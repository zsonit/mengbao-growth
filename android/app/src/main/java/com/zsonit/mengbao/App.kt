package com.zsonit.mengbao

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import kotlinx.coroutines.delay
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.data.SyncManager
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.Routes
import com.zsonit.mengbao.ui.screens.ClinicDetailScreen
import com.zsonit.mengbao.ui.screens.ClinicListScreen
import com.zsonit.mengbao.ui.screens.FeedScreen
import com.zsonit.mengbao.ui.screens.FoodScreen
import com.zsonit.mengbao.ui.screens.DietGuideScreen
import com.zsonit.mengbao.ui.screens.GrowthDetailScreen
import com.zsonit.mengbao.ui.screens.HistoryScreen
import com.zsonit.mengbao.ui.screens.HomeScreen
import com.zsonit.mengbao.ui.screens.KidEditorScreen
import com.zsonit.mengbao.ui.screens.KidsScreen
import com.zsonit.mengbao.ui.screens.YamiaoWebScreen
import com.zsonit.mengbao.ui.screens.NearbyMapScreen
import com.zsonit.mengbao.ui.screens.ProfileScreen
import com.zsonit.mengbao.ui.screens.QuickEntryManagerScreen
import com.zsonit.mengbao.ui.screens.RecordEditorScreen
import com.zsonit.mengbao.ui.screens.SizeEditorScreen
import com.zsonit.mengbao.ui.screens.StageScreen
import com.zsonit.mengbao.ui.screens.ToothChartScreen
import com.zsonit.mengbao.ui.screens.TodoEditorScreen
import com.zsonit.mengbao.ui.screens.TrendsScreen
import com.zsonit.mengbao.ui.screens.AIAssistantScreen
import com.zsonit.mengbao.ui.screens.DayHistoryScreen
import com.zsonit.mengbao.ui.screens.VaccineScreen

private data class Tab(val route: String, val label: String, val emoji: String)

