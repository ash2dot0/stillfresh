import SwiftUI

struct GlassCard<Content: View>: View {
    @Environment(\.glassCardStyle) private var style
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(style.padding)
            .background(style.material, in: RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .strokeBorder(style.strokeColor, lineWidth: style.strokeLineWidth)
            )
    }
}

struct ColorfulCard<Content: View>: View {
    @Environment(\.colorfulCardStyle) private var style
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(style.padding)
            .background(
                LinearGradient(colors: style.colors, startPoint: style.startPoint, endPoint: style.endPoint),
                in: RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .strokeBorder(style.strokeColor, lineWidth: style.strokeLineWidth)
            )
    }
}

