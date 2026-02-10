import SwiftUI

struct StatTile: View {
    let mainTitle: String
    let subtitle: String

    // Primary value (top line)
    let amount: String
    let color: Color

    // Optional secondary value (second line)
    var secondaryLabel: String? = nil
    var secondaryAmount: String? = nil
    var secondaryColor: Color = .green

    var fixedHeight: CGFloat = 96
    var cornerRadius: CGFloat = 22

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {

                HStack(alignment: .center, spacing: 2) {
                    Text(mainTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(amount)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let secondaryAmount, !secondaryAmount.isEmpty {
                        HStack(spacing: 6) {
                            if let secondaryLabel, !secondaryLabel.isEmpty {
                                Text("\(secondaryLabel):")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            Text(secondaryAmount)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(secondaryColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        // ✅ Rounded corners guaranteed (no “one tile looks square” issues)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .frame(height: fixedHeight)
    }
}

