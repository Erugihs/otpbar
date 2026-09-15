import CommonCrypto
import CryptoKit
import Foundation

public enum TwoFASImporter {
    public static let maximumFileSize = 100 * 1024 * 1024

    public static func read(_ data: Data, password: String? = nil) throws -> [OTPEntry] {
        guard data.count <= maximumFileSize else { throw OTPError.invalidBackup }
        do {
            let decoder = JSONDecoder()
            let header = try decoder.decode(Header.self, from: data)
            guard [3, 4].contains(header.schemaVersion) else {
                throw OTPError.unsupportedSchema(header.schemaVersion)
            }
            let backup = try decoder.decode(Backup.self, from: data)
            let services: [Service]
            if backup.servicesEncrypted != nil || backup.reference != nil {
                guard let encrypted = backup.servicesEncrypted, let reference = backup.reference,
                      backup.services?.isEmpty != false else { throw OTPError.invalidBackup }
                guard let password else { throw OTPError.passwordRequired }
                let referenceData = try decrypt(reference, password: password)
                guard referenceData == Data(referenceValue.utf8) else { throw OTPError.decryptionFailed }
                services = try decoder.decode([Service].self, from: decrypt(encrypted, password: password))
            } else {
                guard let plaintext = backup.services else { throw OTPError.invalidBackup }
                services = plaintext
            }
            // Stable ordering when two groups contain the same position.
            return try services.enumerated().sorted {
                let left = $0.element.order?.position ?? $0.offset
                let right = $1.element.order?.position ?? $1.offset
                return left == right ? $0.offset < $1.offset : left < right
            }.map { _, service in
                guard (service.otp.tokenType ?? "TOTP").uppercased() == "TOTP",
                      let algorithm = OTPAlgorithm(rawValue: (service.otp.algorithm ?? "SHA1").uppercased()) else {
                    throw OTPError.unsupportedToken
                }
                return try OTPEntry(name: service.name, account: service.otp.account ?? "", secret: service.secret,
                                    algorithm: algorithm, digits: service.otp.digits ?? 6, period: service.otp.period ?? 30)
            }
        } catch let error as OTPError {
            throw error
        } catch {
            // Never include decoder/crypto diagnostics containing backup data in UI errors or logs.
            throw OTPError.invalidBackup
        }
    }

    private static func decrypt(_ encoded: String, password: String) throws -> Data {
        let parts = encoded.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3, let payload = Data(base64Encoded: String(parts[0])),
              let salt = Data(base64Encoded: String(parts[1])), let nonce = Data(base64Encoded: String(parts[2])),
              payload.count >= 16, salt.count == 32, nonce.count == 12 else { throw OTPError.invalidBackup }

        var key = [UInt8](repeating: 0, count: 32)
        defer { _ = key.withUnsafeMutableBytes { $0.initializeMemory(as: UInt8.self, repeating: 0) } }
        let status = password.withCString { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), passwordBytes, password.utf8.count,
                                    saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 10_000, &key, key.count)
            }
        }
        guard status == kCCSuccess else { throw OTPError.decryptionFailed }
        do {
            let sealed = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce),
                                              ciphertext: payload.dropLast(16), tag: payload.suffix(16))
            return try AES.GCM.open(sealed, using: SymmetricKey(data: key))
        } catch {
            throw OTPError.decryptionFailed
        }
    }

    // Public format marker specified by 2FAS; not a secret.
    private static let referenceValue = "tRViSsLKzd86Hprh4ceC2OP7xazn4rrt4xhfEUbOjxLX8Rc3mkISXE0lWbmnWfggogbBJhtYgpK6fMl1D6mtsy92R3HkdGfwuXbzLebqVFJsR7IZ2w58t938iymwG4824igYy1wi6n2WDpO1Q1P69zwJGs2F5a1qP4MyIiDSD7NCV2OvidXQCBnDlGfmz0f1BQySRkkt4ryiJeCjD2o4QsveJ9uDBUn8ELyOrESv5R5DMDkD4iAF8TXU7KyoJujd"

    private struct Header: Decodable { let schemaVersion: Int }
    private struct Backup: Decodable {
        let services: [Service]?
        let servicesEncrypted: String?
        let reference: String?
    }
    private struct Service: Decodable {
        let name: String
        let secret: String
        let otp: OTP
        let order: Order?
    }
    private struct OTP: Decodable {
        let account: String?
        let digits: Int?
        let period: Int?
        let algorithm: String?
        let tokenType: String?
    }
    private struct Order: Decodable { let position: Int }
}
