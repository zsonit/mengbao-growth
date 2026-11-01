package com.zsonit.mengbao.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.zsonit.mengbao.data.GrowthMath
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.FeedLog
import com.zsonit.mengbao.ui.ChipLabel
import com.zsonit.mengbao.ui.EmptyHint
import com.zsonit.mengbao.ui.HintBlock
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.PrimaryButton
import com.zsonit.mengbao.ui.SectionHeader
import com.zsonit.mengbao.ui.TopBar
import com.zsonit.mengbao.ui.cardStyle
import java.time.LocalDate
import java.time.LocalTime

// MARK: - 喂养

@Composable
fun FeedScreen(onBack: () -> Unit, onOpenTrends: () -> Unit = {}) {
    val child = Store.current
    var showAdd by remember { mutableStateOf(false) }
    var addKind by remember { mutableStateOf(FeedLog.Kind.SLEEP) }

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(
            title = "喂养",
            onBack = onBack,
            actions = {
                IconButton(onClick = { addKind = FeedLog.Kind.SLEEP; showAdd = true }) {
                    Icon(Icons.Default.AddCircle, contentDescription = "添加记录", tint = Palette.purple)
                }
            },
        )
        if (child == null) {
            EmptyHint("先添加宝宝档案")
        } else {
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState()),
            ) {
                FeedContent(child, onOpenTrends = onOpenTrends)
            }
        }
    }

    if (showAdd && child != null) {
        FeedEditorDialog(child = child, initialKind = addKind, onDismiss = { showAdd = false })
    }
}

@Composable
private fun FeedContent(child: Child, onOpenTrends: () -> Unit = {}) {
    val today = child.feeds.filter { GrowthMath.isSameDay(it.date, LocalDate.now()) }
    val sleepMinutes = today.filter { it.kind == FeedLog.Kind.SLEEP }.sumOf { it.minutes ?: 0 }
    val breastCount = today.count { it.kind == FeedLog.Kind.BREAST }
    val leftCount = today.count { it.kind == FeedLog.Kind.BREAST && it.side == "左" }
    val rightCount = today.count { it.kind == FeedLog.Kind.BREAST && it.side == "右" }
    val bottleML = today.filter { it.kind == FeedLog.Kind.BOTTLE }.sumOf { it.ml ?: 0.0 }
    val diaperCount = today.count { it.kind == FeedLog.Kind.DIAPER }

    SectionHeader(title = "今日 · ${child.name}", trailing = GrowthMath.dateString(LocalDate.now()))

    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(11.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(11.dp)) {
            Box(Modifier.weight(1f)) {
                FeedCard(FeedLog.Kind.SLEEP, value = "$sleepMinutes", unit = "分钟",
                    hint = if (sleepMinutes > 0) "今日总计" else "点右上角 ＋ 记录")
            }
            Box(Modifier.weight(1f)) {
                FeedCard(FeedLog.Kind.BREAST, value = "$breastCount", unit = "次",
                    hint = "左 $leftCount · 右 $rightCount")
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(11.dp)) {
            Box(Modifier.weight(1f)) {
                FeedCard(FeedLog.Kind.BOTTLE, value = "${bottleML.toInt()}", unit = "ml",
                    hint = if (bottleML > 0) "今日总计" else "点右上角 ＋ 记录")
            }
            Box(Modifier.weight(1f)) {
                FeedCard(FeedLog.Kind.DIAPER, value = "$diaperCount", unit = "次",
                    hint = if (diaperCount > 0) "今日总计" else "点右上角 ＋ 记录")
            }
        }
    }

    SectionHeader(title = "成长趋势", trailing = "查看曲线 ›", onAction = onOpenTrends)
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp).cardStyle(padding = 13.dp).clickable { onOpenTrends() },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("📊", fontSize = 17.sp)
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text("睡眠 · 奶量 · 尿布 · 吸奶 · 辅食 · 体温 · 体重 · 身高 · 头围", fontSize = 12.5.sp, color = Palette.ink2)
            Text("9 项曲线 + 按日期查历史明细", fontSize = 11.sp, color = Palette.subtle, modifier = Modifier.padding(top = 1.dp))
        }
        Text("›", fontSize = 16.sp, color = Palette.purple)
    }

    SectionHeader(title = "最近 7 天")
    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .cardStyle(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row {
            Text("睡眠时长", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
            Spacer(Modifier.weight(1f))
            Text("分钟", fontSize = 12.sp, color = Palette.subtle)
        }
        BarChart(
            values = last7(child) { if (it.kind == FeedLog.Kind.SLEEP) (it.minutes ?: 0).toDouble() else null },
            maxValue = 720.0,
        )
    }

    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(top = 11.dp)
            .cardStyle(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row {
            Text("奶量", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
            Spacer(Modifier.weight(1f))
            Text("ml", fontSize = 12.sp, color = Palette.subtle)
        }
        BarChart(
            values = last7(child) { if (it.kind == FeedLog.Kind.BOTTLE) (it.ml ?: 0.0) else null },
            maxValue = 600.0,
        )
    }

    SectionHeader(title = "今日明细")
    if (today.isEmpty()) {
        EmptyHint("今天还没有喂养记录")
    } else {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .cardStyle(padding = 16.dp, radius = 18.dp),
        ) {
            today.sortedWith(
                compareByDescending<FeedLog> { it.date }
                    .thenByDescending { it.time ?: LocalTime.MIN },
            ).forEach { log ->
                Row(Modifier.fillMaxWidth().padding(vertical = 9.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(log.kind.icon, fontSize = 17.sp)
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text("${log.kind.title} · ${log.summary}", fontSize = 14.sp, color = Palette.ink)
                        if (log.note.isNotEmpty()) {
                            Text(log.note, fontSize = 12.sp, color = Palette.subtle)
                        }
                    }
                    Text(GrowthMath.momentText(log.date, log.time), fontSize = 11.5.sp, color = Palette.subtle)
                    Spacer(Modifier.width(8.dp))
                    Text(
                        "🗑", fontSize = 12.sp, color = Palette.bad,
                        modifier = Modifier.clickable { Store.deleteFeed(log.id) },
                    )
                }
            }
        }
    }

    if (GrowthMath.ageMonths(child.birthDate) > 36) {
        HintBlock(
            text = "喂养模块主要面向 0–3 岁。孩子已经 ${GrowthMath.ageText(child.birthDate)}，可以在「我的 → 功能开关」里隐藏这个模块。",
            modifier = Modifier.padding(horizontal = 16.dp).padding(top = 12.dp),
        )
    }
    Spacer(Modifier.height(28.dp))
}

