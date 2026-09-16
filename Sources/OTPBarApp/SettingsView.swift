import AppKit
import OTPBarCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                WindowControls().frame(width: 66, height: 16)
                Spacer()
                Text("OTPBar · 设置").font(.system(size: 12, weight: .medium))
                Spacer()
                Text("本机存储").font(.system(size: 11)).foregroundStyle(Appearance.muted)
                    .frame(width: 66, alignment: .trailing)
            }.padding(.horizontal, 14).frame(height: 49).background(Appearance.sidebar)
            Appearance.line.frame(height: 1)
            HStack(spacing: 0) {
                sidebar
                Appearance.line.frame(width: 1)
                Group {
                    if let error = model.loadError {
                        ContentUnavailableView("无法读取本地数据", systemImage: "lock.trianglebadge.exclamationmark", description: Text(error))
                    } else if let entry = model.selectedEntry {
                        EntryDetail(model: model, entry: entry).id(entry.id)
                    } else {
                        VStack(spacing: 14) {
                            Text("还没有验证码").font(.system(size: 18, weight: .medium))
                            Text("导入手机上的 2FAS 备份，即可在 Mac 上查看和复制。")
                                .foregroundStyle(Appearance.muted).multilineTextAlignment(.center).frame(maxWidth: 270)
                            Button("导入备份") { model.importVisible = true }.buttonStyle(CompactButtonStyle(primary: true))
                            FeedbackView(message: model.message)
                        }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .disabled(model.importVisible || model.deletingEntry != nil)
        .overlay {
            if model.importVisible || model.deletingEntry != nil {
                ZStack {
                    Color.black.opacity(0.25)
                    Group {
                        if model.importVisible { ImportView(model: model) }
                        else if let entry = model.deletingEntry { DeleteView(model: model, entry: entry) }
                    }.background(Appearance.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Appearance.line))
                        .shadow(color: .black.opacity(0.25), radius: 20, y: 15)
                }
            }
        }
        .font(.system(size: 13)).foregroundStyle(Appearance.text)
        .background(Appearance.surface).buttonStyle(CompactButtonStyle())
        .ignoresSafeArea(.container, edges: .top)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("账号 · \(model.entries.count)")
                Spacer()
                Text("菜单栏显示")
            }.font(.system(size: 11)).foregroundStyle(Appearance.muted)
                .padding(.horizontal, 17).padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(model.entries) { entry in
                        HStack(spacing: 0) {
                            Button {
                                if model.isEditing { model.message = "请先保存或取消当前修改。" }
                                else { model.selectedID = entry.id; model.message = nil }
                            } label: {
                                HStack(spacing: 7) {
                                    AccountAvatar(name: entry.name, size: 25)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                        Text(entry.account.isEmpty ? "—" : entry.account)
                                            .font(.system(size: 11)).foregroundStyle(Appearance.muted).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }.padding(.horizontal, 7).frame(height: 58).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityAddTraits(model.selectedID == entry.id ? .isSelected : [])
                            VStack(spacing: 4) {
                                Toggle("\(entry.name) 在菜单栏显示", isOn: Binding(
                                    get: { entry.isVisibleInMenu },
                                    set: { visible in
                                        do { try model.setMenuVisibility(entry, visible: visible) }
                                        catch { model.message = error.localizedDescription }
                                    }
                                )).labelsHidden().toggleStyle(MenuVisibilityToggleStyle(label: "\(entry.name) 在菜单栏显示"))
                                Text(entry.isVisibleInMenu ? "显示" : "隐藏")
                                    .font(.system(size: 11)).foregroundStyle(Appearance.muted)
                            }.frame(width: 40).padding(.trailing, 5)
                        }.background(model.selectedID == entry.id ? Appearance.selected : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    }
                    Text("关闭后仅从菜单栏隐藏，\n账号仍保留在本机。")
                        .font(.system(size: 11)).foregroundStyle(Appearance.muted).lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 7).padding(.top, 11)
                }.padding(.horizontal, 10)
            }
            Button { model.importVisible = true } label: {
                Label("导入备份", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
            }.disabled(model.isEditing || model.loadError != nil).padding(.horizontal, 10).padding(.top, 15).padding(.bottom, 12)
        }.padding(.top, 18).frame(width: 218).background(Appearance.sidebar)
    }
}

