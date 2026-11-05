package com.zsonit.mengbao.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zsonit.mengbao.data.AISuggest
import com.zsonit.mengbao.data.AISuggestion
import com.zsonit.mengbao.data.GrowthMath
import com.zsonit.mengbao.data.Standards
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.data.TodoParser
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.FeedLog
import com.zsonit.mengbao.model.GrowthRecord
import com.zsonit.mengbao.model.QuickEntry
import com.zsonit.mengbao.ui.Avatar
import com.zsonit.mengbao.ui.CapsuleShape
import com.zsonit.mengbao.ui.DividerLine
import com.zsonit.mengbao.ui.EmptyHint
import com.zsonit.mengbao.ui.HintBlock
import com.zsonit.mengbao.ui.KVRow
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.PrimaryButton
import com.zsonit.mengbao.ui.ProgressBar
import com.zsonit.mengbao.ui.Routes
import com.zsonit.mengbao.ui.SectionHeader
import com.zsonit.mengbao.ui.Avatar
import com.zsonit.mengbao.ui.TagTone
import com.zsonit.mengbao.ui.TagView
import com.zsonit.mengbao.ui.cardStyle
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.temporal.ChronoUnit
import java.util.Locale

// MARK: - 首页

@Composable
fun HomeScreen(
    onNavigate: (String) -> Unit,
    onNewRecord: () -> Unit,
    onEditRecord: (String) -> Unit,
) {
    val child = Store.current
    val settings = Store.settings
    var menuOpen by remember { mutableStateOf(false) }
    var sheetEntry by remember { mutableStateOf<QuickEntry?>(null) }
    var showVoice by remember { mutableStateOf(false) }

    // 按 kind 找入口（隐藏的也能直接打开，不影响配置）
    fun openEntryByKind(kind: String) {
        val entry = Store.quickEntries.firstOrNull { it.kind == kind }
            ?: QuickEntry.builtins.firstOrNull { it.kind == kind }
            ?: QuickEntry(id = kind, kind = kind, title = kind, icon = "📝")
        sheetEntry = entry
    }

    Box(Modifier.fillMaxSize().background(Palette.background)) {
        Column(Modifier.fillMaxSize()) {
            HomeHeader(
                child = child,
                menuOpen = menuOpen,
                onMenuOpen = { menuOpen = true },
                onMenuClose = { menuOpen = false },
                onNavigate = onNavigate,
            )

            if (child == null) {
                Onboarding(onNavigate = onNavigate, onAddChild = { onNavigate(Routes.kidEditor()) })
            } else {
                LazyColumn(
                    Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 120.dp),
                ) {
                    item {
                        AiCard(
                            suggestion = AISuggest.card(child, settings),
                            onAction = { action ->
                                when (action) {
                                    is AISuggestion.Action.Entry -> openEntryByKind(action.id)
                                    AISuggestion.Action.Vaccine -> onNavigate(Routes.VACCINE)
                                    AISuggestion.Action.Growth -> onNavigate(Routes.GROWTH)
                                    AISuggestion.Action.None -> Unit
                                }
                            },
                        )
                    }
                    if (settings.showFeed) {
                        item { TodaySection(child) { kind -> openEntryByKind(kind) } }
                    }
                    if (settings.showFeed) {
                        item {
                            QuickEntriesRow(
                                entries = Store.homeQuickEntries,
                                onPick = { entry -> sheetEntry = entry },
                                onConfigure = { onNavigate(Routes.QUICK_ENTRIES) },
                            )
                        }
                    }
                    item {
                        QuickGrid(
                            showFeed = settings.showFeed,
                            showSize = settings.showSize,
                            showTrends = settings.showTrends,
                            onNavigate = onNavigate,
                            onNewRecord = onNewRecord,
                        )
                    }
                    item {
                        RecentActivitySection(
                            child = child,
                            showFeed = settings.showFeed,
                            onOpenHistory = { onNavigate(Routes.HISTORY) },
                        )
                    }
                    item { StageCard(child, onOpenTodo = { onNavigate(Routes.TODO) }) }
                    if (child.todos.isNotEmpty()) {
                        item { TodoCard(child) { onNavigate(Routes.TODO) } }
                    }
                    item { ShotCard(child, onOpenVaccine = { onNavigate(Routes.VACCINE) }) }
                    item {
                        RecentCard(
                            child = child,
                            onEditRecord = onEditRecord,
                            onOpenHistory = { onNavigate(Routes.HISTORY) },
                        )
                    }
                    item {
                        HintBlock(Standards.disclaimer, Modifier.padding(horizontal = 16.dp, vertical = 14.dp))
                    }
                }
            }
        }

        if (child != null) {
            HoldToTalkFab(onOpenPage = { page ->
                when (page) {
                    "todo" -> onNavigate(Routes.TODO)
                    "size" -> onNavigate(Routes.SIZE)
                    "teeth" -> onNavigate(Routes.TEETH)
                    "growth" -> onNavigate(Routes.GROWTH)
                    "trends" -> onNavigate(Routes.TRENDS)
                    "history" -> onNavigate(Routes.HISTORY)
                }
            })
        }
    }

    val current = child
    if (showVoice && current != null) {
        VoiceEntryDialog(child = current, onDismiss = { showVoice = false })
    }
    val editing = sheetEntry
    if (editing != null && current != null) {
        EntrySheet(entry = editing, child = current, onDismiss = { sheetEntry = null })
    }
}