@Composable
fun MengBaoApp() {
    val nav = rememberNavController()
    val settings = Store.settings

    val tabs = buildList {
        add(Tab(Routes.HOME, "成长", "🌱"))
        if (settings.showFeed) add(Tab(Routes.FEED, "喂养", "🍼"))
        if (settings.showShot) add(Tab(Routes.VACCINE, "接种", "💉"))
        add(Tab(Routes.PROFILE, "我的", "👤"))
    }

    val backStack by nav.currentBackStackEntryAsState()
    val currentRoute = backStack?.destination?.route
    val showBottomBar = tabs.any { it.route == currentRoute }

    // 配对手机已清空全部数据：让用户决定「同步清除 / 忽略」
    if (SyncManager.clearPrompt) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { SyncManager.clearPrompt = false },
            title = { Text("配对手机已清空数据") },
            text = { Text("对方手机已清空全部数据。要把本机数据一起清空吗？点「忽略」则保留本机数据。") },
            confirmButton = {
                androidx.compose.material3.TextButton(onClick = {
                    SyncManager.clearPrompt = false
                    Store.reset()
                }) { Text("同步清除", color = Palette.bad) }
            },
            dismissButton = {
                androidx.compose.material3.TextButton(onClick = { SyncManager.clearPrompt = false }) {
                    Text("忽略")
                }
            },
        )
    }

    Scaffold(
        containerColor = Palette.background,
        bottomBar = {
            if (showBottomBar) {
                LiquidNavBar(
                    tabs = tabs,
                    current = currentRoute,
                    onSelect = { nav.switchTab(it) },
                )
            }
        },
    ) { padding ->
        NavHost(
            navController = nav,
            startDestination = Routes.HOME,
            modifier = Modifier.padding(padding),
            // 页面切换不再硬切：轻微缩小 + 淡入淡出，接近玻璃层叠滑入的手感
            enterTransition = {
                fadeIn(tween(260)) + scaleIn(initialScale = 0.985f, animationSpec = tween(300))
            },
            exitTransition = { fadeOut(tween(180)) + scaleOut(targetScale = 0.99f, animationSpec = tween(220)) },
            popEnterTransition = {
                fadeIn(tween(240)) + scaleIn(initialScale = 0.99f, animationSpec = tween(280))
            },
            popExitTransition = { fadeOut(tween(180)) + scaleOut(targetScale = 0.985f, animationSpec = tween(220)) },
        ) {
            composable(Routes.HOME) {
                HomeScreen(
                    onNavigate = { route -> nav.navigate(route) },
                    onNewRecord = { nav.navigate(Routes.recordEditor()) },
                    onEditRecord = { id -> nav.navigate(Routes.recordEditor(id)) },
                )
            }
            composable(Routes.FEED) { FeedScreen(onBack = { nav.switchTab(Routes.HOME) }, onOpenTrends = { nav.navigate(Routes.TRENDS) }) }
            composable(Routes.VACCINE) {
                VaccineScreen(
                    onBack = { nav.switchTab(Routes.HOME) },
                    onOpenClinics = { nav.navigate(Routes.CLINICS) },
                    onOpenYamiao = { nav.navigate(Routes.YAMIAO) },
                    onOpenNearby = { nav.navigate(Routes.NEARBY) },
                )
            }
            composable(Routes.PROFILE) {
                ProfileScreen(
                    onOpenKids = { nav.navigate(Routes.KIDS) },
                    onOpenAI = { nav.navigate(Routes.AI) },
                )
            }

            composable(Routes.GROWTH) { GrowthDetailScreen(onBack = { nav.popBackStack() }) }
            composable(Routes.HISTORY) { HistoryScreen(onBack = { nav.popBackStack() }) }

            composable(
                route = "${Routes.RECORD_EDITOR}/{id}",
                arguments = listOf(navArgument("id") { type = NavType.StringType }),
            ) { entry ->
                val id = entry.arguments?.getString("id")?.takeIf { it != "new" }
                RecordEditorScreen(recordId = id, onBack = { nav.popBackStack() })
            }

            composable(Routes.KIDS) {
                KidsScreen(onBack = { nav.popBackStack() }, onEdit = { id -> nav.navigate(Routes.kidEditor(id)) })
            }
            composable(
                route = "${Routes.KID_EDITOR}/{id}",
                arguments = listOf(navArgument("id") { type = NavType.StringType }),
            ) { entry ->
                val id = entry.arguments?.getString("id")?.takeIf { it != "new" }
                KidEditorScreen(childId = id, onBack = { nav.popBackStack() })
            }

            composable(Routes.SIZE) { SizeEditorScreen(onBack = { nav.popBackStack() }) }
            composable(Routes.TEETH) { ToothChartScreen(onBack = { nav.popBackStack() }) }
            composable(Routes.TODO) { TodoEditorScreen(onBack = { nav.popBackStack() }) }
            composable(Routes.STAGE) { StageScreen(onBack = { nav.popBackStack() }) }
            composable(Routes.FOOD) { FoodScreen(onBack = { nav.popBackStack() }) }
            composable(Routes.DIET) { DietGuideScreen(child = Store.current, onBack = { nav.popBackStack() }) }
            composable(Routes.QUICK_ENTRIES) { QuickEntryManagerScreen(onBack = { nav.popBackStack() }) }

            composable(Routes.CLINICS) {
                ClinicListScreen(
                    onBack = { nav.popBackStack() },
                    onOpenYamiao = { nav.navigate(Routes.YAMIAO) },
                    onOpenDetail = { id -> nav.navigate(Routes.clinicDetail(id)) },
                )
            }
            composable(
                route = "${Routes.CLINIC_DETAIL}/{id}",
                arguments = listOf(navArgument("id") { type = NavType.StringType }),
            ) { entry ->
                val id = android.net.Uri.decode(entry.arguments?.getString("id") ?: "")
                ClinicDetailScreen(clinicId = id, onBack = { nav.popBackStack() })
            }

            composable(Routes.YAMIAO) { YamiaoWebScreen(onBack = { nav.popBackStack() }, onOpenNearby = { nav.navigate(Routes.NEARBY) }) }
            composable(Routes.NEARBY) { NearbyMapScreen(onBack = { nav.popBackStack() }) }
            composable(Routes.AI) {
                AIAssistantScreen(
                    onBack = { nav.popBackStack() },
                    onOpenPage = { page ->
                        when (page) {
                            "home" -> nav.switchTab(Routes.HOME)
                            "feed" -> nav.switchTab(Routes.FEED)
                            "vaccine" -> nav.switchTab(Routes.VACCINE)
                            "profile" -> nav.switchTab(Routes.PROFILE)
                            "trends" -> nav.navigate(Routes.TRENDS)
                            "history" -> nav.navigate(Routes.HISTORY)
                            "todo" -> nav.navigate(Routes.TODO)
                            "size" -> nav.navigate(Routes.SIZE)
                            "growth" -> nav.navigate(Routes.GROWTH)
                            "teeth" -> nav.navigate(Routes.TEETH)
                        }
                    },
                )
            }
            composable(Routes.TRENDS) {
                TrendsScreen(
                    onBack = { nav.popBackStack() },
                    onOpenDay = { date, metric -> nav.navigate(Routes.dayHistory(date, metric)) },
                )
            }
            composable(
                route = "${Routes.DAY_HISTORY}/{date}/{metric}",
                arguments = listOf(
                    navArgument("date") { type = NavType.StringType },
                    navArgument("metric") { type = NavType.StringType },
                ),
            ) { entry ->
                DayHistoryScreen(
                    initialDate = android.net.Uri.decode(entry.arguments?.getString("date") ?: ""),
                    initialMetric = android.net.Uri.decode(entry.arguments?.getString("metric") ?: "all"),
                    onBack = { nav.popBackStack() },
                )
            }
        }
    }
}