private struct MenuVisibilityToggleStyle: ToggleStyle {
    let label: String
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            Capsule().fill(configuration.isOn ? Appearance.action : Appearance.muted.opacity(0.55))
                .frame(width: 30, height: 18)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle().fill(.white).frame(width: 14, height: 14).padding(2)
                }.frame(width: 36, height: 22).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(label)
            .accessibilityValue(configuration.isOn ? "开启" : "关闭")
    }
}

// Use AppKit's standard controls inside the custom 49-point title bar.
private struct WindowControls: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ControlsView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ControlsView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            subviews.forEach { $0.removeFromSuperview() }
            guard let window else { return }
            for (index, type) in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].enumerated() {
                guard let button = NSWindow.standardWindowButton(type, for: window.styleMask) else { continue }
                button.setFrameOrigin(NSPoint(x: index * 20, y: 1))
                button.target = window
                button.action = type == .closeButton ? #selector(NSWindow.performClose(_:)) :
                    type == .miniaturizeButton ? #selector(NSWindow.performMiniaturize(_:)) : #selector(NSWindow.performZoom(_:))
                addSubview(button)
            }
        }
    }
}

struct AccountAvatar: View {
    let name: String
    let size: CGFloat
    var body: some View {
        Text(String(name.prefix(1)).uppercased()).font(.system(size: 12, weight: .medium))
            .frame(width: size, height: size).background(Appearance.field, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Appearance.line))
    }
}

struct FeedbackView: View {
    let message: String?
    var body: some View {
        Text(message ?? " ").font(.system(size: 11)).foregroundStyle(Appearance.accent)
            .lineLimit(1).help(message ?? "").frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28, alignment: .leading)
            .accessibilityLabel(message ?? "").accessibilityHidden(message == nil)
    }
}