// MARK: 宝宝头部

@Composable
private fun HomeHeader(
    child: Child?,
    menuOpen: Boolean,
    onMenuOpen: () -> Unit,
    onMenuClose: () -> Unit,
    onNavigate: (String) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(start = 18.dp, end = 12.dp, top = 12.dp, bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (child != null) {
            Avatar(child = child, size = 84.dp, fontSize = 42.sp, shape = RoundedCornerShape(28.dp))
        } else {
            Box(
                Modifier.size(84.dp).clip(RoundedCornerShape(28.dp)).background(Palette.pinkBg),
                contentAlignment = Alignment.Center,
            ) { Text("👶", fontSize = 42.sp) }
        }

        Spacer(Modifier.width(12.dp))

        Column(Modifier.weight(1f)) {
            Text(
                child?.name ?: "萌宝成长",
                fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Palette.ink,
            )
            if (child != null) {
                val days = ChronoUnit.DAYS.between(child.birthDate, LocalDate.now())
                    .toInt().coerceAtLeast(0)
                Text(
                    "第 $days 天 · ${GrowthMath.ageText(child.birthDate)}",
                    fontSize = 12.sp, color = Palette.subtle,
                )
            } else {
                Text("先添加宝宝档案，开始记录", fontSize = 12.sp, color = Palette.subtle)
            }
        }

        Box {
            Row(
                Modifier.clip(CapsuleShape).background(Palette.card)
                    .border(1.dp, Palette.hairline, CapsuleShape)
                    .clickable { onMenuOpen() }
                    .padding(horizontal = 11.dp, vertical = 7.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("切换", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple)
                Spacer(Modifier.width(3.dp))
                Text("▾", fontSize = 10.sp, color = Palette.purple)
            }
            DropdownMenu(expanded = menuOpen, onDismissRequest = onMenuClose) {
                Store.state.children.forEach { kid ->
                    DropdownMenuItem(
                        text = {
                            // 切换列表里显示照片小头像（没设置照片就用可爱的 emoji）
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Avatar(child = kid, size = 22.dp, fontSize = 12.sp)
                                Spacer(Modifier.width(8.dp))
                                Text(
                                    kid.name +
                                        if (kid.id == Store.state.currentId) "  ✓" else "",
                                    fontSize = 14.sp,
                                )
                            }
                        },
                        onClick = {
                            Store.selectChild(kid.id)
                            onMenuClose()
                        },
                    )
                }
                if (Store.state.children.isNotEmpty()) DividerLine()
                DropdownMenuItem(
                    text = { Text("编辑当前档案", fontSize = 14.sp) },
                    onClick = {
                        onMenuClose()
                        onNavigate(Routes.kidEditor(Store.state.currentId))
                    },
                )
                DropdownMenuItem(
                    text = { Text("管理宝宝", fontSize = 14.sp) },
                    onClick = {
                        onMenuClose()
                        onNavigate(Routes.KIDS)
                    },
                )
                DropdownMenuItem(
                    text = { Text("快捷入口管理", fontSize = 14.sp) },
                    onClick = {
                        onMenuClose()
                        onNavigate(Routes.QUICK_ENTRIES)
                    },
                )
            }
        }
    }
}

// MARK: AI 分析卡

