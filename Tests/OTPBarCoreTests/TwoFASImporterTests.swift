import Foundation
import Testing
@testable import OTPBarCore

@Test(arguments: ["plaintext-v3", "plaintext-v4"])
func importsPlaintextVersions(_ name: String) throws {
    let data = try fixture(name)
    let original = data
    let entries = try TwoFASImporter.read(data)
    #expect(entries.map(\.name) == ["Example first", "Example second"])
    #expect(entries.map(\.algorithm) == [.sha1, .sha256])
    #expect(entries.map(\.digits) == [6, 8])
    #expect(entries.map(\.period) == [30, 60])
    #expect(entries[0].account == "first@example.invalid")
    #expect(try TOTP.generate(for: entries[0], at: Date(timeIntervalSince1970: 59)).value == "287082")
    #expect(data == original)
}

@Test func decryptsIndependentNodeFixtures() throws {
    let plain = try TwoFASImporter.read(fixture("plaintext-v4"))
    for (name, password) in [("ascii", "otpbar-test-only"), ("utf8", "测试密码🔑"), ("empty", "")] {
        let decrypted = try TwoFASImporter.read(fixture("encrypted-\(name)-v4"), password: password)
        #expect(decrypted.count == plain.count)
        for (actual, expected) in zip(decrypted, plain) {
            #expect(actual.name == expected.name)
            #expect(actual.account == expected.account)
            #expect(actual.hasSameGenerator(as: expected))
        }
    }
}

@Test func passwordAndReferenceFailures() throws {
    let encrypted = try fixture("encrypted-ascii-v4")
    #expect(throws: OTPError.passwordRequired) { try TwoFASImporter.read(encrypted) }
    for password in ["wrong", "", "otpbar-test-only "] {
        #expect(throws: OTPError.decryptionFailed) { try TwoFASImporter.read(encrypted, password: password) }
    }
    #expect(throws: OTPError.decryptionFailed) {
        try TwoFASImporter.read(fixture("encrypted-bad-reference-v4"), password: "otpbar-test-only")
    }
}

@Test func everyEncryptedComponentIsAuthenticated() throws {
    let original = try JSONSerialization.jsonObject(with: fixture("encrypted-ascii-v4")) as! [String: Any]
    // Both ciphertext+tag fields, both salts and both nonces must be authenticated.
    for field in ["servicesEncrypted", "reference"] {
        for component in 0..<3 {
            for bytePosition in [0, -1] {
                var json = original
                var parts = (json[field] as! String).components(separatedBy: ":")
                var bytes = Data(base64Encoded: parts[component])!
                let index = bytePosition == -1 ? bytes.count - 1 : 0
                bytes[index] ^= 1
                parts[component] = bytes.base64EncodedString()
                json[field] = parts.joined(separator: ":")
                let corrupted = try JSONSerialization.data(withJSONObject: json)
                #expect(throws: OTPError.decryptionFailed) { try TwoFASImporter.read(corrupted, password: "otpbar-test-only") }
            }
        }
    }
}

@Test func malformedEncryptedEnvelopesFailClosed() throws {
    let original = try JSONSerialization.jsonObject(with: fixture("encrypted-ascii-v4")) as! [String: Any]
    for value in ["", ":", "::", "invalid:base64:!", "AA==:AA==:AA=="] {
        var json = original
        json["servicesEncrypted"] = value
        #expect(throws: OTPError.invalidBackup) {
            try TwoFASImporter.read(JSONSerialization.data(withJSONObject: json), password: "otpbar-test-only")
        }
    }
    for field in ["servicesEncrypted", "reference"] {
        var json = original
        json.removeValue(forKey: field)
        #expect(throws: OTPError.invalidBackup) {
            try TwoFASImporter.read(JSONSerialization.data(withJSONObject: json), password: "otpbar-test-only")
        }
    }
    var mixed = original
    mixed["services"] = (try JSONSerialization.jsonObject(with: fixture("plaintext-v4")) as! [String: Any])["services"]
    #expect(throws: OTPError.invalidBackup) {
        try TwoFASImporter.read(JSONSerialization.data(withJSONObject: mixed), password: "otpbar-test-only")
    }
}

@Test func unsupportedVersionsAndTokensFailExplicitly() throws {
    for version in [0, 1, 2, 5, Int.max] {
        let data = try modifiedBackup { $0["schemaVersion"] = version }
        #expect(throws: OTPError.unsupportedSchema(version)) { try TwoFASImporter.read(data) }
    }
    for (field, value) in [("tokenType", "HOTP"), ("tokenType", "STEAM"), ("tokenType", "future"), ("algorithm", "MD5")] {
        let data = try modifiedBackup {
            var services = $0["services"] as! [[String: Any]]
            var otp = services[0]["otp"] as! [String: Any]
            otp[field] = value
            services[0]["otp"] = otp
            $0["services"] = services
        }
        #expect(throws: OTPError.unsupportedToken) { try TwoFASImporter.read(data) }
    }
}

@Test func missingOptionalOtpFieldsUse2FASDefaults() throws {
    let data = try modifiedBackup {
        var services = $0["services"] as! [[String: Any]]
        services[0]["otp"] = ["account": "label", "algorithm": NSNull(), "digits": NSNull()]
        $0["services"] = services
    }
    let entries = try TwoFASImporter.read(data)
    #expect(entries[1].algorithm == .sha1)
    #expect(entries[1].digits == 6)
    #expect(entries[1].period == 30)
}

@Test func corruptJsonMissingFieldsAndInvalidEntriesFail() throws {
    for input in ["not json", "[]", "{}", "{\"schemaVersion\":4}", "{\"schemaVersion\":4,\"services\":null}"] {
        #expect(throws: OTPError.invalidBackup) { try TwoFASImporter.read(Data(input.utf8)) }
    }
    let invalid = try modifiedBackup {
        var services = $0["services"] as! [[String: Any]]
        services[0]["secret"] = "not-a-key!"
        $0["services"] = services
    }
    #expect(throws: OTPError.invalidSecret) { try TwoFASImporter.read(invalid) }
    let invalidDigits = try modifiedBackup {
        var services = $0["services"] as! [[String: Any]]
        var otp = services[0]["otp"] as! [String: Any]
        otp["digits"] = 0
        services[0]["otp"] = otp
        $0["services"] = services
    }
    #expect(throws: OTPError.invalidParameters) { try TwoFASImporter.read(invalidDigits) }
}
