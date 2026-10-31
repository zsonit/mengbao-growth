import SwiftUI

// MARK: - 应用入口

@main
struct MengBaoApp: App {
    @StateObject private var store = Store.shared

    init() {
        // 高德 SDK 必须在任何地图/搜索类实例化之前完成 Key 与隐私合规配置
        MapConfig.bootstrap()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(preferredScheme)
                .tint(Palette.purple)
        }
    }

    private var preferredScheme: ColorScheme? {
        guard let dark = store.settings.darkMode else { return nil }
        return dark ? .dark : .light
    }
}

// MARK: - 根视图

struct RootView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("成长", systemImage: "leaf.fill") }

            if store.settings.showFeed {
                NavigationStack {
                    FeedView()
                }
                .tabItem { Label("喂养", systemImage: "drop.fill") }
            }

            if store.settings.showShot {
                NavigationStack {
                    VaccineView()
                }
                .tabItem { Label("接种", systemImage: "cross.case.fill") }
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
    }
}