@Composable
private fun AiCard(suggestion: AISuggestion, onAction: (AISuggestion.Action) -> Unit) {
    Column(
        Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            .fillMaxWidth()
            .shadow(6.dp, RoundedCornerShape(20.dp))
            .clip(RoundedCornerShape(20.dp))
            .background(Palette.card)
            .padding(16.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Text(
                    suggestion.title,
                    fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Palette.ink,
                    lineHeight = 21.sp,
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    suggestion.body,
                    fontSize = 13.sp, color = Palette.ink2, lineHeight = 19.sp,
                )
            }
            Spacer(Modifier.width(12.dp))
            Box(
                Modifier.size(52.dp).clip(CircleShape).background(Palette.pinkGradient),
                contentAlignment = Alignment.Center,
            ) { Text(suggestion.tone.emoji, fontSize = 22.sp) }
        }
        Spacer(Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                suggestion.actionTitle,
                fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.pinkDeep,
                modifier = Modifier.clip(CapsuleShape).background(Palette.pinkBg)
                    .clickable { onAction(suggestion.action) }
                    .padding(horizontal = 13.dp, vertical = 7.dp),
            )
            Spacer(Modifier.weight(1f))
        }
        Spacer(Modifier.height(10.dp))
        Text(
            "* AI 分析仅供参考，不能替代医疗建议",
            fontSize = 10.5.sp, color = Palette.subtle,
        )
    }
}

// MARK: 今日记录

@Composable
private fun TodaySection(child: Child, onPick: (String) -> Unit) {
    val today = child.feeds.filter { GrowthMath.isSameDay(it.date, LocalDate.now()) }
    val bottleMl = today.filter { it.kind == FeedLog.Kind.BOTTLE }.sumOf { it.ml ?: 0.0 }
    val sleepMinutes = today.filter { it.kind == FeedLog.Kind.SLEEP }.sumOf { it.minutes ?: 0 }
    val diaperCount = today.count { it.kind == FeedLog.Kind.DIAPER }

    Column(Modifier.fillMaxWidth()) {
        SectionHeader(title = "今日记录", trailing = GrowthMath.dateString(LocalDate.now()))
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(9.dp),
        ) {
            TodayStatCard(
                icon = "🍼", label = "瓶喂",
                value = "${bottleMl.toInt()}", unit = "ml",
                tint = Palette.blueBg,
                modifier = Modifier.weight(1f),
                onAdd = { onPick("bottle") },
            )
            TodayStatCard(
                icon = "😴", label = "睡眠",
                value = durationText(sleepMinutes), unit = "",
                tint = Palette.purpleSoft,
                modifier = Modifier.weight(1f),
                onAdd = { onPick("sleep") },
            )
            TodayStatCard(
                icon = "🧷", label = "尿布",
                value = "$diaperCount", unit = "次",
                tint = Palette.okBg,
                modifier = Modifier.weight(1f),
                onAdd = { onPick("diaper") },
            )
        }
    }
}

/** 分钟数 → 1h20m 这种紧凑写法 */
private fun durationText(minutes: Int): String {
    if (minutes < 60) return "$minutes"
    val h = minutes / 60
    val m = minutes % 60
    return if (m == 0) "${h}h" else "${h}h${m}m"
}

@Composable
private fun TodayStatCard(
    icon: String,
    label: String,
    value: String,
    unit: String,
    tint: Color,
    onAdd: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier
            .height(104.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(Palette.card)
            .border(1.dp, Palette.hairline, RoundedCornerShape(18.dp))
            .padding(12.dp),
    ) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(icon, fontSize = 13.sp)
                Spacer(Modifier.width(4.dp))
                Text(label, fontSize = 11.5.sp, color = Palette.subtle, maxLines = 1)
            }
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    value, fontSize = 19.sp, fontWeight = FontWeight.Bold, color = Palette.ink,
                    maxLines = 1,
                )
                if (unit.isNotEmpty()) {
                    Text(
                        unit, fontSize = 10.5.sp, color = Palette.subtle,
                        modifier = Modifier.padding(start = 2.dp, bottom = 2.dp),
                    )
                }
            }
        }
        Box(
            Modifier.align(Alignment.BottomEnd).size(26.dp).clip(CircleShape)
                .background(tint).clickable { onAdd() },
            contentAlignment = Alignment.Center,
        ) {
            Text("＋", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Palette.pinkDeep)
        }
    }
}

// MARK: 快捷入口横滑