private struct EntryDetail: View {
    @ObservedObject var model: AppModel
    let entry: OTPEntry
    @State private var name = ""
    @State private var account = ""
    @State private var secret = ""
    @State private var algorithm = OTPAlgorithm.sha1
    @State private var digits = 6
    @State private var period = 30
    @State private var revealSecret = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.name).font(.system(size: 21, weight: .medium)).lineLimit(2)
                        Text(entry.account.isEmpty ? "—" : entry.account).font(.system(size: 11)).foregroundStyle(Appearance.muted)
                        HStack(spacing: 6) {
                            Circle().fill(entry.isVisibleInMenu ? Appearance.accent : Appearance.muted).frame(width: 5, height: 5)
                            Text(entry.isVisibleInMenu ? "已在菜单栏显示" : "已从菜单栏隐藏")
                        }.font(.system(size: 11)).foregroundStyle(Appearance.muted).padding(.top, 5)
                    }
                    Spacer()
                    if !model.isEditing { Button("编辑") { resetFields(); model.isEditing = true; model.message = nil } }
                }.padding(.bottom, 20)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let code = try? TOTP.generate(for: entry, at: context.date)
                    VStack(spacing: 8) {
                        HStack {
                            Text("当前验证码")
                            Spacer()
                            if let code { CodeCountdown(code: code, date: context.date, period: entry.period) }
                        }.font(.system(size: 11)).foregroundStyle(Appearance.muted)
                        HStack {
                            Text(code.map { groupedCode($0.value) } ?? "时间无效")
                                .font(.system(size: 30, weight: .medium, design: .monospaced)).monospacedDigit().tracking(1)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            Spacer(minLength: 8)
                            Button { model.copy(entry) } label: { Label("复制", systemImage: "doc.on.doc") }
                                .buttonStyle(CompactButtonStyle(primary: true)).disabled(code == nil)
                        }
                    }.padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Appearance.field, in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Appearance.line))
                }
                FeedbackView(message: model.message)
                VStack(spacing: 0) {
                    infoRow("名称") {
                        if model.isEditing { TextField("名称", text: $name) }
                        else { Text(name).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                    }
                    Appearance.line.frame(height: 1)
                    infoRow("账号") {
                        if model.isEditing { TextField("账号", text: $account) }
                        else { Text(account.isEmpty ? "—" : account).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                    }
                    Appearance.line.frame(height: 1)
                    infoRow("密钥") {
                        HStack {
                            if model.isEditing {
                                if revealSecret { TextField("密钥", text: $secret) }
                                else { SecureField("密钥", text: $secret) }
                                Button { revealSecret.toggle() } label: { Image(systemName: revealSecret ? "eye.slash" : "eye") }
                                    .buttonStyle(.plain).accessibilityLabel(revealSecret ? "隐藏密钥" : "显示密钥")
                            } else { Text("•••• •••• ••••").tracking(2).frame(maxWidth: .infinity, alignment: .leading) }
                        }
                    }
                }.padding(.horizontal, 12).background(Appearance.field, in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Appearance.line))
                if model.isEditing {
                    HStack(spacing: 8) {
                        Picker("算法", selection: $algorithm) { ForEach(OTPAlgorithm.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        Picker("位数", selection: $digits) { ForEach(5...8, id: \.self) { Text("\($0) 位").tag($0) } }
                        Picker("周期", selection: $period) { ForEach([10, 30, 60, 90], id: \.self) { Text("\($0) 秒").tag($0) } }
                    }.labelsHidden().padding(.top, 16)
                } else {
                    HStack(spacing: 16) { Text(entry.algorithm.rawValue); Text("\(entry.digits) 位"); Text("每 \(entry.period) 秒更新") }
                        .font(.system(size: 11)).foregroundStyle(Appearance.muted).padding(.top, 16)
                }
                if let error { Text(error).foregroundStyle(Appearance.danger).font(.system(size: 12)).padding(.top, 10) }
                Appearance.line.frame(height: 1).padding(.top, 20).padding(.bottom, 12)
                HStack {
                    if model.isEditing {
                        Spacer()
                        Button("取消") { model.isEditing = false; resetFields() }.keyboardShortcut(.cancelAction)
                        Button("保存", action: save).buttonStyle(CompactButtonStyle(primary: true)).keyboardShortcut(.defaultAction)
                    } else {
                        Button { model.deletingEntry = entry } label: { Label("删除账号", systemImage: "trash") }
                            .buttonStyle(CompactButtonStyle(destructive: true))
                        Spacer()
                        Label("仅保存在本机", systemImage: "lock").font(.system(size: 11)).foregroundStyle(Appearance.muted)
                    }
                }
            }.textFieldStyle(.plain).padding(.horizontal, 20).padding(.vertical, 22)
        }.onAppear(perform: resetFields)
    }

    private func resetFields() {
        name = entry.name; account = entry.account; secret = entry.secret
        algorithm = entry.algorithm; digits = entry.digits; period = entry.period
        revealSecret = false; error = nil
    }

    private func infoRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 11)).foregroundStyle(Appearance.muted).frame(width: 58, alignment: .leading)
            content().font(.system(size: 12)).padding(5)
                .background(model.isEditing ? Appearance.surface : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(model.isEditing ? Appearance.accent : Color.clear))
        }.frame(minHeight: 43)
    }

    private func save() {
        do {
            try model.update(OTPEntry(id: entry.id, name: name, account: account, secret: secret,
                                      algorithm: algorithm, digits: digits, period: period))
            revealSecret = false; error = nil
        } catch { self.error = error.localizedDescription }
    }
}

