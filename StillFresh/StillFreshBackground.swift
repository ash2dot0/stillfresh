import SwiftUI

struct StillFreshBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.mint.opacity(0.28),
                Color.cyan.opacity(0.22),
                Color.blue.opacity(0.18),
                Color(uiColor: .systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
