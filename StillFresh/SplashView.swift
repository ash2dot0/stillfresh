import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "leaf.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(.green)
                Text("StillFresh")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
            )
        }
    }
}

#Preview {
    SplashView()
}
