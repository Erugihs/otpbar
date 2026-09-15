import Foundation
import Testing
@testable import OTPBarCore

@Test func importAndReloadPreserveIdentityAndData() throws {
    let storage = MemoryStorage()
    var vault = try TokenVault(storage: storage)
    #expect(vault.entries.isEmpty)
    let result = try vault.importBackup(fixture("plaintext-v4"))
    #expect(result.added == 2)
    #expect(result.skipped == 0)
    #expect(storage.writes == 1)
    let reopened = try TokenVault(storage: storage)
    #expect(reopened.entries == vault.entries)
}

@Test func duplicateImportsPreserveLocalEdits() throws {
    let storage = MemoryStorage()
    var vault = try TokenVault(storage: storage)
    try vault.importBackup(fixture("plaintext-v4"))
    let original = vault.entries[0]
    let edited = try OTPEntry(id: original.id, name: "Local name", account: "local@example.invalid", secret: original.secret)
    try vault.update(edited)
    let writesBefore = storage.writes
    let result = try vault.importBackup(fixture("encrypted-ascii-v4"), password: "otpbar-test-only")
    #expect(result.added == 0)
    #expect(result.skipped == 2)
    #expect(storage.writes == writesBefore)
    #expect(vault.entries[0] == edited)
}

@Test func duplicatesWithinBackupAreSkippedButDifferentParametersSurvive() throws {
    let data = try modifiedBackup {
        var services = $0["services"] as! [[String: Any]]
        var duplicate = services[1]
        duplicate["secret"] = publicTestSecret.lowercased() + "\n"
        var variant = duplicate
        var otp = variant["otp"] as! [String: Any]
        otp["period"] = 60
        variant["otp"] = otp
        services += [duplicate, variant]
        $0["services"] = services
    }
    var vault = try TokenVault(storage: MemoryStorage())
    let result = try vault.importBackup(data)
    #expect(result.added == 3)
    #expect(result.skipped == 1)
}

@Test func oneBadEntryRejectsWholeImport() throws {
    let storage = MemoryStorage()
    var vault = try TokenVault(storage: storage)
    let corrupt = try modifiedBackup {
        var services = $0["services"] as! [[String: Any]]
        services[0]["secret"] = "invalid!" // Second in display order: first must not be written either.
        $0["services"] = services
    }
    #expect(throws: OTPError.invalidSecret) { try vault.importBackup(corrupt) }
    #expect(storage.writes == 0)
    #expect(vault.entries.isEmpty)
    #expect(storage.data == nil)
}

@Test func failedWritesLeaveMemoryAndPersistedDataUnchanged() throws {
    let storage = MemoryStorage()
    var vault = try TokenVault(storage: storage)
    storage.failWrite = true
    #expect(throws: TestFailure.write) { try vault.importBackup(fixture("plaintext-v4")) }
    #expect(vault.entries.isEmpty)
    #expect(storage.data == nil)
    storage.failWrite = false
    try vault.importBackup(fixture("plaintext-v4"))
    let before = vault.entries
    let bytesBefore = storage.data
    storage.failWrite = true
    let changed = try OTPEntry(id: before[0].id, name: "Changed", secret: "MZXW6YTBOI")
    #expect(throws: TestFailure.write) { try vault.update(changed) }
    #expect(vault.entries == before)
    #expect(storage.data == bytesBefore)
    #expect(try TokenVault(storage: storage).entries == before)
}

@Test func unreadableVaultNeverBecomesWritableEmptyVault() throws {
    let storage = MemoryStorage()
    storage.failRead = true
    #expect(throws: TestFailure.read) { try TokenVault(storage: storage) }
    storage.failRead = false
    for invalid in ["broken", "{}", "{\"schemaVersion\":2,\"entries\":[]}"] {
        storage.data = Data(invalid.utf8)
        #expect(throws: OTPError.invalidVault) { try TokenVault(storage: storage) }
    }
    #expect(storage.writes == 0)
}