@Composable
private fun FeedCard(kind: FeedLog.Kind, value: String, unit: String, hint: String) {
    var open by remember { mutableStateOf(false) }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .height(116.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(Palette.card)
            .border(1.dp, Palette.hairline, RoundedCornerShape(18.dp))
            .clickable { open = true }
            .padding(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(kind.icon, fontSize = 18.sp)
            Spacer(Modifier.width(7.dp))
            Text(kind.title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
            Spacer(Modifier.weight(1f))
            Box(
                Modifier
                    .size(24.dp)
                    .clip(CircleShape)
                    .background(Palette.purpleSoft),
                contentAlignment = Alignment.Center,
            ) {
                Text("＋", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Palette.purple)
            }
        }
        Row(
            Modifier.padding(top = 12.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            Text(value, fontSize = 25.sp, fontWeight = FontWeight.Bold, color = Palette.ink)
            Spacer(Modifier.width(2.dp))
            Text(unit, fontSize = 11.5.sp, color = Palette.subtle)
        }
        Text(hint, fontSize = 11.5.sp, color = Palette.subtle)
    }
    if (open) {
        Store.current?.let { FeedEditorDialog(child = it, initialKind = kind, onDismiss = { open = false }) }
    }
}

private fun last7(child: Child, value: (FeedLog) -> Double?): List<Double> {
    val today = LocalDate.now()
    return (0..6).map { offset ->
        val day = today.minusDays((6 - offset).toLong())
        child.feeds
            .filter { GrowthMath.isSameDay(it.date, day) }
            .mapNotNull(value)
            .sum()
    }
}

@Composable
private fun BarChart(values: List<Double>, maxValue: Double) {
    val today = LocalDate.now()
    val labels = (0..6).map { offset -> "${today.minusDays((6 - offset).toLong()).dayOfMonth}日" }
    val peak = maxOf(maxValue, values.maxOrNull() ?: 1.0)

    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(
            Modifier.fillMaxWidth().height(50.dp),
            horizontalArrangement = Arrangement.spacedBy(5.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            values.forEach { v ->
                val ratio = if (peak > 0) v / peak else 0.0
                Box(
                    Modifier
                        .weight(1f)
                        .height(maxOf(3.0, ratio * 46.0).dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(if (v > 0) Palette.purple.copy(alpha = 0.55f) else Palette.purpleTint),
                )
            }
        }
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            labels.forEach {
                Text(it, fontSize = 9.sp, color = Palette.subtle, modifier = Modifier.weight(1f),
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            }
        }
    }
}

// MARK: - 喂养录入

@Composable
private fun FeedEditorDialog(child: Child, initialKind: FeedLog.Kind, onDismiss: () -> Unit) {
    var kind by remember { mutableStateOf(initialKind) }
    var minutes by remember { mutableStateOf("") }
    var ml by remember { mutableStateOf("") }
    var side by remember { mutableStateOf("左") }
    var diaperKind by remember { mutableStateOf("小便") }
    var note by remember { mutableStateOf("") }

    fun save(): Boolean {
        val now = LocalTime.now().withSecond(0).withNano(0)
        val log = when (kind) {
            FeedLog.Kind.SLEEP -> {
                val m = minutes.toIntOrNull() ?: return false
                if (m <= 0) return false
                FeedLog(date = LocalDate.now(), time = now, kind = kind, minutes = m)
            }
            FeedLog.Kind.BREAST ->
                FeedLog(date = LocalDate.now(), time = now, kind = kind, side = side, minutes = minutes.toIntOrNull())
            FeedLog.Kind.BOTTLE -> {
                val v = ml.toDoubleOrNull() ?: return false
                if (v <= 0) return false
                FeedLog(date = LocalDate.now(), time = now, kind = kind, ml = v)
            }
            FeedLog.Kind.DIAPER ->
                FeedLog(date = LocalDate.now(), time = now, kind = kind, diaperKind = diaperKind)
            FeedLog.Kind.PUMPING ->
                FeedLog(date = LocalDate.now(), time = now, kind = kind, ml = ml.toDoubleOrNull())
            FeedLog.Kind.TEMP ->
                FeedLog(date = LocalDate.now(), time = now, kind = kind, value = ml.toDoubleOrNull() ?: 36.5)
            FeedLog.Kind.SOLID, FeedLog.Kind.SUPPLEMENT, FeedLog.Kind.CUSTOM ->
                FeedLog(date = LocalDate.now(), time = now, kind = kind, note = note.trim())
        }
        Store.addFeed(log.copy(note = note.trim()))
        onDismiss()
        return true
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.92f)
                .clip(RoundedCornerShape(20.dp))
                .background(Palette.background),
        ) {
            // 顶栏：取消 / 标题
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("取消", fontSize = 15.sp, color = Palette.purple,
                    modifier = Modifier.clickable { onDismiss() })
                Spacer(Modifier.weight(1f))
                Text("记录喂养", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
                Spacer(Modifier.weight(1f))
                Spacer(Modifier.width(52.dp))
            }

            Column(
                Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Row(
                    Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    FeedLog.Kind.entries.forEach { k ->
                        ChipLabel(text = k.title, selected = kind == k, icon = k.icon, onClick = { kind = k })
                    }
                }

                Column(
                    Modifier.fillMaxWidth().cardStyle(),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    if (kind == FeedLog.Kind.SLEEP || kind == FeedLog.Kind.BREAST) {
                        FeedField(title = "时长", text = minutes, unit = "分钟",
                            allowDecimal = false, onChange = { minutes = it })
                    }
                    if (kind == FeedLog.Kind.BOTTLE || kind == FeedLog.Kind.PUMPING) {
                        FeedField(title = if (kind == FeedLog.Kind.BOTTLE) "奶量" else "吸出奶量", text = ml, unit = "ml",
                            allowDecimal = true, onChange = { ml = it })
                    }
                    if (kind == FeedLog.Kind.TEMP) {
                        FeedField(title = "体温", text = ml, unit = "℃",
                            allowDecimal = true, onChange = { ml = it })
                    }
                    if (kind == FeedLog.Kind.BREAST) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            listOf("左", "右", "双侧").forEach { s ->
                                ChipLabel(text = s, selected = side == s, onClick = { side = s })
                            }
                        }
                    }
                    if (kind == FeedLog.Kind.DIAPER) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            listOf("小便", "大便", "混合").forEach { s ->
                                ChipLabel(text = s, selected = diaperKind == s, onClick = { diaperKind = s })
                            }
                        }
                    }
                    Column(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(13.dp))
                            .background(Palette.purpleTint)
                            .padding(horizontal = 13.dp, vertical = 10.dp),
                    ) {
                        Text("备注（可选）", fontSize = 11.5.sp, color = Palette.subtle)
                        BasicTextField(
                            value = note,
                            onValueChange = { note = it },
                            textStyle = TextStyle(fontSize = 15.sp, color = Palette.ink),
                            decorationBox = { inner ->
                                if (note.isEmpty()) {
                                    Text("如：夜里醒了两次", fontSize = 15.sp, color = Palette.subtle)
                                }
                                inner()
                            },
                        )
                    }
                }

                PrimaryButton(text = "保存记录") { save() }
            }
        }
    }
}

@Composable
private fun FeedField(title: String, text: String, unit: String, allowDecimal: Boolean, onChange: (String) -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(13.dp))
            .background(Palette.purpleTint)
            .padding(horizontal = 13.dp, vertical = 10.dp),
    ) {
        Text(title, fontSize = 11.5.sp, color = Palette.subtle)
        Row(verticalAlignment = Alignment.CenterVertically) {
            BasicTextField(
                value = text,
                onValueChange = { v ->
                    if (v.matches(if (allowDecimal) Regex("^\\d*(\\.\\d*)?$") else Regex("^\\d*$"))) onChange(v)
                },
                keyboardOptions = KeyboardOptions(
                    keyboardType = if (allowDecimal) KeyboardType.Decimal else KeyboardType.Number,
                ),
                textStyle = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink),
                modifier = Modifier.weight(1f),
            )
            Spacer(Modifier.width(4.dp))
            Text(unit, fontSize = 12.5.sp, color = Palette.subtle)
        }
    }
}
