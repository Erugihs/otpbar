import AppKit
import SwiftUI

enum Appearance {
    static let surface = color(0xf8f8f8, 0x292a2d)
    static let sidebar = color(0xeeeeef, 0x242528)
    static let field = color(0xffffff, 0x35363a)
    static let line = color(0xdedee2, 0x44464c)
    static let selected = color(0xdedfe3, 0x42444a)
    static let text = color(0x202124, 0xf1f1f3)
    static let muted = color(0x62656b, 0xa8abb2)
    static let danger = color(0xb42318, 0xff9c91)

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
            .font(.system(size: 13))
            .padding(.horizontal, 12).frame(minHeight: 28)
            .foregroundStyle(primary ? Color.white : destructive ? Appearance.danger : Appearance.text)
            .background(primary ? Color(red: 0.027, green: 0.396, blue: 0.812) : Appearance.field,
                        in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(primary ? Color.clear : Appearance.line))
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}
