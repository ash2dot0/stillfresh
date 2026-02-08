import SwiftUI

struct ProcessingOverlay: View {
    let stage: ProcessingStage
    let progress: Double // 0...1 (real progress signal from the pipeline)
    let hint: String

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

                    // Single circular progress indicator (smooth + playful but minimal)
                    ProgressView(value: max(0.02, min(1, displayProgress)))
                        .progressViewStyle(.circular)
                        .tint(.white.opacity(0.85))
                        .frame(width: 66, height: 66)
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

