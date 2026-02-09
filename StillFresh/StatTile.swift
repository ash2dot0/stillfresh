import SwiftUI

struct StatTile: View {
    let mainTitle: String
    let subtitle: String
    let amount: String
    let color: Color
    var fixedHeight: CGFloat = 112

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {

                VStack(alignment: .leading, spacing: 2) {
                    GeometryReader { geo in
                        // Inner width after padding. Clamp and scale to feel like the rest of the UI.
                        let w = max(0, geo.size.width)
                        let size = min(19, max(15, w * 0.105))

                        Text(mainTitle)
                            .font(.system(size: size, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .allowsTightening(true)
                    }
                    .frame(height: 18)

                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Text(amount)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: fixedHeight)
    }
}

