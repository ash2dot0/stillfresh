import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: AppStore
    @State private var snackbarWorkItem: DispatchWorkItem?

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "sparkles") }

            ScanView()
                .tabItem { Label("Scan", systemImage: "camera.viewfinder") }

            AllItemsView()
                .tabItem { Label("All", systemImage: "list.bullet") }
        }
        .task { store.loadMockDataIfEmpty() }
        .modifier(GlassTabBar())
        .safeAreaInset(edge: .bottom) {
            if let snack = store.snackbar {
                SnackbarView(state: snack, onClose: dismissSnackbar)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        snackbarWorkItem?.cancel()
                        let work = DispatchWorkItem {
                            withAnimation {
                                if store.snackbar?.id == snack.id {
                                    store.snackbar = nil
                                }
                            }
                        }
                        snackbarWorkItem = work
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.snackbar?.id)
    }

    private func dismissSnackbar() {
        snackbarWorkItem?.cancel()
        withAnimation {
            store.snackbar = nil
        }
    }
}

struct GlassTabBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}
