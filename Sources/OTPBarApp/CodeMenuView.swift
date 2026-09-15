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
                    Text("点击验证码复制")
                }.font(.system(size: 11)).foregroundStyle(Appearance.muted)
                    .padding(.horizontal, 9).padding(.top, 6).padding(.bottom, 8)
                if model.loadError != nil {
                    Text("无法读取本地数据，请打开设置").font(.system(size: 12)).padding(14)
                } else if model.entries.isEmpty {
                    Text("还没有验证码，请在设置中导入备份。").font(.system(size: 12)).foregroundStyle(Appearance.muted).padding(14)
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(model.entries) { entry in
                                CodeMenuRow(entry: entry) { model.copy(entry); close() }
                            }
                        }
                    }.frame(height: min(CGFloat(model.entries.count) * 67, 470))
                }
                separator
            }
            MenuCommand(title: "设置…", icon: "gearshape", shortcut: "⌘,") { close(); settings() }
            if contextOnly {
                separator
                MenuCommand(title: "退出 OTPBar", icon: nil, shortcut: "⌘Q") { close(); quit() }
            }
        }.padding(6).frame(width: contextOnly ? 220 : 292)
            .foregroundStyle(Appearance.text).background(Appearance.surface)
            .onExitCommand(perform: close)
    }

    private var separator: some View { Appearance.line.frame(height: 1).padding(.horizontal, 6).padding(.vertical, 6) }
}

private struct CodeMenuRow: View {
    let entry: OTPEntry
    let copy: () -> Void
    @State private var hovering = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let code = try? TOTP.generate(for: entry, at: context.date)
            Button(action: copy) {
                VStack(spacing: 3) {
                    HStack(spacing: 8) {
                        Text(entry.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(entry.account).font(.system(size: 11)).lineLimit(1).truncationMode(.middle)
                            .foregroundStyle(hovering ? Color.white : Appearance.muted).frame(maxWidth: 165, alignment: .trailing)
                    }
                    HStack {
                        Text(code.map { groupedCode($0.value) } ?? "时间无效")
                            .font(.system(size: 22, weight: .medium, design: .monospaced)).tracking(1).monospacedDigit()
                        Spacer(minLength: 4)
                        if let code {
                            Label("\(max(0, Int(ceil(code.validUntil.timeIntervalSince(context.date))))) 秒", systemImage: "timer")
                                .font(.system(size: 11)).monospacedDigit().foregroundStyle(hovering ? Color.white : Appearance.muted)
                        }
                    }
                }.padding(.horizontal, 10).padding(.vertical, 8)
                    .foregroundStyle(hovering ? Color.white : Appearance.text)
                    .background(hovering ? Color(red: 0.027, green: 0.396, blue: 0.812) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(code == nil).onHover { hovering = $0 }
        }
    }
}

private struct MenuCommand: View {
    let title: String
    let icon: String?
    let shortcut: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).frame(width: 14) }
                Text(title).font(.system(size: 13))
                Spacer()
                Text(shortcut).font(.system(size: 12)).foregroundStyle(Appearance.muted)
            }.padding(.horizontal, 9).padding(.vertical, 6)
                .background(hovering ? Appearance.selected : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hovering = $0 }
    }
}
