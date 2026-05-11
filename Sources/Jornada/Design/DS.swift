import SwiftUI

enum DS {
    static let hPadding: CGFloat = 16
    static let rowVPadding: CGFloat = 6
    static let sectionSpacing: CGFloat = 12
    static let cornerRadius: CGFloat = 8

    static let sectionFont = Font.system(size: 11, weight: .semibold)
    static let bodyFont = Font.system(size: 12)
    static let monoFont = Font.system(size: 12, design: .monospaced)
    static let smallMonoFont = Font.system(size: 11, design: .monospaced)
    static let labelFont = Font.system(size: 11)

    static let secondaryColor = Color.secondary
    static let tertiaryColor = Color.secondary.opacity(0.5)
    static let cardBackground = Color(NSColor.controlBackgroundColor)

    static func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(sectionFont)
            .foregroundStyle(secondaryColor)
            .tracking(0.5)
    }
}
