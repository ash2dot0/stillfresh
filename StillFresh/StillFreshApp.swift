import SwiftUI

@main
struct StillFreshApp: App {
    @StateObject private var store = AppStore()
    // 0 = System, 1 = Light, 2 = Dark
    @AppStorage("sf_appearance") private var appearanceRaw: Int = 0
    @State private var showAppSplash: Bool = true

    private var preferredScheme: ColorScheme? {
        switch appearanceRaw {
        case 1: return .light
        case 2: return .dark
        default: return nil // System
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView()
                    .environmentObject(store)
                    .preferredColorScheme(preferredScheme)

                if showAppSplash {
                    SplashView()
                        .transition(.opacity.combined(with: .scale))
                        .zIndex(1)
                }
            }
            .onAppear {
                // Dismiss app-level splash quickly
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showAppSplash = false
                    }
                }
            }
        }
    }
}
