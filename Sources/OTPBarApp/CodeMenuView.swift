import OTPBarCore
import SwiftUI

struct CodeMenuView: View {
    @ObservedObject var model: AppModel
    let contextOnly: Bool
    let close: () -> Void
    let settings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if !contextOnly {
                HStack {
                    Text("OTPBar")
                    Spacer()
                    Text("显示 \(model.menuEntries.count) / \(model.entries.count)")
                }.font(.system(size: 11)).foregroundStyle(Appearance.muted)
                    .padding(.horizontal, 9).padding(.top, 7).padding(.bottom, 12)
                if model.loadError != nil {
                    emptyState("无法读取本地数据", detail: "请打开设置查看详情。")
                } else if model.entries.isEmpty {
                    emptyState("还没有验证码", detail: "在设置中导入手机上的 2FAS 备份。")
                } else if model.menuEntries.isEmpty {
                    emptyState("暂无显示的验证码", detail: "在设置中开启账号的菜单栏显示。")
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(model.menuEntries) { entry in
                                CodeMenuRow(entry: entry) {
                                    if model.copy(entry, fromMenu: true) { close() }
                                }
                            }
                        }
                    }.frame(height: min(CGFloat(model.menuEntries.count) * 99, 495))
                }
                FeedbackView(message: model.menuMessage).padding(.horizontal, 10)
                Appearance.line.frame(height: 1)
                HStack {
                    MenuCommand(title: "设置", icon: "slider.horizontal.3") { close(); settings() }
                    Spacer(minLength: 4)
                    MenuCommand(title: "退出 OTPBar", icon: "power") { close(); quit() }
                }.padding(.horizontal, 3).padding(.top, 7)
            } else {
                MenuCommand(title: "设置", icon: "slider.horizontal.3") { close(); settings() }
                    .frame(maxWidth: .infinity, alignment: .leading)
                Appearance.line.frame(height: 1).padding(.vertical, 6)
                MenuCommand(title: "退出 OTPBar", icon: "power") { close(); quit() }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(7).frame(width: contextOnly ? 220 : 282)
            .foregroundStyle(Appearance.text).background(Appearance.surface)
            .onExitCommand(perform: close)
    }

    private func emptyState(_ title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.system(size: 13))
            Text(detail).font(.system(size: 11)).foregroundStyle(Appearance.muted)
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity).frame(height: 160)
    }
}

private struct CodeMenuRow: View {
    let entry: OTPEntry
    let copy: () -> Void
    @State private var hovering = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let code = try? TOTP.generate(for: entry, at: context.date)
            Button(action: copy) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        AccountAvatar(name: entry.name, size: 25)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                            Text(entry.account.isEmpty ? "—" : entry.account).font(.system(size: 11))
                                .foregroundStyle(Appearance.muted).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    HStack {
                        Text(code.map { groupedCode($0.value) } ?? "时间无效")
                            .font(.system(size: 24, weight: .medium, design: .monospaced)).tracking(1).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        if let code {
                            Text("\(max(0, Int(ceil(code.validUntil.timeIntervalSince(context.date)))))s")
                                .font(.system(size: 11)).monospacedDigit().foregroundStyle(Appearance.muted)
                        }
                    }.padding(.leading, 33)
                }.padding(.horizontal, 10).frame(height: 99)
                    .foregroundStyle(Appearance.text)
                    .background(hovering ? Appearance.selected : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(code == nil).onHover { hovering = $0 }
        }
    }
}

private struct MenuCommand: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 11))
                .padding(.horizontal, 6).frame(height: 32)
                .background(hovering ? Appearance.selected : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hovering = $0 }
    }
}
