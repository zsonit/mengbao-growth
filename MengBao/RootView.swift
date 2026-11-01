import SwiftUI

// MARK: - 应用入口

@main
struct MengBaoApp: App {
    @StateObject private var store = Store.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 高德 SDK 必须在任何地图/搜索类实例化之前完成 Key 与隐私合规配置
        MapConfig.bootstrap()
        AppLog.bootstrap()
        AppLog.isEnabled = store.settings.showLog == true
        AppLog.i("Main", "App 启动：\(store.state.children.count) 个宝宝档案")
        // 触发同步引擎初始化（已配对时启动后会自动拉一次云端）
        _ = SyncManager.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(preferredScheme)
                .tint(Palette.purple)
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .active:
                        // 回到前台：立即同步一次并开启自动检查（12 秒一轮）
                        SyncManager.shared.appDidBecomeActive()
                    case .background:
                        // 退到后台：停止自动检查，不耗电不耗流量
                        SyncManager.shared.appDidEnterBackground()
                    default:
                        break
                    }
                }
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
