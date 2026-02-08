import SwiftUI
import Combine

struct SnackbarView: View {
    let state: SnackbarState
    let onClose: () -> Void
    @State private var remaining: Int = 5
    @State private var timerCancellable: AnyCancellable?

    var body: some View {
        HStack(spacing: 12) {
            Text(state.message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 8)

            Button(state.actionTitle) {
                state.action()
            }
            .font(.subheadline)
            .buttonStyle(.borderedProminent)
            .tint(.primary.opacity(0.15))

            Text("(\(remaining))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(radius: 12, y: 8)
        .onAppear {
            remaining = 5
            timerCancellable?.cancel()
            timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    if remaining > 0 {
                        remaining -= 1
                    } else {
                        onClose()
                    }
                }
        }
        .onDisappear {
            timerCancellable?.cancel()
            timerCancellable = nil
        }
    }
}
