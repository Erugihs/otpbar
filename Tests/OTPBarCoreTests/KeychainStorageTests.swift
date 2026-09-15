import Foundation
import Security
import Testing
@testable import OTPBarCore

@Test(.enabled(if: ProcessInfo.processInfo.environment["OTPBAR_KEYCHAIN_TEST"] == "1",
               "Set OTPBAR_KEYCHAIN_TEST=1 to exercise an isolated, temporary local Keychain record."))
func realKeychainRoundTrip() throws {
    let service = "com.erugihs.otpbar.tests.\(UUID().uuidString)"
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecUseDataProtectionKeychain as String: false,
                                kSecAttrService as String: service]
    defer {
        let deleted = SecItemDelete(query as CFDictionary)
        #expect(deleted == errSecSuccess || deleted == errSecItemNotFound)
    }
    let storage = KeychainStorage(service: service)
    #expect(try storage.read() == nil)
    var vault = try TokenVault(storage: storage)
    try vault.importBackup(fixture("encrypted-ascii-v4"), password: "otpbar-test-only")
    #expect(try TokenVault(storage: storage).entries == vault.entries)
    let first = vault.entries[0]
    let edited = try OTPEntry(id: first.id, name: "Edited synthetic entry", secret: first.secret)
    try vault.update(edited)
    #expect(try TokenVault(storage: storage).entries[0] == edited)

    var attributesQuery = query
    attributesQuery[kSecReturnAttributes as String] = true
    var result: CFTypeRef?
    #expect(SecItemCopyMatching(attributesQuery as CFDictionary, &result) == errSecSuccess)
    let attributes = try #require(result as? [String: Any])
    #expect(attributes[kSecAttrService as String] as? String == service)
    #expect(attributes[kSecAttrAccount as String] as? String == "otpbar-vault-v1")
    #expect((attributes[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue != true)
}
