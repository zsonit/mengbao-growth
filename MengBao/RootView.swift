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
        ZStack {
            // 不再用 TabView：它的切页是「硬切」，正是动画生硬的主因。
            // 改成 ZStack 常驻各页 + 淡入缩放交叉过渡，切页像玻璃层叠滑过去一样连续。
            ZStack {
                page("growth") { HomeView() }
                if store.settings.showFeed { page("feed") { FeedView() } }
                if store.settings.showShot { page("vaccine") { VaccineView() } }
                page("profile") { ProfileView() }
            }
            // 悬浮玻璃胶囊：内容滚动时会从玻璃后面穿过
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if store.tabBarHidden || store.voiceActive || store.voiceHolding || store.voiceProcessing {
                    // 聊天页 / 按住说话时收起玻璃栏：语音遮罩才能盖满全屏
                    EmptyView()
                } else {
                    LiquidTabBar(items: tabs, selection: $tab)
                }
            }

            // 按住说话的玻璃遮罩：挂在根视图这一层（不是首页那个被 padding 顶起的按钮内部），
            // 四边 ignoresSafeArea，底部不会再露出首页内容
            if store.voiceHolding || store.voiceProcessing {
                VoiceHoldOverlay(processing: store.voiceProcessing, said: store.voiceLiveText) {
                    // 逃生口：万一卡在录音态，点一下遮罩等同松手
                    store.voiceStopTick += 1
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(Anim.pop, value: store.voiceHolding)
        .animation(Anim.pop, value: store.voiceProcessing)
    }

    /// 单页容器：非当前页淡出并轻微缩小，切页时带阻尼弹簧
    @ViewBuilder
    private func page<Content: View>(_ id: String, @ViewBuilder content: () -> Content) -> some View {
        let on = tab == id
        NavigationStack { content() }
            .opacity(on ? 1 : 0)
            .scaleEffect(on ? 1 : 0.982)
            .offset(y: on ? 0 : 8)
            .allowsHitTesting(on)
            .accessibilityHidden(!on)
            .zIndex(on ? 1 : 0)
            .animation(Anim.page, value: tab)
    }
}
