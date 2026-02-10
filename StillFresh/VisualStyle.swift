import SwiftUI

// MARK: - GlassCard style

public struct GlassCardStyle {
    public var padding: CGFloat
    public var cornerRadius: CGFloat
    public var material: Material
    public var strokeColor: Color
    public var strokeLineWidth: CGFloat

    public init(
        padding: CGFloat = 14,
        cornerRadius: CGFloat = 20,
        material: Material = .ultraThinMaterial,
        strokeColor: Color = .white.opacity(0.12),
        strokeLineWidth: CGFloat = 1
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.material = material
        self.strokeColor = strokeColor
        self.strokeLineWidth = strokeLineWidth
    }
}

private struct GlassCardStyleKey: EnvironmentKey {
    static let defaultValue = GlassCardStyle()
}

public extension EnvironmentValues {
    var glassCardStyle: GlassCardStyle {
        get { self[GlassCardStyleKey.self] }
        set { self[GlassCardStyleKey.self] = newValue }
    }
}

public extension View {
    func glassCardStyle(_ style: GlassCardStyle) -> some View {
        environment(\.glassCardStyle, style)
    }
}

// MARK: - ColorfulCard style

public struct ColorfulCardStyle: Equatable {
    public var padding: CGFloat
    public var cornerRadius: CGFloat
    public var colors: [Color]
    public var startPoint: UnitPoint
    public var endPoint: UnitPoint
    public var strokeColor: Color
    public var strokeLineWidth: CGFloat

    public init(
        padding: CGFloat = 14,
        cornerRadius: CGFloat = 20,
        colors: [Color] = [Color.purple.opacity(0.25), Color.blue.opacity(0.25)],
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing,
        strokeColor: Color = .white.opacity(0.12),
        strokeLineWidth: CGFloat = 1
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.colors = colors
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.strokeColor = strokeColor
        self.strokeLineWidth = strokeLineWidth
    }
}

private struct ColorfulCardStyleKey: EnvironmentKey {
    static let defaultValue = ColorfulCardStyle()
}

public extension EnvironmentValues {
    var colorfulCardStyle: ColorfulCardStyle {
        get { self[ColorfulCardStyleKey.self] }
        set { self[ColorfulCardStyleKey.self] = newValue }
    }
}

public extension View {
    func colorfulCardStyle(_ style: ColorfulCardStyle) -> some View {
        environment(\.colorfulCardStyle, style)
    }
}

// MARK: - Home row (item cell) style

public struct HomeRowStyle: Equatable {
    public var primaryHStackSpacing: CGFloat
    public var secondaryHStackSpacing: CGFloat
    public var avatarSize: CGFloat
    public var iconEmojiSize: CGFloat
    public var storageBadgeSize: CGFloat
    public var storageIconFontSize: CGFloat
    public var storageBadgeOffset: CGSize
    public var titleFont: Font
    public var subtitleFont: Font
    public var smallSubtitleFont: Font
    public var quantityHorizontalPadding: CGFloat
    public var quantityVerticalPadding: CGFloat
    public var progressHeight: CGFloat
    public var topSpacing: CGFloat

    public init(
        primaryHStackSpacing: CGFloat = 6,
        secondaryHStackSpacing: CGFloat = 8,
        avatarSize: CGFloat = 30,
        iconEmojiSize: CGFloat = 20,
        storageBadgeSize: CGFloat = 16,
        storageIconFontSize: CGFloat = 10,
        storageBadgeOffset: CGSize = CGSize(width: 10, height: 6),
        titleFont: Font = .callout.weight(.semibold),
        subtitleFont: Font = .caption,
        smallSubtitleFont: Font = .caption,
        quantityHorizontalPadding: CGFloat = 5,
        quantityVerticalPadding: CGFloat = 2,
        progressHeight: CGFloat = 3,
        topSpacing: CGFloat = 1
    ) {
        self.primaryHStackSpacing = primaryHStackSpacing
        self.secondaryHStackSpacing = secondaryHStackSpacing
        self.avatarSize = avatarSize
        self.iconEmojiSize = iconEmojiSize
        self.storageBadgeSize = storageBadgeSize
        self.storageIconFontSize = storageIconFontSize
        self.storageBadgeOffset = storageBadgeOffset
        self.titleFont = titleFont
        self.subtitleFont = subtitleFont
        self.smallSubtitleFont = smallSubtitleFont
        self.quantityHorizontalPadding = quantityHorizontalPadding
        self.quantityVerticalPadding = quantityVerticalPadding
        self.progressHeight = progressHeight
        self.topSpacing = topSpacing
    }
}

private struct HomeRowStyleKey: EnvironmentKey {
    static let defaultValue = HomeRowStyle()
}

public extension EnvironmentValues {
    var homeRowStyle: HomeRowStyle {
        get { self[HomeRowStyleKey.self] }
        set { self[HomeRowStyleKey.self] = newValue }
    }
}

public extension View {
    func homeRowStyle(_ style: HomeRowStyle) -> some View {
        environment(\.homeRowStyle, style)
    }
}