private fun NavHostController.switchTab(route: String) {
    navigate(route) {
        popUpTo(Routes.HOME) { saveState = true }
        launchSingleTop = true
        restoreState = true
    }
}

// MARK: - 液态玻璃悬浮导航栏（对应 iOS 的 LiquidTabBar）

@Composable
private fun LiquidNavBar(
    tabs: List<Tab>,
    current: String?,
    onSelect: (String) -> Unit,
) {
    val isDark = Palette.isDark
    val haptic = LocalHapticFeedback.current
    val pill = RoundedCornerShape(50.dp)

    val glassFill = if (isDark) Color(0xFF1E1B29).copy(alpha = 0.80f) else Color.White.copy(alpha = 0.82f)
    val edgeTop = Color.White.copy(alpha = if (isDark) 0.26f else 0.95f)
    val edgeBottom = Color.White.copy(alpha = if (isDark) 0.06f else 0.22f)
    // 选中指示必须是「透明玻璃水滴」：只给很淡的染色，绝不填实
    val selFill = if (isDark) Palette.purpleSoft.copy(alpha = 0.28f) else Color.White.copy(alpha = 0.32f)

    val count = tabs.size.coerceAtLeast(1)
    val index = tabs.indexOfFirst { it.route == current }.coerceAtLeast(0)

    Box(
        Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = 30.dp, vertical = 6.dp),
    ) {
        BoxWithConstraints(
            Modifier
                .fillMaxWidth()
                .shadow(
                    elevation = 16.dp,
                    shape = pill,
                    ambientColor = Color.Black.copy(alpha = 0.14f),
                    spotColor = Color.Black.copy(alpha = 0.20f),
                )
                .clip(pill)
                .background(glassFill)
                // 顶光：上亮下透，玻璃的厚度感
                .background(
                    Brush.verticalGradient(
                        listOf(
                            Color.White.copy(alpha = if (isDark) 0.10f else 0.42f),
                            Color.Transparent,
                            Color.Black.copy(alpha = if (isDark) 0.16f else 0.03f),
                        )
                    )
                )
                .border(BorderStroke(1.dp, Brush.verticalGradient(listOf(edgeTop, edgeBottom))), pill)
                .padding(horizontal = 6.dp, vertical = 5.dp)
                .height(52.dp),
        ) {
            val tabW = maxWidth / count
            // 选中水滴滑动（弹簧，不硬跳）
            val slide by animateDpAsState(
                targetValue = tabW * index,
                animationSpec = spring(dampingRatio = 0.66f, stiffness = Spring.StiffnessMediumLow),
                label = "tab-pill",
            )
            // 滑动途中像水滴一样被拉长，落定后弹回
            var stretched by remember { mutableStateOf(false) }
            LaunchedEffect(index) {
                stretched = true
                delay(140)
                stretched = false
            }
            val stretch by animateFloatAsState(
                targetValue = if (stretched) 1.22f else 1f,
                animationSpec = spring(dampingRatio = 0.62f, stiffness = Spring.StiffnessMedium),
                label = "droplet-stretch",
            )

            Box(
                Modifier
                    .offset(x = slide)
                    .width(tabW)
                    .fillMaxHeight()
                    .graphicsLayer {
                        scaleX = stretch
                        scaleY = 1f / stretch
                    }
                    .clip(pill)
                    .background(selFill)
                    .border(
                        1.dp,
                        Brush.verticalGradient(
                            listOf(
                                Color.White.copy(alpha = if (isDark) 0.24f else 0.70f),
                                Color.White.copy(alpha = if (isDark) 0.04f else 0.15f),
                            )
                        ),
                        pill,
                    ),
            )

            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                tabs.forEach { tab ->
                    val selected = tab.route == current
                    val interaction = remember { MutableInteractionSource() }
                    val pressed by interaction.collectIsPressedAsState()
                    val scale by animateFloatAsState(
                        targetValue = if (pressed) 0.93f else 1f,
                        animationSpec = spring(dampingRatio = 0.7f, stiffness = Spring.StiffnessMediumLow),
                        label = "tab-press",
                    )
                    val lift by animateDpAsState(
                        targetValue = if (selected) (-1).dp else 0.dp,
                        animationSpec = spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessLow),
                        label = "tab-lift",
                    )
                    Column(
                        Modifier
                            .weight(1f)
                            .height(52.dp)
                            .graphicsLayer {
                                scaleX = scale
                                scaleY = scale
                            }
                            .clip(pill)
                            .clickable(
                                interactionSource = interaction,
                                indication = null,
                            ) {
                                if (!selected) {
                                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                    onSelect(tab.route)
                                }
                            },
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                    ) {
                        Text(
                            tab.emoji,
                            fontSize = 17.sp,
                            modifier = Modifier.offset(y = lift),
                        )
                        Text(
                            tab.label,
                            fontSize = 10.5.sp,
                            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                            color = if (selected) Palette.purple else Palette.subtle.copy(alpha = 0.85f),
                        )
                    }
                }
            }
        }
    }
}
