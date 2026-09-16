import Foundation

public enum OTPError: Error, Equatable, LocalizedError {
    case invalidName, invalidSecret, invalidParameters, invalidTime
    case invalidBackup, unsupportedSchema(Int), unsupportedToken, passwordRequired, decryptionFailed
    case invalidVault, entryNotFound, duplicateEntry

    public var errorDescription: String? {
        switch self {
        case .invalidName: "请输入账号名称。"
        case .invalidSecret: "密钥不是有效的 Base32 字符串。"
        case .invalidParameters: "支持 5–8 位验证码，周期为 10、30、60 或 90 秒。"
        case .invalidTime: "系统时间无效，请检查 Mac 的日期与时间设置。"
        case .invalidBackup: "备份格式无效或已损坏，未导入任何条目。"
        case .unsupportedSchema(let version): "暂不支持备份版本 \(version)，请用最新版 2FAS 重新导出。"
        case .unsupportedToken: "备份包含暂不支持的验证码类型或算法，未导入任何条目。"
        case .passwordRequired: "请输入导出备份时设置的密码。"
        case .decryptionFailed: "密码不正确或备份已损坏。"
        case .invalidVault: "本地数据无法读取；为保护原数据，已停止写入。"
        case .entryNotFound: "未找到该条目，请重新打开设置。"
        case .duplicateEntry: "已存在使用相同密钥和生成参数的条目。"
        }
    }
}

public enum OTPAlgorithm: String, Codable, CaseIterable, Sendable {
    case sha1 = "SHA1", sha256 = "SHA256", sha512 = "SHA512"
}

public struct OTPEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let account: String
    public let secret: String
    public let algorithm: OTPAlgorithm
    public let digits: Int
    public let period: Int
    public var isVisibleInMenu: Bool

    public init(id: UUID = UUID(), name: String, account: String = "", secret: String,
                algorithm: OTPAlgorithm = .sha1, digits: Int = 6, period: Int = 30,
                isVisibleInMenu: Bool = true) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw OTPError.invalidName }
        guard (5...8).contains(digits), [10, 30, 60, 90].contains(period) else {
            throw OTPError.invalidParameters
        }
        let canonical = try Base32.canonical(secret)
        self.id = id
        self.name = trimmedName
        self.account = account.trimmingCharacters(in: .whitespacesAndNewlines)
        self.secret = canonical
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
        self.isVisibleInMenu = isVisibleInMenu
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: container.decode(UUID.self, forKey: .id),
                      name: container.decode(String.self, forKey: .name),
                      account: container.decode(String.self, forKey: .account),
                      secret: container.decode(String.self, forKey: .secret),
                      algorithm: container.decode(OTPAlgorithm.self, forKey: .algorithm),
                      digits: container.decode(Int.self, forKey: .digits),
                      period: container.decode(Int.self, forKey: .period),
                      isVisibleInMenu: container.decodeIfPresent(Bool.self, forKey: .isVisibleInMenu) ?? true)
    }

    func hasSameGenerator(as other: OTPEntry) -> Bool {
        secret == other.secret && algorithm == other.algorithm && digits == other.digits && period == other.period
    }
}

enum Base32 {
    static func canonical(_ input: String) throws -> String {
        let compact = input.uppercased().filter { !$0.isWhitespace }
        let parts = compact.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        let content = String(parts[0])
        guard !content.isEmpty else { throw OTPError.invalidSecret }
        let padding = [0: 0, 2: 6, 4: 4, 5: 3, 7: 1]
        guard let expectedPadding = padding[content.utf8.count % 8] else { throw OTPError.invalidSecret }
        if parts.count == 2 {
            guard expectedPadding > 0, parts[1].allSatisfy({ $0 == "=" }),
                  parts[1].count + 1 == expectedPadding else { throw OTPError.invalidSecret }
        }
        _ = try decode(content)
        return content
    }

    static func decode(_ canonical: String) throws -> Data {
        var result = Data()
        var buffer: UInt32 = 0
        var bits = 0
        for character in canonical.utf8 {
            let value: UInt32
            switch character {
            case 65...90: value = UInt32(character - 65)
            case 50...55: value = UInt32(character - 50 + 26)
            default: throw OTPError.invalidSecret
            }
            buffer = (buffer << 5) | value
            bits += 5
            if bits >= 8 {
                bits -= 8
                result.append(UInt8((buffer >> bits) & 255))
                buffer &= (1 << bits) - 1
            }
        }
        guard !result.isEmpty, buffer == 0 else { throw OTPError.invalidSecret }
        return result
    }
}
