import AppKit
import OTPBarCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("验证码  \(model.entries.count)").font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                List(selection: Binding(get: { model.selectedID }, set: { id in
                    if model.isEditing { model.message = "请先保存或取消当前修改。" }
                    else if let id { model.selectedID = id; model.message = nil }
                })) {
                    ForEach(model.entries) { entry in
                        HStack(spacing: 9) {
                            Text(String(entry.name.prefix(1)).uppercased())
                                .fontWeight(.medium).frame(width: 29, height: 29)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.name).lineLimit(1)
                                if !entry.account.isEmpty { Text(entry.account).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                            }
                        }.padding(.vertical, 3).tag(entry.id)
                    }
                }.listStyle(.sidebar)
                Button { model.importVisible = true } label: {
                    Label("导入备份…", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
                }.disabled(model.isEditing || model.loadError != nil).padding([.horizontal, .bottom])
            }.padding(.top, 20).frame(width: 215).background(.bar)
            Divider()
            VStack(spacing: 0) {
                if let error = model.loadError {
                    ContentUnavailableView("无法读取本地数据", systemImage: "lock.trianglebadge.exclamationmark", description: Text(error))
                } else if let entry = model.selectedEntry {
                    EntryDetail(model: model, entry: entry).id(entry.id)
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "key.horizontal").font(.system(size: 36)).foregroundStyle(.secondary)
                        Text("还没有验证码").font(.title2)
                        Text("导入手机上的 2FAS 备份，即可在 Mac 上查看和复制。").foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("导入备份…") { model.importVisible = true }.buttonStyle(.borderedProminent)
                    }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if let message = model.message {
                    Divider()
                    HStack {
                        Text(message).font(.callout).textSelection(.enabled)
                        Spacer()
                        Button { model.message = nil } label: { Image(systemName: "xmark") }
                            .buttonStyle(.plain).accessibilityLabel("关闭提示")
                    }.padding(12).background(.bar)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $model.importVisible) { ImportView(model: model) }
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
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.name).font(.title2).fontWeight(.medium)
                        Text("基于时间的动态验证码").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !model.isEditing { Button("编辑") { resetFields(); model.isEditing = true; model.message = nil } }
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("当前验证码").font(.caption).foregroundStyle(.secondary)
                            Text((try? TOTP.generate(for: entry, at: context.date)).map { groupedCode($0.value) } ?? "时间无效")
                                .font(.system(size: 28, weight: .medium, design: .monospaced)).monospacedDigit()
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) {
                            Button { model.copy(entry) } label: { Label("复制", systemImage: "doc.on.doc") }
                            if let code = try? TOTP.generate(for: entry, at: context.date) {
                                Text("\(max(0, Int(ceil(code.validUntil.timeIntervalSince(context.date))))) 秒后刷新")
                                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            }
                        }
                    }.padding(16).background(.background, in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(.quaternary))
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text("账号信息").font(.caption).foregroundStyle(.secondary)
                    LabeledContent("名称") { TextField("名称", text: $name).disabled(!model.isEditing) }
                    LabeledContent("账号") { TextField("账号", text: $account).disabled(!model.isEditing) }
                    LabeledContent("密钥") {
                        HStack {
                            if revealSecret { TextField("密钥", text: $secret).disabled(!model.isEditing) }
                            else { SecureField("密钥", text: $secret).disabled(!model.isEditing) }
                            Button { revealSecret.toggle() } label: { Image(systemName: revealSecret ? "eye.slash" : "eye") }
                                .buttonStyle(.plain).accessibilityLabel(revealSecret ? "隐藏密钥" : "显示密钥")
                        }
                    }
                    DisclosureGroup("生成参数") {
                        VStack(spacing: 12) {
                            Picker("算法", selection: $algorithm) { ForEach(OTPAlgorithm.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                            Picker("位数", selection: $digits) { ForEach(5...8, id: \.self) { Text("\($0)").tag($0) } }
                            Picker("刷新周期", selection: $period) { ForEach([10, 30, 60, 90], id: \.self) { Text("\($0) 秒").tag($0) } }
                        }.disabled(!model.isEditing).padding(.top, 12)
                    }.padding(.top, 4)
                }.textFieldStyle(.roundedBorder)
                if let error { Text(error).foregroundStyle(.red).font(.callout) }
                Text("修改仅保存在这台 Mac，不会更改手机上的账号。").font(.caption).foregroundStyle(.secondary)
                if model.isEditing {
                    HStack {
                        Spacer()
                        Button("取消") { model.isEditing = false; resetFields() }.keyboardShortcut(.cancelAction)
                        Button("保存修改", action: save).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    }
                } else {
                    Divider()
                    Button("删除账号…", role: .destructive) { confirmingDelete = true }
                }
            }.padding(28)
        }
        .onAppear(perform: resetFields)
        .alert("删除“\(entry.name)”？", isPresented: $confirmingDelete) {
            Button("取消", role: .cancel) {}.keyboardShortcut(.defaultAction)
            Button("删除", role: .destructive) {
                do { try model.remove(entry) }
                catch { self.error = error.localizedDescription }
            }
        } message: {
            Text("只会删除这台 Mac 上的条目，手机 2FAS 中的数据不会改变。之后可以从备份重新导入。")
        }
    }

    private func resetFields() {
        name = entry.name; account = entry.account; secret = entry.secret
        algorithm = entry.algorithm; digits = entry.digits; period = entry.period
        revealSecret = false; error = nil
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

private struct ImportView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var data: Data?
    @State private var fileName = ""
    @State private var password = ""
    @State private var needsPassword = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "doc.badge.arrow.up").font(.title).foregroundStyle(.tint)
            Text("导入 2FAS 备份").font(.title2).fontWeight(.medium)
            Text("选择从手机 2FAS Auth 导出的 .2fas 文件。").foregroundStyle(.secondary)
            Button(action: chooseFile) { Label(fileName.isEmpty ? "选择 .2fas 文件…" : fileName, systemImage: "folder") }
            if needsPassword { SecureField("备份密码", text: $password).textFieldStyle(.roundedBorder).onSubmit(importBackup) }
            if let error { Text(error).foregroundStyle(.red).font(.callout) }
            Text("相同密钥及生成参数的条目会跳过，保留本机修改的名称。同名但密钥不同的账号会保留。")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("导入", action: importBackup).buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction).disabled(data == nil)
            }
        }.padding(28).frame(width: 430).onDisappear { data = nil; password = "" }
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
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
