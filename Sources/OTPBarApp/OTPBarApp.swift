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
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private let popover = NSPopover()

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
        if popover.isShown { popover.performClose(nil); return }
        guard let button = statusItem.button else { return }
        let secondary = NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(rootView: CodeMenuView(
            model: model, contextOnly: secondary,
            close: { [weak self] in self?.popover.performClose(nil) },
            settings: { [weak self] in self?.showSettings() },
            quit: { NSApp.terminate(nil) }
        ))
        if let content = popover.contentViewController { popover.contentSize = content.view.fittingSize }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    @objc func showSettings() {
        if window == nil {
            let content = SettingsView(model: model)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 850, height: 578),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "OTPBar — 设置"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.contentView = NSHostingView(rootView: content)
            if let contentView = window.contentView {
                for (index, type) in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].enumerated() {
                    guard let button = window.standardWindowButton(type) else { continue }
                    button.removeFromSuperview()
                    contentView.addSubview(button)
                    button.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: CGFloat(18 + index * 20)),
                        button.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
                        button.widthAnchor.constraint(equalToConstant: 12),
                        button.heightAnchor.constraint(equalToConstant: 12)
                    ])
                }
            }
            window.minSize = NSSize(width: 700, height: 578)
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