@Composable
private fun QuickEntriesRow(
    entries: List<QuickEntry>,
    onPick: (QuickEntry) -> Unit,
    onConfigure: () -> Unit,
) {
    Column(Modifier.fillMaxWidth()) {
        SectionHeader(title = "快捷录入")
        LazyRow(
            contentPadding = PaddingValues(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(entries, key = { it.id }) { entry ->
                QuickEntryChip(icon = entry.icon, title = entry.title) { onPick(entry) }
            }
            item(key = "__config__") {
                QuickEntryChip(icon = "⚙️", title = "配置", onClick = onConfigure)
            }
        }
    }
}

@Composable
private fun QuickEntryChip(icon: String, title: String, onClick: () -> Unit) {
    Row(
        Modifier.clip(CapsuleShape).background(Palette.card)
            .border(1.dp, Palette.hairline, CapsuleShape)
            .clickable { onClick() }
            .padding(horizontal = 13.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(icon, fontSize = 15.sp)
        Spacer(Modifier.width(6.dp))
        Text(title, fontSize = 12.5.sp, fontWeight = FontWeight.Medium, color = Palette.ink)
    }
}

// MARK: 常用工具

@Composable
private fun QuickGrid(showFeed: Boolean, showSize: Boolean, showTrends: Boolean, onNavigate: (String) -> Unit, onNewRecord: () -> Unit) {
    val entries = buildList {
        add(Triple("🎙️", "AI 助手", { onNavigate(Routes.AI) }))
        add(Triple("📝", "记录数据", { onNewRecord() }))
        add(Triple("📈", "生长曲线", { onNavigate(Routes.GROWTH) }))
        if (showTrends && showFeed) add(Triple("📊", "成长趋势", { onNavigate(Routes.TRENDS) }))
        add(Triple("💉", "接种计划", { onNavigate(Routes.VACCINE) }))
        if (showFeed) add(Triple("🍼", "喂养记录", { onNavigate(Routes.FEED) }))
        add(Triple("🕘", "历史记录", { onNavigate(Routes.HISTORY) }))
        if (showSize) add(Triple("👟", "鞋服尺码", { onNavigate(Routes.SIZE) }))
        add(Triple("🦷", "换牙档案", { onNavigate(Routes.TEETH) }))
        if (showFeed) add(Triple("🥣", "辅食推荐", { onNavigate(Routes.FOOD) }))
        add(Triple("🍽️", "饮食指南", { onNavigate(Routes.DIET) }))
        add(Triple("📋", "待办", { onNavigate(Routes.TODO) }))
        add(Triple("⭐", "阶段重点", { onNavigate(Routes.STAGE) }))
    }
    val backgrounds = listOf(
        Palette.purpleTint, Palette.pinkBg, Palette.blueBg, Palette.okBg,
        Palette.warnBg, Palette.purpleSoft, Palette.purpleTint, Palette.pinkBg,
    )

    Column(Modifier.fillMaxWidth()) {
        SectionHeader("常用入口")
        Column(Modifier.padding(horizontal = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            entries.chunked(4).forEach { rowItems ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    rowItems.forEach { item ->
                        val index = entries.indexOf(item)
                        Column(
                            Modifier.weight(1f).clickable { item.third() },
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Box(
                                Modifier.size(46.dp).clip(RoundedCornerShape(15.dp))
                                    .background(backgrounds[index % backgrounds.size])
                                    .border(1.dp, Palette.hairline, RoundedCornerShape(15.dp)),
                                contentAlignment = Alignment.Center,
                            ) { Text(item.first, fontSize = 20.sp) }
                            Spacer(Modifier.height(6.dp))
                            Text(item.second, fontSize = 12.sp, color = Palette.ink2, maxLines = 1)
                        }
                    }
                    repeat(4 - rowItems.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
        Spacer(Modifier.height(6.dp))
    }
}

// MARK: 近 24 小时活动

@Composable
private fun RecentActivitySection(child: Child, showFeed: Boolean, onOpenHistory: () -> Unit) {
    val cutoff = LocalDateTime.now().minusHours(24)
    val recent = child.feeds.filter { log ->
        val at = LocalDateTime.of(log.date, log.time ?: LocalTime.MIN)
        val kindOk = showFeed ||
            log.kind == FeedLog.Kind.TEMP || log.kind == FeedLog.Kind.CUSTOM ||
            log.kind == FeedLog.Kind.NOTEBOOK || log.kind == FeedLog.Kind.MEDICINE
        at.isAfter(cutoff) && kindOk
    }.sortedWith(
        compareByDescending<FeedLog> { it.date }
            .thenByDescending { it.time ?: LocalTime.MIN },
    ).take(6)

    Column(Modifier.fillMaxWidth()) {
        SectionHeader(title = "近 24 小时", trailing = "历史 ›", onAction = onOpenHistory)
        Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle(padding = 14.dp)) {
            if (recent.isEmpty()) {
                EmptyHint("暂无记录")
            } else {
                recent.forEachIndexed { index, log ->
                    Row(
                        Modifier.fillMaxWidth().padding(vertical = 7.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(
                            Modifier.size(34.dp).clip(CircleShape).background(tintForKind(log.kind)),
                            contentAlignment = Alignment.Center,
                        ) { Text(log.kind.icon, fontSize = 15.sp) }
                        Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Text(
                                log.kind.title, fontSize = 13.5.sp,
                                fontWeight = FontWeight.SemiBold, color = Palette.ink,
                            )
                            Text(log.summary, fontSize = 12.sp, color = Palette.subtle)
                        }
                        Text(GrowthMath.timeText(log.time), fontSize = 11.5.sp, color = Palette.subtle)
                    }
                    if (index != recent.size - 1) DividerLine()
                }
            }
        }
    }
}

@Composable
private fun tintForKind(kind: FeedLog.Kind): Color = when (kind) {
    FeedLog.Kind.SLEEP -> Palette.purpleSoft
    FeedLog.Kind.BREAST -> Palette.pinkBg
    FeedLog.Kind.BOTTLE -> Palette.blueBg
    FeedLog.Kind.PUMPING -> Palette.blueBg
    FeedLog.Kind.STORAGE -> Palette.blueBg
    FeedLog.Kind.DIAPER -> Palette.okBg
    FeedLog.Kind.SOLID -> Palette.warnBg
    FeedLog.Kind.SUPPLEMENT -> Palette.okBg
    FeedLog.Kind.MEDICINE -> Palette.warnBg
    FeedLog.Kind.TEMP -> Palette.badBg
    FeedLog.Kind.NOTEBOOK -> Palette.purpleTint
    FeedLog.Kind.CUSTOM -> Palette.purpleTint
}

// MARK: 语音悬浮球

@Composable
private fun VoiceFab(modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier
            .size(58.dp)
            .shadow(10.dp, CircleShape)
            .clip(CircleShape)
            .background(Palette.pinkGradient)
            .clickable { onClick() },
        contentAlignment = Alignment.Center,
    ) { Text("🎤", fontSize = 24.sp) }
}

// MARK: 阶段重点

@Composable
private fun StageCard(child: Child, onOpenTodo: () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(top = 4.dp)) {
        SectionHeader("阶段重点", trailing = GrowthMath.ageText(child.birthDate))
        Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle()) {
            Text(
                "这个阶段可以关注",
                fontSize = 11.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple,
                modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(Palette.purpleSoft)
                    .padding(horizontal = 9.dp, vertical = 3.dp),
            )
            Spacer(Modifier.height(8.dp))
            GrowthMath.milestones(child).forEach { item ->
                Row(Modifier.padding(vertical = 2.dp)) {
                    Text("·", color = Palette.subtle, fontSize = 13.sp)
                    Spacer(Modifier.width(7.dp))
                    Text(item, fontSize = 13.sp, color = Palette.ink2, lineHeight = 19.sp)
                }
            }
            Spacer(Modifier.height(4.dp))
            Text(
                "加入待办清单",
                fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple,
                modifier = Modifier.clip(RoundedCornerShape(10.dp)).background(Palette.purpleSoft)
                    .clickable { onOpenTodo() }
                    .padding(horizontal = 12.dp, vertical = 7.dp),
            )
        }
    }
}

// MARK: 待办

@Composable
private fun TodoCard(child: Child, onOpen: () -> Unit) {
    val sorted = child.todos.sortedBy { if (it.done) 1 else 0 }
    Column(Modifier.fillMaxWidth().padding(top = 4.dp)) {
        SectionHeader("待办", trailing = "新增", onAction = onOpen)
        Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle(padding = 14.dp)) {
            sorted.forEachIndexed { index, todo ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(
                        checked = todo.done,
                        onCheckedChange = { Store.toggleTodo(todo.id) },
                        colors = CheckboxDefaults.colors(
                            checkedColor = Palette.ok,
                            uncheckedColor = Palette.hairline,
                            checkmarkColor = Color.White,
                        ),
                        modifier = Modifier.size(26.dp),
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        todo.title,
                        fontSize = 13.5.sp,
                        color = if (todo.done) Palette.subtle else Palette.ink,
                        textDecoration = if (todo.done) TextDecoration.LineThrough else TextDecoration.None,
                        modifier = Modifier.weight(1f),
                    )
                    todo.due?.let { d ->
                        if (!todo.done) {
                            val overdue = d.isBefore(LocalDate.now())
                            Text(
                                if (overdue) "已过期" else TodoParser.dueText(d),
                                fontSize = 10.5.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = if (overdue) Palette.bad else Palette.purple,
                                modifier = Modifier
                                    .padding(start = 6.dp)
                                    .clip(RoundedCornerShape(20.dp))
                                    .background(if (overdue) Palette.badBg else Palette.purpleTint)
                                    .padding(horizontal = 7.dp, vertical = 2.dp),
                            )
                        }
                    }
                    // 本机提醒开关：🔔 会在到期时响，🔕 本机静音（不影响另一台手机，待办内容照样同步）
                    if (todo.due != null && !todo.done) {
                        val muted = todo.id in Store.settings.mutedTodoReminders
                        Text(
                            if (muted) "🔕" else "🔔",
                            fontSize = 13.sp,
                            modifier = Modifier.clickable { Store.toggleTodoMute(todo.id) }.padding(6.dp),
                        )
                    }
                    Text(
                        "✕", fontSize = 12.sp, color = Palette.subtle,
                        modifier = Modifier.clickable { Store.deleteTodo(todo.id) }.padding(8.dp),
                    )
                }
                if (index != sorted.size - 1) DividerLine()
            }
        }
    }
}

