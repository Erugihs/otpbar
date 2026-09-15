import AppKit
import OTPBarCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Color.clear.frame(width: 78, height: 1)
                Spacer()
                Text("OTPBar — 设置").font(.system(size: 14, weight: .medium))
                Spacer()
                Text("本地存储").font(.system(size: 11)).foregroundStyle(Appearance.muted)
                    .frame(width: 78, alignment: .trailing)
            }.padding(.horizontal, 18).frame(height: 52).background(Appearance.sidebar)
                .overlay(alignment: .bottom) { Appearance.line.frame(height: 1) }
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("验证码  \(model.entries.count)").font(.system(size: 12, weight: .medium)).foregroundStyle(Appearance.muted).padding(.horizontal, 20).padding(.bottom, 10)
                ScrollView {
                  VStack(spacing: 5) {
                    ForEach(model.entries) { entry in
                      Button {
                        if model.isEditing { model.message = "请先保存或取消当前修改。" }
                        else { model.selectedID = entry.id; model.message = nil }
                      } label: {
                        HStack(spacing: 10) {
                            Text(String(entry.name.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .medium)).frame(width: 30, height: 30)
                                .background(Appearance.field, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Appearance.line))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                if !entry.account.isEmpty { Text(entry.account).font(.system(size: 11)).foregroundStyle(Appearance.muted).lineLimit(1) }
                            }
                            Spacer(minLength: 0)
                        }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                          .background(model.selectedID == entry.id ? Appearance.selected : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                      }.buttonStyle(.plain).accessibilityAddTraits(model.selectedID == entry.id ? .isSelected : [])
                    }
                  }.padding(.horizontal, 10)
                }
                Button { model.importVisible = true } label: {
                    Label("导入备份…", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
                }.disabled(model.isEditing || model.loadError != nil).padding(.horizontal, 10).padding(.top, 32).padding(.bottom, 12)
            }.padding(.top, 18).frame(width: 210).background(Appearance.sidebar)
            Divider()
            VStack(spacing: 0) {
                if let error = model.loadError {
                    ContentUnavailableView("无法读取本地数据", systemImage: "lock.trianglebadge.exclamationmark", description: Text(error))
                } else if let entry = model.selectedEntry {
                    EntryDetail(model: model, entry: entry).id(entry.id)
                } else {
                    VStack(spacing: 14) {
                        Text("还没有验证码").font(.system(size: 18, weight: .medium))
                        Text("导入手机上的 2FAS 备份，即可在 Mac 上查看和复制。")
                            .foregroundStyle(Appearance.muted).multilineTextAlignment(.center).frame(maxWidth: 270)
                        Button("导入备份…") { model.importVisible = true }.buttonStyle(CompactButtonStyle(primary: true))
                    }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        }
        .overlay(alignment: .bottom) {
                if let message = model.message {
                    HStack {
                        Text(message).font(.system(size: 12)).textSelection(.enabled)
                        Button { model.message = nil } label: { Image(systemName: "xmark") }
                            .buttonStyle(.plain).accessibilityLabel("关闭提示")
                    }.padding(.vertical, 9).padding(.horizontal, 17)
                        .background(Appearance.surface, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Appearance.line))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4).padding(.bottom, 12)
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
        .font(.system(size: 14)).foregroundStyle(Appearance.text)
        .background(Appearance.surface).buttonStyle(CompactButtonStyle())
        .ignoresSafeArea(.container, edges: .top)
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
    @State private var parametersExpanded = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.name).font(.system(size: 20, weight: .medium))
                        Text("基于时间的动态验证码").font(.system(size: 12)).foregroundStyle(Appearance.muted)
                    }
                    Spacer()
                    if !model.isEditing { Button("编辑") { resetFields(); model.isEditing = true; model.message = nil } }
                }.frame(height: 45.4, alignment: .top).padding(.bottom, 18)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("当前验证码").font(.system(size: 11)).foregroundStyle(Appearance.muted)
                            Text((try? TOTP.generate(for: entry, at: context.date)).map { groupedCode($0.value) } ?? "时间无效")
                                .font(.system(size: 25, weight: .medium, design: .monospaced)).monospacedDigit().tracking(1.4)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 7) {
                            Button { model.copy(entry) } label: { Label("复制", systemImage: "doc.on.doc") }
                            if let code = try? TOTP.generate(for: entry, at: context.date) {
                                Text("\(max(0, Int(ceil(code.validUntil.timeIntervalSince(context.date))))) 秒后刷新")
                                    .font(.system(size: 11)).foregroundStyle(Appearance.muted).monospacedDigit()
                            }
                        }
                    }.padding(.horizontal, 16).frame(height: 83.25).background(Appearance.field, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Appearance.line))
                }.padding(.bottom, 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text("账号信息").font(.system(size: 12, weight: .medium)).foregroundStyle(Appearance.muted).frame(height: 15).padding(.bottom, 9)
                    VStack(spacing: 0) {
                    infoRow("名称") {
                        if model.isEditing { TextField("名称", text: $name) }
                        else { Text(name).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                    }
                    Divider()
                    infoRow("账号") {
                        if model.isEditing { TextField("账号", text: $account) }
                        else { Text(account.isEmpty ? "—" : account).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                    }
                    Divider()
                    infoRow("密钥") {
                        HStack {
                            if model.isEditing {
                                if revealSecret { TextField("密钥", text: $secret) }
                                else { SecureField("密钥", text: $secret) }
                            } else {
                                Text(revealSecret ? secret : String(repeating: "•", count: min(secret.count, 32))).lineLimit(1).font(.system(size: 13, design: .monospaced)).tracking(1)
                                    .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                            }
                            Button { revealSecret.toggle() } label: { Image(systemName: revealSecret ? "eye.slash" : "eye") }
                                .buttonStyle(.plain).accessibilityLabel(revealSecret ? "隐藏密钥" : "显示密钥")
                        }
                    }
                    }.background(Appearance.field, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Appearance.line))
                    VStack(alignment: .leading, spacing: 0) {
                        Button { parametersExpanded.toggle() } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "triangle.fill").font(.system(size: 7))
                                    .rotationEffect(.degrees(parametersExpanded ? 180 : 90))
                                Text("生成参数")
                            }.frame(height: 17.4)
                        }.buttonStyle(.plain).accessibilityValue(parametersExpanded ? "已展开" : "已折叠")
                        if parametersExpanded {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("算法")
                                Picker("算法", selection: $algorithm) { ForEach(OTPAlgorithm.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(maxWidth: .infinity)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 7) {
                                Text("位数")
                                Picker("位数", selection: $digits) { ForEach(5...8, id: \.self) { Text("\($0)").tag($0) } }.labelsHidden().frame(maxWidth: .infinity)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 7) {
                                Text("刷新周期")
                                Picker("刷新周期", selection: $period) { ForEach([10, 30, 60, 90], id: \.self) { Text("\($0) 秒").tag($0) } }.labelsHidden().frame(maxWidth: .infinity)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.disabled(!model.isEditing).padding(.top, 12)
                        }
                    }.font(.system(size: 12)).foregroundStyle(Appearance.muted).padding(.top, 14).padding(.bottom, 10)
                }.textFieldStyle(.plain)
                if let error { Text(error).foregroundStyle(.red).font(.callout) }
                Text("修改仅保存在这台 Mac，不会更改手机上的账号。").font(.system(size: 11)).foregroundStyle(Appearance.muted).frame(height: 16).padding(.top, 17)
                if model.isEditing {
                    HStack {
                        Spacer()
                        Button("取消") { model.isEditing = false; resetFields() }.keyboardShortcut(.cancelAction)
                        Button("保存修改", action: save).buttonStyle(CompactButtonStyle(primary: true)).keyboardShortcut(.defaultAction)
                    }.padding(.top, 15)
                } else {
                    Appearance.line.frame(height: 1).padding(.top, 20)
                    Button("删除账号…", role: .destructive) { model.deletingEntry = entry }.buttonStyle(CompactButtonStyle(destructive: true)).padding(.top, 15)
                }
            }.padding(.horizontal, 28).padding(.top, 23).padding(.bottom, 22)
        }
        .onAppear(perform: resetFields)
    }

    private func resetFields() {
        name = entry.name; account = entry.account; secret = entry.secret
        algorithm = entry.algorithm; digits = entry.digits; period = entry.period
        revealSecret = false; error = nil
    }

    private func infoRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 12)).foregroundStyle(Appearance.muted).frame(width: 83, alignment: .leading)
            content().font(.system(size: 13)).padding(.horizontal, 5).padding(.vertical, 3)
                .background(model.isEditing ? Appearance.surface : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(model.isEditing ? Appearance.line : Color.clear))
        }.padding(.horizontal, 13).frame(height: 47.5)
    }

    private func save() {
        do {
            try model.update(OTPEntry(id: entry.id, name: name, account: account, secret: secret,
                                      algorithm: algorithm, digits: digits, period: period))
            revealSecret = false
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}

private struct DeleteView: View {
    @ObservedObject var model: AppModel
    let entry: OTPEntry
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "trash").font(.system(size: 23)).foregroundStyle(.blue)
                .frame(width: 43, height: 43).background(Appearance.selected, in: RoundedRectangle(cornerRadius: 10)).padding(.bottom, 14)
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
        }.padding(.horizontal, 26).padding(.top, 25).padding(.bottom, 20).frame(width: 410)
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
            Image(systemName: "doc.badge.arrow.up").font(.system(size: 23)).foregroundStyle(.blue)
                .frame(width: 43, height: 43).background(Appearance.selected, in: RoundedRectangle(cornerRadius: 10)).padding(.bottom, 14)
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
        }.padding(.horizontal, 26).padding(.top, 25).padding(.bottom, 20).frame(width: 410).font(.system(size: 13))
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
