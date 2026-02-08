import SwiftUI

struct ProcessingOverlay: View {
    let stage: ProcessingStage
    let progress: Double // 0...1 (real progress signal from the pipeline)
    let hint: String

    @State private var pulse = false

    // Display progress: smooth + continuously advancing while we wait.
    @State private var displayProgress: Double = 0
    @State private var lastSeenProgress: Double = 0
    @State private var lastProgressBump: Date = .init()

    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

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

                    // Progress arc (uses smoothed display progress)
                    Circle()
                        .trim(from: 0, to: max(0.02, min(1, displayProgress)))
                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 66, height: 66)
                        .foregroundStyle(.white.opacity(0.85))
                        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: displayProgress)

                    Image(systemName: symbolForStage(stage))
                        .font(.system(size: 22, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.92))
                }

                VStack(spacing: 10) {
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

                    ModernProgressBar(progress: displayProgress)
                        .padding(.horizontal, 22)
                        .padding(.top, 2)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 26)
        }
        .onAppear {
            pulse = true
            displayProgress = max(0.02, min(0.25, progress))
            lastSeenProgress = progress
            lastProgressBump = Date()
        }
        .onChange(of: progress) { _, newValue in
            if newValue > lastSeenProgress {
                lastSeenProgress = newValue
                lastProgressBump = Date()
            }
        }
        .onReceive(timer) { _ in
            tick()
        }
    }

    private func tick() {
        // Always snap upward to real progress (never backwards).
        displayProgress = max(displayProgress, min(1, progress))

        // If real progress is stalled, keep advancing smoothly but conservatively.
        let stalledFor = Date().timeIntervalSince(lastProgressBump)

        if progress >= 1.0 {
            if displayProgress < 1.0 {
                withAnimation(.easeOut(duration: 0.25)) { displayProgress = 1.0 }
            }
            return
        }

        // Allow the animation to lead real progress slightly (feels continuous),
        // but never exceed +0.12, and never exceed 0.92 unless real progress does.
        let leadCap = min(0.92, progress + 0.12)

        if stalledFor > 0.25, displayProgress < leadCap {
            // Ease towards leadCap with diminishing increments as we approach it.
            let remaining = max(0, leadCap - displayProgress)
            let step = max(0.002, remaining * 0.08)  // slows down near the cap
            displayProgress = min(leadCap, displayProgress + step)
        }
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

private struct ModernProgressBar: View {
    let progress: Double

    @State private var sheen = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let filled = max(0.06, min(1.0, progress)) * w

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.10))

                Capsule()
                    .fill(.white.opacity(0.70))
                    .frame(width: filled)

                // Moving sheen for a modern "processing" feel.
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.00),
                                .white.opacity(0.35),
                                .white.opacity(0.00)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 64)
                    .offset(x: sheen ? w + 64 : -64)
                    .opacity(0.9)
                    .blendMode(.plusLighter)
                    .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: sheen)
            }
            .onAppear { sheen = true }
        }
        .frame(height: 10)
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }
}