// MARK: 接种进度

@Composable
private fun ShotCard(child: Child, onOpenVaccine: () -> Unit) {
    val schedule = GrowthMath.schedule(child)
    val done = schedule.count { it.status == com.zsonit.mengbao.data.Dose.Status.DONE }
    val due = schedule.count { it.status == com.zsonit.mengbao.data.Dose.Status.DUE }
    val total = schedule.size
    val next = schedule.firstOrNull { it.status == com.zsonit.mengbao.data.Dose.Status.SOON }

    Column(Modifier.fillMaxWidth().padding(top = 4.dp)) {
        SectionHeader("接种进度")
        Column(
            Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle(padding = 14.dp)
                .clickable { onOpenVaccine() },
        ) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("已完成 $done / $total 剂", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
                Spacer(Modifier.weight(1f))
                Text("${(done.toDouble() / total * 100).toInt()}%", fontSize = 12.sp, color = Palette.subtle)
            }
            Spacer(Modifier.height(8.dp))
            ProgressBar(done.toDouble() / total)
            Spacer(Modifier.height(8.dp))
            Text(
                when {
                    due > 0 -> "⚠️ $due 剂已到期未种"
                    next != null -> "下一针：${next.ageLabel} · ${next.vaccine.name}"
                    else -> "全部按计划完成"
                },
                fontSize = 12.sp,
                color = if (due > 0) Palette.bad else Palette.subtle,
            )
        }
    }
}

