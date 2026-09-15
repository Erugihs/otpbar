import AppKit
import OTPBarCore
import SwiftUI

@main
struct OTPBarApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private var menuTimer: Timer?
    private var codeItems: [(NSMenuItem, OTPEntry)] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let icon = Bundle.main.url(forResource: "otpbar-template", withExtension: "png")
                .flatMap { NSImage(contentsOf: $0) } ?? NSImage(systemSymbolName: "key.horizontal", accessibilityDescription: "OTPBar")!
            icon.size = NSSize(width: 20, height: 20)
            icon.isTemplate = true
            button.image = icon
            button.toolTip = "OTPBar — 左键查看验证码，右键打开设置"
            button.setAccessibilityLabel("OTPBar")
            button.target = self
            button.action = #selector(statusClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        let appMenu = NSMenu()
        let item = NSMenuItem()
        let submenu = NSMenu()
        submenu.addItem(withTitle: "设置…", action: #selector(showSettings), keyEquivalent: ",").target = self
        submenu.addItem(.separator())
        submenu.addItem(withTitle: "退出 OTPBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = submenu
        appMenu.addItem(item)
        let edit = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        edit.submenu = NSMenu(title: "编辑")
        for (title, action, key) in [("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            edit.submenu?.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        appMenu.addItem(edit)
        NSApp.mainMenu = appMenu
        if model.entries.isEmpty || model.loadError != nil { showSettings() }
    }

    @objc private func statusClicked() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        codeItems = []
        let secondaryClick = NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true
        if !secondaryClick {
            if model.loadError != nil {
                let item = menu.addItem(withTitle: "无法读取本地数据，请打开设置", action: nil, keyEquivalent: "")
                item.isEnabled = false
            } else if model.entries.isEmpty {
                let item = menu.addItem(withTitle: "还没有验证码，请在设置中导入备份", action: nil, keyEquivalent: "")
                item.isEnabled = false
            }
            for entry in model.entries {
                let item = NSMenuItem(title: entry.name, action: #selector(copyCode(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = entry.id
                menu.addItem(item)
                codeItems.append((item, entry))
            }
            refreshMenu()
            menu.addItem(.separator())
        }
        menu.addItem(withTitle: "设置…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "退出 OTPBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard !codeItems.isEmpty else { return }
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshMenu() }
        }
        RunLoop.main.add(timer, forMode: .eventTracking)
        menuTimer = timer
    }

    func menuDidClose(_ menu: NSMenu) {
        menuTimer?.invalidate()
        menuTimer = nil
        statusItem.menu = nil
        codeItems = []
    }

    private func refreshMenu() {
        let now = Date()
        for (item, entry) in codeItems {
            let heading = entry.account.isEmpty ? entry.name : "\(entry.name) · \(entry.account)"
            let title = NSMutableAttributedString(string: heading + "\n", attributes: [.font: NSFont.systemFont(ofSize: 12)])
            if let code = try? TOTP.generate(for: entry, at: now) {
                let remaining = max(0, Int(ceil(code.validUntil.timeIntervalSince(now))))
                title.append(NSAttributedString(string: "\(groupedCode(code.value))  ·  \(remaining) 秒", attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)]))
                item.isEnabled = true
            } else {
                title.append(NSAttributedString(string: "系统时间无效"))
                item.isEnabled = false
            }
            item.attributedTitle = title
        }
    }

    @objc private func copyCode(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID, let entry = model.entries.first(where: { $0.id == id }) else { return }
        model.copy(entry)
    }

    @objc func showSettings() {
        if window == nil {
            let content = SettingsView(model: model)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 570),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "OTPBar — 设置"
            window.contentView = NSHostingView(rootView: content)
            window.minSize = NSSize(width: 700, height: 550)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if model.isEditing {
            model.message = "请先保存或取消当前修改。"
            return false
        }
        return true
    }

    func windowWillClose(_ notification: Notification) { NSApp.setActivationPolicy(.accessory) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model.isEditing {
            showSettings()
            model.message = "请先保存或取消当前修改，再退出。"
            return .terminateCancel
        }
        return .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) { model.clearCopiedCode() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }
}
