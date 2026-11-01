package com.zsonit.mengbao

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
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
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.Routes
import com.zsonit.mengbao.ui.screens.ClinicDetailScreen
import com.zsonit.mengbao.ui.screens.ClinicListScreen
import com.zsonit.mengbao.ui.screens.FeedScreen
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
    val glassFill = if (isDark) Color(0xFF1E1B29).copy(alpha = 0.78f) else Color.White.copy(alpha = 0.80f)
    val edgeTop = Color.White.copy(alpha = if (isDark) 0.22f else 0.90f)
    val edgeBottom = Color.White.copy(alpha = if (isDark) 0.06f else 0.25f)
    val selFill = if (isDark) Palette.purpleSoft else Color.White.copy(alpha = 0.95f)
    val pill = RoundedCornerShape(50.dp)

    Box(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 36.dp, vertical = 6.dp),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .shadow(
                    elevation = 16.dp,
                    shape = pill,
                    ambientColor = Color.Black.copy(alpha = 0.15f),
                    spotColor = Color.Black.copy(alpha = 0.20f),
                )
                .clip(pill)
                .background(glassFill)
                .border(BorderStroke(1.dp, Brush.verticalGradient(listOf(edgeTop, edgeBottom))), pill)
                .padding(horizontal = 8.dp, vertical = 5.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            tabs.forEach { tab ->
                val selected = tab.route == current
                Column(
                    Modifier
                        .weight(1f)
                        .clip(pill)
                        .background(if (selected) selFill else Color.Transparent)
                        .clickable { onSelect(tab.route) }
                        .padding(vertical = 7.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(tab.emoji, fontSize = 17.sp)
                    Text(
                        tab.label,
                        fontSize = 10.5.sp,
                        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                        color = if (selected) Palette.purple else Palette.subtle,
                    )
                }
            }
        }
    }
}
