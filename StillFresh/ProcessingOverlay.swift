import SwiftUI

struct ProcessingOverlay: View {
    let stage: ProcessingStage
    let progress: Double // 0...1
    let hint: String

    @State private var pulse = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.28))
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 92, height: 92)
                        .overlay(
                            Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1)
                        )

                    // "Liquid" pulse ring
                    Circle()
                        .stroke(.white.opacity(0.25), lineWidth: 2)
                        .frame(width: pulse ? 92 : 56, height: pulse ? 92 : 56)
                        .opacity(pulse ? 0.1 : 0.5)
                        .blur(radius: pulse ? 0 : 0.5)
                        .animation(.easeOut(duration: 0.9).repeatForever(autoreverses: false), value: pulse)

                    // Progress arc
                    Circle()
                        .trim(from: 0, to: max(0.02, min(1, progress)))
                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 66, height: 66)
                        .foregroundStyle(.white.opacity(0.85))
                        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: progress)

                    Image(systemName: symbolForStage(stage))
                        .font(.system(size: 22, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.92))
                }

                VStack(spacing: 6) {
                    Text(stage.rawValue)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(hint)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 26)
        }
        .onAppear { pulse = true }
    }

    private func symbolForStage(_ stage: ProcessingStage) -> String {
        switch stage {
        case .capturing: return "camera.fill"
        case .enhancing: return "wand.and.stars"
        case .understanding: return "brain.head.profile"
        case .organizing: return "square.grid.2x2.fill"
        }
    }
}