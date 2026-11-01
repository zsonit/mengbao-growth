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
        // 语音识别要用网络状态决定走在线还是离线
        _ = Reachability.shared
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

// MARK: - 根视图（悬浮液态玻璃 Tab 栏）

struct RootView: View {
    @EnvironmentObject private var store: Store
    @State private var tab = "growth"

    /// 依据设置动态生成的页签
    private var tabs: [LiquidTabBar.Item] {
        var t = [LiquidTabBar.Item(id: "growth", label: "成长", icon: "leaf.fill")]
        if store.settings.showFeed {
            t.append(LiquidTabBar.Item(id: "feed", label: "喂养", icon: "drop.fill"))
        }
        if store.settings.showShot {
            t.append(LiquidTabBar.Item(id: "vaccine", label: "接种", icon: "cross.case.fill"))
        }
        t.append(LiquidTabBar.Item(id: "profile", label: "我的", icon: "person.crop.circle"))
        return t
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                HomeView()
                    .toolbar(.hidden, for: .tabBar)
            }
            .tag("growth")

            if store.settings.showFeed {
                NavigationStack {
                    FeedView()
                        .toolbar(.hidden, for: .tabBar)
                }
                .tag("feed")
            }

            if store.settings.showShot {
                NavigationStack {
                    VaccineView()
                        .toolbar(.hidden, for: .tabBar)
                }
                .tag("vaccine")
            }

            NavigationStack {
                ProfileView()
                    .toolbar(.hidden, for: .tabBar)
            }
            .tag("profile")
        }
        // 悬浮玻璃胶囊：内容滚动时会从玻璃后面穿过
        .safeAreaInset(edge: .bottom, spacing: 0) {
            LiquidTabBar(items: tabs, selection: $tab)
        }
    }
}
