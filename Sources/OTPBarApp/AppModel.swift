import AppKit
import OTPBarCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var entries: [OTPEntry] = []
    @Published private(set) var loadError: String?
    @Published var selectedID: UUID?
    @Published var isEditing = false
    @Published var importVisible = false
    @Published var deletingEntry: OTPEntry?
    @Published var message: String?
    @Published private(set) var menuMessage: String?
    private var vault: TokenVault?
    private var clipboardTimer: Timer?
    private var clipboardChange: Int?
    private let pasteboard: NSPasteboard
    private var feedbackTimers: [Bool: Timer] = [:]

    init(storage: any VaultStorage = KeychainStorage(), pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        do {
            let vault = try TokenVault(storage: storage)
            self.vault = vault
            entries = vault.entries
            selectedID = entries.first?.id
        } catch { loadError = error.localizedDescription }
    }

    var selectedEntry: OTPEntry? { entries.first { $0.id == selectedID } }
    var menuEntries: [OTPEntry] { entries.filter(\.isVisibleInMenu) }

    func setMenuVisibility(_ entry: OTPEntry, visible: Bool) throws {
        guard var vault else { throw OTPError.invalidVault }
        try vault.setMenuVisibility(id: entry.id, visible: visible)
        self.vault = vault
        entries = vault.entries
    }

    func importBackup(_ data: Data, password: String?) throws -> ImportResult {
        guard var vault else { throw OTPError.invalidVault }
        let result = try vault.importBackup(data, password: password)
        self.vault = vault
        entries = vault.entries
        if selectedID == nil { selectedID = entries.first?.id }
        message = "导入完成：新增 \(result.added) 个，跳过 \(result.skipped) 个重复账号。"
        return result
    }

    func update(_ entry: OTPEntry) throws {
        guard var vault else { throw OTPError.invalidVault }
        guard let current = vault.entries.first(where: { $0.id == entry.id }) else { throw OTPError.entryNotFound }
        var updated = entry
        updated.isVisibleInMenu = current.isVisibleInMenu
        try vault.update(updated)
        self.vault = vault
        entries = vault.entries
        isEditing = false
        message = "修改已保存。"
    }

    func remove(_ entry: OTPEntry) throws {
        guard var vault else { throw OTPError.invalidVault }
        try vault.remove(id: entry.id)
        self.vault = vault
        entries = vault.entries
        selectedID = entries.first?.id
        message = "已从这台 Mac 删除“\(entry.name)”。"
    }

    @discardableResult
    func copy(_ entry: OTPEntry, fromMenu: Bool = false) -> Bool {
        do {
            guard let vault else { throw OTPError.invalidVault }
            let code = try vault.code(for: entry.id)
            clipboardTimer?.invalidate()
            pasteboard.clearContents()
            guard pasteboard.setString(code.value, forType: .string) else {
                showFeedback("无法写入剪贴板，请重试。", fromMenu: fromMenu)
                return false
            }
            clipboardChange = pasteboard.changeCount
            let timer = Timer(timeInterval: max(0.01, code.validUntil.timeIntervalSinceNow), repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.clearCopiedCode() }
            }
            RunLoop.main.add(timer, forMode: .common)
            clipboardTimer = timer
            if fromMenu { menuMessage = nil }
            else { showFeedback("已复制 \(entry.name) 的验证码。", fromMenu: false) }
            return true
        } catch {
            showFeedback(error.localizedDescription, fromMenu: fromMenu)
            return false
        }
    }

    private func showFeedback(_ text: String, fromMenu: Bool) {
        feedbackTimers[fromMenu]?.invalidate()
        if fromMenu { menuMessage = text } else { message = text }
        let timer = Timer(timeInterval: 2.4, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if fromMenu { if self.menuMessage == text { self.menuMessage = nil } }
                else if self.message == text { self.message = nil }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        feedbackTimers[fromMenu] = timer
    }

    func clearCopiedCode() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
        if let clipboardChange, pasteboard.changeCount == clipboardChange {
            pasteboard.clearContents()
        }
        clipboardChange = nil
    }
}

func groupedCode(_ code: String) -> String {
    let middle = code.index(code.startIndex, offsetBy: code.count / 2)
    return String(code[..<middle]) + " " + String(code[middle...])
}
