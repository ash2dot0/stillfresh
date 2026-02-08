import SwiftUI

@main
struct StillFreshApp: App {
    @StateObject private var store = AppStore()
    // 0 = System, 1 = Light, 2 = Dark
    @AppStorage("sf_appearance") private var appearanceRaw: Int = 0

    private var preferredScheme: ColorScheme? {
        switch appearanceRaw {
        case 1: return .light
        case 2: return .dark
        default: return nil // System
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .preferredColorScheme(preferredScheme)
        }
    }
}