// MARK: 最近记录

@Composable
private fun RecentCard(child: Child, onEditRecord: (String) -> Unit, onOpenHistory: () -> Unit) {
    val records = child.sortedRecords.reversed().take(2)
    Column(Modifier.fillMaxWidth()) {
        SectionHeader("最近记录", trailing = "全部 ›", onAction = onOpenHistory)
        if (records.isEmpty()) {
            EmptyHint("还没有记录，去「记录数据」量一次吧")
        } else {
            records.forEach { record ->
                RecordMiniCard(child, record, onClick = { onEditRecord(record.id) })
            }
        }
    }
}

@Composable
fun RecordMiniCard(child: Child, record: GrowthRecord, modifier: Modifier = Modifier, onClick: () -> Unit = {}) {
    val evaluation = GrowthMath.evaluate(child, record)
    val unit = Store.settings.weightUnit

    Column(
        modifier.padding(horizontal = 16.dp, vertical = 5.dp).fillMaxWidth()
            .cardStyle(padding = 14.dp).clickable { onClick() },
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(GrowthMath.dateString(record.date), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink2)
            Spacer(Modifier.width(8.dp))
            Text(GrowthMath.ageText(child.birthDate, record.date), fontSize = 12.sp, color = Palette.subtle)
            Spacer(Modifier.weight(1f))
            evaluation.heightPercentile?.let { p ->
                val tone = when (evaluation.heightLevel?.tone) {
                    com.zsonit.mengbao.data.LevelTone.BAD -> TagTone.BAD
                    com.zsonit.mengbao.data.LevelTone.WARN -> TagTone.WARN
                    else -> TagTone.OK
                }
                TagView(GrowthMath.percentileLabel(p), tone)
            }
        }
        Spacer(Modifier.height(10.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MiniValue(record.height?.let { String.format(Locale.US, "%.1f", it) } ?: "—", "身高cm", Modifier.weight(1f))
            MiniValue(
                record.weight?.let { String.format(Locale.US, "%.1f", if (unit == "斤") it * 2 else it) } ?: "—",
                "体重$unit", Modifier.weight(1f),
            )
            MiniValue(evaluation.bmi?.let { String.format(Locale.US, "%.1f", it) } ?: "—", "BMI", Modifier.weight(1f))
            MiniValue(record.footLength?.let { String.format(Locale.US, "%.0f", it) } ?: "—", "脚长cm", Modifier.weight(1f))
        }
        if (record.note.isNotEmpty()) {
            Spacer(Modifier.height(8.dp))
            Text(record.note, fontSize = 12.sp, color = Palette.subtle)
        }
    }
}

