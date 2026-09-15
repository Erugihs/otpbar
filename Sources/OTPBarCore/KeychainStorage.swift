import Foundation
import Security

public struct KeychainFailure: Error, LocalizedError {
    public let status: OSStatus
    public var errorDescription: String? {
        "无法访问 macOS 钥匙串（错误 \(status)）。原数据未被替换。"
    }
}

public struct KeychainStorage: VaultStorage, Sendable {
    private let service: String
    private let account = "otpbar-vault-v1"

    public init(service: String = "com.erugihs.otpbar") { self.service = service }

    private var query: [String: Any] {
        // Ad hoc macOS builds use the file-based keychain and its system-managed ACL.
        // Data-protection access groups require provisioned signing (Apple TN3137).
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecUseDataProtectionKeychain as String: false,
         kSecAttrSynchronizable as String: false]
    }

    public func read() throws -> Data? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainFailure(status: status) }
        guard let data = result as? Data else { throw OTPError.invalidVault }
        return data
    }

    public func write(_ data: Data) throws {
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrLabel as String] = "OTPBar 验证码"
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainFailure(status: added) }
        } else if status != errSecSuccess {
            throw KeychainFailure(status: status)
        }
    }
}
