import AppKit
import SwiftUI

enum Appearance {
    static let surface = color(0xfafbfc, 0x21242b)
    static let sidebar = color(0xeff1f5, 0x1b1e25)
    static let field = color(0xffffff, 0x292d36)
    static let line = color(0xdce1e9, 0x393f4c)
    static let selected = color(0xe5edfc, 0x303e59)
    static let text = color(0x252e3c, 0xedf1f8)
    static let muted = color(0x647083, 0xa6b0c0)
    static let danger = color(0xb23b49, 0xefa0a9)
    static let accent = color(0x2863cc, 0xa7c5ff)
    static let action = color(0x306ad5, 0x507aca)

    private static func color(_ light: Int, _ dark: Int) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((hex >> 16) & 255) / 255,
                           green: Double((hex >> 8) & 255) / 255,
                           blue: Double(hex & 255) / 255, alpha: 1)
        })
    }
}

struct CompactButtonStyle: ButtonStyle {
    var primary = false
    var destructive = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .regular))
            .padding(.horizontal, 11).frame(minHeight: 32)
            .foregroundStyle(primary ? Color.white : destructive ? Appearance.danger : Appearance.text)
            .background(primary ? (destructive ? Appearance.danger : Appearance.action) : destructive ? Color.clear : Appearance.field,
                        in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(primary || destructive ? Color.clear : Appearance.line))
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}