@Test func persistedEntriesAreValidatedOnRead() throws {
    let storage = MemoryStorage()
    var vault = try TokenVault(storage: storage)
    try vault.importBackup(fixture("plaintext-v4"))
    let original = try JSONSerialization.jsonObject(with: storage.data!) as! [String: Any]
    for field in ["digits", "period", "secret"] {
        var data = original
        var entries = data["entries"] as! [[String: Any]]
        entries[0][field] = field == "secret" ? "invalid!" : 0
        data["entries"] = entries
        storage.data = try JSONSerialization.data(withJSONObject: data)
        #expect(throws: OTPError.invalidVault) { try TokenVault(storage: storage) }
    }
    var duplicated = original
    let entries = original["entries"] as! [[String: Any]]
    duplicated["entries"] = entries + entries
    storage.data = try JSONSerialization.data(withJSONObject: duplicated)
    #expect(throws: OTPError.invalidVault) { try TokenVault(storage: storage) }
}

@Test func editsValidateIdentityAndAvoidGeneratorCollision() throws {
    let storage = MemoryStorage()
    var vault = try TokenVault(storage: storage)
    try vault.importBackup(fixture("plaintext-v4"))
    let other = vault.entries[1]
    let collision = try OTPEntry(id: vault.entries[0].id, name: "Collision", secret: other.secret,
                                 algorithm: other.algorithm, digits: other.digits, period: other.period)
    #expect(throws: OTPError.duplicateEntry) { try vault.update(collision) }
    #expect(throws: OTPError.entryNotFound) { try vault.update(OTPEntry(name: "Unknown", secret: publicTestSecret)) }
    #expect(storage.writes == 1)
}

@Test func lookupRecomputesCodeAtRollover() throws {
    var vault = try TokenVault(storage: MemoryStorage())
    try vault.importBackup(fixture("plaintext-v4"))
    let id = vault.entries[0].id
    // RFC 4226 counters 0 and 1: a click after rollover must return the new code.
    let displayed = try vault.code(for: id, at: Date(timeIntervalSince1970: 29.999))
    let clicked = try vault.code(for: id, at: Date(timeIntervalSince1970: 30))
    #expect(displayed.value == "755224")
    #expect(clicked.value == "287082")
    #expect(displayed.validUntil == Date(timeIntervalSince1970: 30))
}

@Test func deletionPersistsAndPreservesOtherAccounts() throws {
    let storage = MemoryStorage()
    var vault = try TokenVault(storage: storage)
    try vault.importBackup(fixture("plaintext-v4"))
    let removed = vault.entries[0].id
    let retained = vault.entries[1]
    try vault.remove(id: removed)
    #expect(vault.entries == [retained])
    #expect(try TokenVault(storage: storage).entries == [retained])
    #expect(throws: OTPError.entryNotFound) { try vault.code(for: removed) }
    try vault.remove(id: retained.id)
    #expect(try TokenVault(storage: storage).entries.isEmpty)
    let result = try vault.importBackup(fixture("plaintext-v4"))
    #expect(result.added == 2)
    #expect(result.skipped == 0)
}

@Test func failedOrStaleDeletionDoesNotChangeTheVault() throws {
    let storage = MemoryStorage()
    var vault = try TokenVault(storage: storage)
    try vault.importBackup(fixture("plaintext-v4"))
    let before = vault.entries
    let bytesBefore = storage.data
    let writesBefore = storage.writes
    storage.failWrite = true
    #expect(throws: TestFailure.write) { try vault.remove(id: before[0].id) }
    #expect(vault.entries == before)
    #expect(storage.data == bytesBefore)
    storage.failWrite = false
    #expect(throws: OTPError.entryNotFound) { try vault.remove(id: UUID()) }
    #expect(storage.writes == writesBefore)
    #expect(try TokenVault(storage: storage).entries == before)
}

@Test func matchingNamesWithDifferentSecretsAreNotDuplicates() throws {
    let data = try modifiedBackup {
        var services = $0["services"] as! [[String: Any]]
        let first = services[0]
        services[1]["name"] = first["name"]
        services[1]["otp"] = first["otp"]
        $0["services"] = services
    }
    var vault = try TokenVault(storage: MemoryStorage())
    let firstImport = try vault.importBackup(data)
    #expect(firstImport.added == 2)
    #expect(firstImport.skipped == 0)
    #expect(vault.entries[0].name == vault.entries[1].name)
    let secondImport = try vault.importBackup(data)
    #expect(secondImport.added == 0)
    #expect(secondImport.skipped == 2)
}
