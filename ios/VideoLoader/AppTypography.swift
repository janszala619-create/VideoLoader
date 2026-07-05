import SwiftUI

enum AppTypography {
    static let largeTitle = Font.system(size: 34, weight: .semibold, design: .default)
    static let title1 = Font.system(size: 28, weight: .semibold, design: .default)
    static let title2 = Font.system(size: 24, weight: .semibold, design: .default)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .default)

    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let subheadline = Font.system(size: 15, weight: .medium, design: .default)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let callout = Font.system(size: 16, weight: .regular, design: .default)
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .medium, design: .default)

    static let button = Font.system(size: 17, weight: .semibold, design: .default)
    static let label = Font.system(size: 12, weight: .semibold, design: .default)
    static let mono = Font.system(size: 13, weight: .medium, design: .monospaced)
}