struct CodeCountdown: View {
    let code: OTPCode
    let date: Date
    let period: Int
    var body: some View {
        let remaining = max(0, code.validUntil.timeIntervalSince(date))
        HStack(spacing: 6) {
            ZStack {
                Circle().stroke(Appearance.line, lineWidth: 2)
                Circle().trim(from: 0, to: min(1, remaining / Double(period)))
                    .stroke(Appearance.accent, lineWidth: 2).rotationEffect(.degrees(-90))
            }.frame(width: 15, height: 15).accessibilityHidden(true)
            Text("\(Int(ceil(remaining))) 秒").monospacedDigit()
        }
    }
}

private struct DeleteView: View {
    @ObservedObject var model: AppModel
    let entry: OTPEntry
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("删除“\(entry.name)”？").font(.system(size: 18, weight: .medium)).padding(.bottom, 6)
            Text("只会删除这台 Mac 上的条目，手机 2FAS 中的数据不会改变。之后可以从备份重新导入。")
                .font(.system(size: 12)).foregroundStyle(Appearance.muted).fixedSize(horizontal: false, vertical: true)
            if let error { Text(error).font(.system(size: 12)).foregroundStyle(Appearance.danger).padding(.top, 10) }
            HStack(spacing: 8) {
                Spacer()
                Button("取消") { model.deletingEntry = nil }.keyboardShortcut(.defaultAction)
                Button("删除", role: .destructive) {
                    do { try model.remove(entry); model.deletingEntry = nil }
                    catch { self.error = error.localizedDescription }
                }.buttonStyle(CompactButtonStyle(primary: true, destructive: true))
            }.padding(.top, 24)
        }.padding(24).frame(width: 330)
            .buttonStyle(CompactButtonStyle()).onExitCommand { model.deletingEntry = nil }
    }
}

private struct ImportView: View {
    @ObservedObject var model: AppModel
    @State private var data: Data?
    @State private var fileName = ""
    @State private var password = ""
    @State private var needsPassword = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("导入 2FAS 备份").font(.system(size: 18, weight: .medium)).padding(.bottom, 6)
            Text("选择从手机 2FAS Auth 导出的 .2fas 文件。").font(.system(size: 12)).foregroundStyle(Appearance.muted).padding(.bottom, 20)
            Button(action: chooseFile) {
                Label(fileName.isEmpty ? "选择 .2fas 文件…" : fileName, systemImage: "folder")
                    .font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 7)
            }.padding(.bottom, 13)
            if needsPassword {
                VStack(alignment: .leading, spacing: 7) {
                    Text("备份密码").font(.system(size: 12))
                    SecureField("导出时设置的密码", text: $password).textFieldStyle(.roundedBorder).onSubmit(importBackup)
                }.padding(.top, 4)
            }
            if let error { Text(error).foregroundStyle(Appearance.danger).font(.system(size: 12)).padding(.top, 10) }
            Text("相同密钥及生成参数的条目会跳过，保留本机修改的名称。同名但密钥不同的账号会保留。")
                .font(.system(size: 11)).foregroundStyle(Appearance.muted).padding(.top, 17)
            HStack(spacing: 8) {
                Spacer()
                Button("取消") { model.importVisible = false }.keyboardShortcut(.cancelAction)
                Button("导入", action: importBackup).buttonStyle(CompactButtonStyle(primary: true))
                    .keyboardShortcut(.defaultAction).disabled(data == nil)
            }.padding(.top, 22)
        }.padding(24).frame(width: 330).font(.system(size: 13))
            .foregroundStyle(Appearance.text)
            .buttonStyle(CompactButtonStyle()).onDisappear { data = nil; password = "" }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "2fas") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "选择从手机 2FAS 导出的备份"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        data = nil; error = nil; password = ""; needsPassword = false; fileName = url.lastPathComponent
        do {
            let content = try Data(contentsOf: url)
            do { _ = try TwoFASImporter.read(content) }
            catch OTPError.passwordRequired { needsPassword = true }
            data = content
        } catch { self.error = error.localizedDescription }
    }

    private func importBackup() {
        guard let data else { return }
        do {
            _ = try model.importBackup(data, password: needsPassword ? password : nil)
            model.importVisible = false
        } catch { self.error = error.localizedDescription }
    }
}
