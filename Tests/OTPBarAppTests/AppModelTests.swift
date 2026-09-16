import AppKit
import Foundation
import OTPBarCore
@testable import OTPBarApp
import Testing

private enum StorageFailure: Error { case unavailable }
private final class TestStorage: VaultStorage {
    var data: Data?
    var failRead = false
    var failWrite = false
    func read() throws -> Data? {
        if failRead { throw StorageFailure.unavailable }
        return data
    }
    func write(_ data: Data) throws {
        if failWrite { throw StorageFailure.unavailable }
        self.data = data
    }
}

private let backup = Data("""
{"schemaVersion":4,"services":[{"name":"Synthetic","secret":"GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ","otp":{"tokenType":"TOTP","algorithm":"SHA1","digits":6,"period":30}}]}
""".utf8)

@MainActor @Test func hiddenAccountsRemainEditableAndCopyableAfterReload() throws {
    let storage = TestStorage()
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    let model = AppModel(storage: storage, pasteboard: pasteboard)
    _ = try model.importBackup(backup, password: nil)
    let entry = try #require(model.selectedEntry)
    model.isEditing = true
    try model.setMenuVisibility(entry, visible: false)
    #expect(model.isEditing)
    #expect(model.menuEntries.isEmpty)
    #expect(model.entries.count == 1)
    #expect(model.selectedID == entry.id)
    try model.update(OTPEntry(id: entry.id, name: "Edited", secret: entry.secret))
    #expect(model.menuEntries.isEmpty)
    #expect(model.selectedEntry?.name == "Edited")
    #expect(model.copy(entry))
    #expect(pasteboard.string(forType: .string) != nil)
    #expect(AppModel(storage: storage).menuEntries.isEmpty)
    model.clearCopiedCode()
}

@MainActor @Test func menuCopyReportsSuccessWithoutSettingsFeedback() throws {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    let model = AppModel(storage: TestStorage(), pasteboard: pasteboard)
    _ = try model.importBackup(backup, password: nil)
    let entry = try #require(model.selectedEntry)
    model.message = nil
    #expect(model.copy(entry, fromMenu: true))
    #expect(model.message == nil)
    #expect(model.menuMessage == nil)
    try model.remove(entry)
    let settingsMessage = model.message
    #expect(!model.copy(entry, fromMenu: true))
    #expect(model.menuMessage == OTPError.entryNotFound.localizedDescription)
    #expect(model.message == settingsMessage)
    model.clearCopiedCode()
}

@MainActor @Test func clipboardCleanupPreservesLaterWritesAndUsesCurrentEntry() throws {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    let model = AppModel(storage: TestStorage(), pasteboard: pasteboard)
    _ = try model.importBackup(backup, password: nil)
    let oldEntry = try #require(model.selectedEntry)
    let replacement = try OTPEntry(id: oldEntry.id, name: "Changed", secret: "JBSWY3DPEHPK3PXP")
    try model.update(replacement)
    let before = try TOTP.generate(for: replacement).value
    model.copy(oldEntry)
    let after = try TOTP.generate(for: replacement).value
    #expect([before, after].contains(pasteboard.string(forType: .string) ?? ""))
    model.clearCopiedCode()
    #expect(pasteboard.string(forType: .string) == nil)
    model.copy(replacement)
    pasteboard.clearContents()
    pasteboard.setString("user replacement", forType: .string)
    model.clearCopiedCode()
    #expect(pasteboard.string(forType: .string) == "user replacement")
}

@MainActor @Test func failedDeletionKeepsSelectionAndAccountVisible() throws {
    let storage = TestStorage()
    let model = AppModel(storage: storage)
    _ = try model.importBackup(backup, password: nil)
    let entry = try #require(model.selectedEntry)
    storage.failWrite = true
    #expect(throws: StorageFailure.unavailable) { try model.remove(entry) }
    #expect(model.selectedID == entry.id)
    #expect(model.entries == [entry])
    storage.failWrite = false
    try model.remove(entry)
    #expect(model.entries.isEmpty)
    #expect(model.selectedID == nil)
}

@MainActor @Test func copiedCodeIsClearedWhenItsPeriodEnds() throws {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    let model = AppModel(storage: TestStorage(), pasteboard: pasteboard)
    _ = try model.importBackup(backup, password: nil)
    let imported = try #require(model.selectedEntry)
    let entry = try OTPEntry(id: imported.id, name: imported.name, secret: imported.secret, period: 10)
    try model.update(entry)
    model.copy(entry)
    #expect(pasteboard.string(forType: .string) != nil)
    let expiry = try TOTP.generate(for: entry).validUntil
    RunLoop.main.run(until: expiry.addingTimeInterval(0.2))
    #expect(pasteboard.string(forType: .string) == nil)
}

@MainActor @Test func loadFailureDisablesWrites() throws {
    let storage = TestStorage()
    storage.failRead = true
    let model = AppModel(storage: storage)
    #expect(model.loadError != nil)
    #expect(throws: OTPError.invalidVault) { try model.importBackup(backup, password: nil) }
    #expect(storage.data == nil)
}
