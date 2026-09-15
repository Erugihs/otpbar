import CryptoKit
import Foundation

public struct OTPCode: Equatable, Sendable {
    public let value: String
    public let validUntil: Date
}

public enum TOTP {
    public static func generate(for entry: OTPEntry, at date: Date = Date()) throws -> OTPCode {
        let timestamp = date.timeIntervalSince1970
        let counterValue = floor(timestamp / Double(entry.period))
        guard timestamp.isFinite, timestamp >= 0, counterValue < Double(UInt64.max) else {
            throw OTPError.invalidTime
        }
        var counter = UInt64(counterValue).bigEndian
        let message = withUnsafeBytes(of: &counter) { Data($0) }
        let key = SymmetricKey(data: try Base32.decode(entry.secret))
        let digest: [UInt8]
        switch entry.algorithm {
        case .sha1: digest = Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        case .sha256: digest = Array(HMAC<SHA256>.authenticationCode(for: message, using: key))
        case .sha512: digest = Array(HMAC<SHA512>.authenticationCode(for: message, using: key))
        }
        let offset = Int(digest[digest.count - 1] & 15)
        let truncated = digest[offset..<(offset + 4)].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) } & 0x7fff_ffff
        let modulus = (0..<entry.digits).reduce(UInt32(1)) { value, _ in value * 10 }
        let value = String(format: "%0*u", entry.digits, truncated % modulus)
        return OTPCode(value: value, validUntil: Date(timeIntervalSince1970: (counterValue + 1) * Double(entry.period)))
    }
}