@Composable
private fun MiniValue(value: String, unit: String, modifier: Modifier = Modifier) {
    Column(
        modifier.clip(RoundedCornerShape(12.dp)).background(Palette.purpleTint).padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(value, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Palette.ink)
        Text(unit, fontSize = 10.5.sp, color = Palette.subtle)
    }
}

// MARK: 首次使用引导

@Composable
fun Onboarding(onNavigate: (String) -> Unit, onAddChild: () -> Unit) {
    var showDemo by remember { mutableStateOf(false) }
    LazyColumn(Modifier.fillMaxSize()) {
        item {
            Box(
                Modifier.padding(16.dp).fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(Palette.heroGradient),
            ) {
                Column(Modifier.padding(18.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            Modifier.size(50.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.24f))
                                .border(2.dp, Color.White.copy(alpha = 0.6f), CircleShape),
                            contentAlignment = Alignment.Center,
                        ) { Text("🍼", fontSize = 24.sp) }
                        Spacer(Modifier.width(12.dp))
                        Column {
                            Text("欢迎使用萌宝成长", fontSize = 19.sp, fontWeight = FontWeight.Bold, color = Color.White)
                            Text(
                                "记录身高体重 · 看懂生长曲线 · 管好疫苗本",
                                fontSize = 12.5.sp, color = Color.White.copy(alpha = 0.95f),
                            )
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                    Text(
                        "＋ 添加宝宝档案",
                        fontSize = 13.5.sp, fontWeight = FontWeight.SemiBold, color = Color.White,
                        modifier = Modifier.fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = 0.22f))
                            .border(1.dp, Color.White.copy(alpha = 0.45f), RoundedCornerShape(12.dp))
                            .clickable { onAddChild() }
                            .padding(vertical = 10.dp),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    )
                }
            }
        }
        item {
            SectionHeader("能做什么")
            Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle()) {
                KVRow("📈 生长曲线", "身高 / 体重 / BMI 百分位")
                DividerLine()
                KVRow("💉 接种计划", "广东免疫规划 ${GrowthMath.totalDoses} 剂")
                DividerLine()
                KVRow("🍼 喂养记录", "睡眠 · 奶量 · 尿布")
                DividerLine()
                KVRow("👟 鞋服尺码", "脚长换算 + 身高对应码")
                DividerLine()
                KVRow("🦷 换牙档案", "20 颗乳牙脱落记录 + 换牙时间表")
                DividerLine()
                KVRow("🔒 数据归属", "只存本机，可导出备份")
            }
        }
        item {
            SectionHeader("先看看效果")
            Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle()) {
                Text(
                    "载入一份示例数据（11 岁姐姐 + 8 个月弟弟），体验完整流程后可以随时删除。",
                    fontSize = 13.sp, color = Palette.subtle, lineHeight = 19.sp,
                )
                Spacer(Modifier.height(12.dp))
                PrimaryButton("载入示例数据", filled = false) { Store.loadDemo() }
            }
            Spacer(Modifier.height(28.dp))
        }
    }
}
