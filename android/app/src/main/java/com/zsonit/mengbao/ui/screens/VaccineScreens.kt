package com.zsonit.mengbao.ui.screens

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zsonit.mengbao.data.Clinic
import com.zsonit.mengbao.data.Dose
import com.zsonit.mengbao.data.GrowthMath
import com.zsonit.mengbao.data.Standards
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.ui.ChipLabel
import com.zsonit.mengbao.ui.Avatar
import com.zsonit.mengbao.ui.DividerLine
import com.zsonit.mengbao.ui.EmptyHint
import com.zsonit.mengbao.ui.HintBlock
import com.zsonit.mengbao.ui.KVRow
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.SectionHeader
import com.zsonit.mengbao.ui.TagTone
import com.zsonit.mengbao.ui.TagView
import com.zsonit.mengbao.ui.TopBar
import com.zsonit.mengbao.ui.cardStyle
import java.util.Locale

// MARK: - 接种计划

private val ageFilters: List<Pair<String, IntRange?>> = listOf(
    "全部" to null,
    "0 岁" to 0..11,
    "1 岁" to 12..17,
    "2 岁" to 18..35,
    "3 岁" to 36..47,
    "4 岁" to 48..71,
    "6 岁" to 72..400,
)

private val scopeMap = mapOf(
    '①' to "儿童免疫规划",
    '②' to "卡介苗 / 乙肝首针",
    '③' to "狂犬病疫苗",
    '④' to "非免疫规划（自费）",
)

@Composable
fun VaccineScreen(onBack: () -> Unit, onOpenClinics: () -> Unit, onOpenYamiao: () -> Unit, onOpenNearby: () -> Unit) {
    val child = Store.current
    var filter by remember { mutableStateOf("全部") }
    var statusFilter by remember { mutableStateOf("全部") }
    var showOptional by remember { mutableStateOf(false) }

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = "接种计划", onBack = onBack)
        if (child == null) {
            EmptyHint("先添加宝宝档案，自动生成接种计划")
        } else {
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState()),
            ) {
                VaccineContent(
                    child = child,
                    filter = filter,
                    onFilter = { filter = it },
                    statusFilter = statusFilter,
                    onStatusFilter = { statusFilter = it },
                    onOpenClinics = onOpenClinics,
                    onOpenYamiao = onOpenYamiao,
                    onOpenNearby = onOpenNearby,
                    onOpenOptional = { showOptional = true },
                )
            }
        }
    }

    if (showOptional && child != null) {
        OptionalVaccineSheet(
            selected = child.optVaccines ?: emptyList(),
            onDismiss = { showOptional = false },
            onSave = { Store.setOptVaccines(it) },
        )
    }
}

@Composable
private fun VaccineContent(
    child: Child,
    filter: String,
    onFilter: (String) -> Unit,
    statusFilter: String,
    onStatusFilter: (String) -> Unit,
    onOpenClinics: () -> Unit,
    onOpenYamiao: () -> Unit,
    onOpenNearby: () -> Unit,
    onOpenOptional: () -> Unit,
) {
    val schedule = GrowthMath.schedule(child)
    val done = schedule.count { it.status == Dose.Status.DONE }
    val due = schedule.count { it.status == Dose.Status.DUE }
    val total = schedule.size
    val percent = (done.toDouble() / maxOf(total, 1).toDouble() * 100).toInt()
    val next = schedule.firstOrNull { it.status == Dose.Status.SOON }
    val range = ageFilters.firstOrNull { it.first == filter }?.second
    val ageVisible = if (range == null) schedule else schedule.filter { it.months in range }
    val visible = when (statusFilter) {
        "待接种" -> ageVisible.filter { it.status != Dose.Status.DONE }
        "已完成" -> ageVisible.filter { it.status == Dose.Status.DONE }
        else -> ageVisible
    }
    val statusFilters = listOf("全部", "待接种", "已完成")

    // Hero
    Box(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(top = 12.dp)
            .clip(RoundedCornerShape(22.dp)),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .background(Palette.warmGradient),
        ) {
            Box(
                Modifier
                    .align(Alignment.BottomEnd)
                    .offset(x = 40.dp, y = 56.dp)
                    .size(160.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.14f)),
            )
            Column(Modifier.fillMaxWidth().padding(18.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        Modifier
                            .size(50.dp)
                            .clip(CircleShape)
                            .border(2.dp, Color.White.copy(alpha = 0.6f), CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Avatar(
                            child = child, size = 46.dp, fontSize = 24.sp,
                            bg = Color.White.copy(alpha = 0.24f),
                        )
                    }
                    Spacer(Modifier.width(12.dp))
                    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Text(
                            "${child.name} 的接种日程",
                            fontSize = 19.sp, fontWeight = FontWeight.Bold, color = Color.White,
                        )
                        Text(
                            "依据国家免疫规划疫苗儿童免疫程序表（${Standards.scheduleYear} 年版，每年自动更新）",
                            fontSize = 11.sp, color = Color.White.copy(alpha = 0.92f),
                            lineHeight = 15.sp,
                        )
                    }
                }
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(top = 14.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color.White.copy(alpha = 0.18f))
                        .padding(horizontal = 12.dp, vertical = 9.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("💉 已接种 $done/$total 剂", fontSize = 12.5.sp, color = Color.White)
                    Spacer(Modifier.weight(1f))
                    Text("$percent%", fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
                }
                Box(
                    Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp)
                        .height(8.dp)
                        .clip(RoundedCornerShape(50))
                        .background(Color.White.copy(alpha = 0.28f)),
                ) {
                    Box(
                        Modifier
                            .fillMaxWidth(percent / 100f)
                            .height(8.dp)
                            .clip(RoundedCornerShape(50))
                            .background(Color.White),
                    )
                }
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(top = 10.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color.White.copy(alpha = 0.2f))
                        .border(1.dp, Color.White.copy(alpha = 0.45f), RoundedCornerShape(12.dp))
                        .clickable { onOpenNearby() }
                        .padding(horizontal = 12.dp, vertical = 10.dp),
                ) {
                    Text("🏥 门诊定位 · 一键同步全省门诊 →", fontSize = 13.sp, color = Color.White)
                }
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(top = 6.dp)
                        .clickable { onOpenYamiao() },
                ) {
                    Text(
                        "粤苗官方页（定位查门诊 / 预约）→",
                        fontSize = 11.5.sp, color = Color.White.copy(alpha = 0.85f),
                    )
                }
            }
        }
    }

    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(top = 12.dp)
            .cardStyle(padding = 14.dp),
    ) {
        KVRow(key = "已完成", value = "$done / $total 剂", valueColor = Palette.ok)
        DividerLine(Palette.hairlineSoft)
        KVRow(key = "已到期未种", value = "$due 剂", valueColor = if (due > 0) Palette.bad else Palette.subtle)
        DividerLine(Palette.hairlineSoft)
        KVRow(key = "下一针", value = next?.let { "${it.ageLabel} · ${it.vaccine.name}" } ?: "全部按计划完成")
        DividerLine(Palette.hairlineSoft)
        KVRow(key = "适用标准", value = "国家免疫规划 ${Standards.scheduleYear} 版")
    }

    OptionalEntryCard(child = child, onClick = onOpenOptional)

    Row(
        Modifier
            .fillMaxWidth()
            .padding(top = 14.dp)
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        ageFilters.forEach { (label, _) ->
            ChipLabel(text = label, selected = filter == label, onClick = { onFilter(label) })
        }
    }

    // 状态筛选：全部 / 待接种 / 已完成
    Row(
        Modifier
            .fillMaxWidth()
            .padding(top = 10.dp)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        statusFilters.forEach { label ->
            ChipLabel(text = label, selected = statusFilter == label, onClick = { onStatusFilter(label) })
        }
        Spacer(Modifier.weight(1f))
        Text("${visible.size} 剂", fontSize = 11.5.sp, color = Palette.subtle)
    }

    HintBlock(
        text = "点击卡片可切换「已接种 / 未接种」。同一天可同时接种多种疫苗（不同部位），接种后需留观 30 分钟。补种原则：未完成剂次按程序补齐，不需重新开始。",
        modifier = Modifier.padding(horizontal = 16.dp).padding(top = 10.dp),
    )

    if (visible.isEmpty()) {
        EmptyHint("这个筛选下还没有疫苗")
    }

    visible.forEach { dose ->
        Box(Modifier.padding(horizontal = 16.dp).padding(top = 9.dp)) {
            DoseCard(dose = dose, onToggle = { Store.toggleShot(dose.key) })
        }
    }

    SectionHeader(title = "非免疫规划疫苗（自费 · 自愿）")
    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .cardStyle(),
    ) {
        Standards.optionalVaccines.forEachIndexed { index, (name, plan) ->
            KVRow(key = "💉 $name", value = plan)
            if (index != Standards.optionalVaccines.lastIndex) {
                DividerLine(Palette.hairlineSoft)
            }
        }
        Text(
            "优先考虑水痘、EV71 手足口、Hib、13 价肺炎。与免疫规划疫苗时间冲突时，优先保证免疫规划疫苗。是否接种请与接种医生沟通。",
            fontSize = 12.sp, color = Palette.subtle, lineHeight = 18.sp,
            modifier = Modifier.padding(top = 10.dp),
        )
    }

    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(top = 12.dp)
            .clip(RoundedCornerShape(13.dp))
            .background(Palette.card)
            .clickable { onOpenClinics() }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("📋", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple)
        Spacer(Modifier.width(10.dp))
        Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text("常见接种门诊速查", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
            Text("离线名录，没网或想先看地址电话时用", fontSize = 11.sp, color = Palette.subtle)
        }
        Spacer(Modifier.weight(1f))
        Text("›", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.subtle)
    }

    HintBlock(
        text = "预约用「粤苗」App / 微信小程序，可查门诊号源、入学查验、电子接种证。本页仅作家庭记录，实际程序以接种门诊安排为准。",
        modifier = Modifier.padding(horizontal = 16.dp).padding(top = 12.dp),
    )
    Spacer(Modifier.height(28.dp))
}

// MARK: - 单剂卡片

@Composable
private fun DoseCard(dose: Dose, onToggle: () -> Unit) {
    val tone = when (dose.status) {
        Dose.Status.DONE -> TagTone.OK
        Dose.Status.DUE -> TagTone.BAD
        Dose.Status.SOON -> TagTone.WARN
        Dose.Status.PENDING -> TagTone.GRAY
    }
    val statusText = when (dose.status) {
        Dose.Status.DONE -> "已接种" + (dose.doneDate?.let { " · " + GrowthMath.dateString(it) } ?: "")
        Dose.Status.DUE -> "已到期 · 尽快补种"
        Dose.Status.SOON -> "近期接种"
        Dose.Status.PENDING -> "待接种"
    }
    val statusColor = when (dose.status) {
        Dose.Status.DONE -> Palette.ok
        Dose.Status.DUE -> Palette.bad
        else -> Palette.warn
    }
    val borderColor = when (dose.status) {
        Dose.Status.DUE -> Palette.bad.copy(alpha = 0.4f)
        Dose.Status.SOON -> Palette.warn.copy(alpha = 0.4f)
        else -> Palette.hairline
    }
    val shape = RoundedCornerShape(16.dp)

    Column(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Palette.card)
            .border(1.dp, borderColor, shape)
            .alpha(if (dose.status == Dose.Status.DONE) 0.78f else 1f)
            .clickable { onToggle() },
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .background(if (dose.status == Dose.Status.DONE) Palette.okBg else Palette.purpleTint)
                .padding(horizontal = 15.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(if (dose.status == Dose.Status.DONE) "✅" else "💉", fontSize = 17.sp)
            Spacer(Modifier.width(10.dp))
            Text(dose.vaccine.name, fontSize = 14.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
            if (dose.key.startsWith("opt|")) {
                Spacer(Modifier.width(6.dp))
                TagView(text = "自费", tone = TagTone.WARN)
            }
            Spacer(Modifier.weight(1f))
            TagView(text = dose.vaccine.dose, tone = tone)
        }
        Column(Modifier.fillMaxWidth().padding(horizontal = 15.dp, vertical = 10.dp)) {
            KVRow(key = "建议时间", value = "${dose.ageLabel}（约 ${GrowthMath.dateString(dose.dueDate)}）")
            KVRow(key = "接种途径", value = dose.vaccine.route)
            KVRow(key = "接种部位", value = dose.vaccine.site)
            KVRow(key = "状态", value = statusText, valueColor = statusColor)
            Box(Modifier.padding(vertical = 6.dp)) {
                DividerLine(Palette.hairlineSoft)
            }
            Text(
                "📌 ${dose.vaccine.note}",
                fontSize = 12.sp, color = Palette.subtle, lineHeight = 18.sp,
            )
        }
    }
}

// MARK: - 自选疫苗入口

@Composable
private fun OptionalEntryCard(child: Child, onClick: () -> Unit) {
    val picked = child.optVaccines ?: emptyList()
    val names = picked.mapNotNull { Standards.optionalById[it]?.name }
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(top = 10.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Palette.card)
            .border(1.dp, Palette.hairlineSoft, RoundedCornerShape(14.dp))
            .clickable { onClick() }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(11.dp),
    ) {
        Box(
            Modifier
                .size(36.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(Palette.purple.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center,
        ) { Text("💉", fontSize = 17.sp) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                if (picked.isEmpty()) "自选疫苗" else "自选疫苗 · 已选 ${picked.size} 种",
                fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink,
            )
            Text(
                if (picked.isEmpty()) "13 价肺炎、五联、轮状、水痘… 勾选后自动加入日程"
                else names.joinToString("、"),
                fontSize = 11.5.sp, color = Palette.subtle, maxLines = 2,
            )
        }
        Text("›", fontSize = 18.sp, color = Palette.subtle)
    }
}

// MARK: - 自选疫苗面板

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun OptionalVaccineSheet(
    selected: List<String>,
    onDismiss: () -> Unit,
    onSave: (List<String>) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var picked by remember { mutableStateOf(selected.toSet()) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = Palette.background,
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .navigationBarsPadding(),
        ) {
            Column(Modifier.padding(horizontal = 20.dp)) {
                Text("自选疫苗", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Palette.ink)
                Text(
                    "勾选后自动加入日程，相同功效仅建议选一种",
                    fontSize = 12.sp, color = Palette.subtle,
                    modifier = Modifier.padding(top = 4.dp),
                )
                Spacer(Modifier.height(10.dp))
            }
            Column(
                Modifier
                    .fillMaxWidth()
                    .heightIn(max = 520.dp)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Standards.optionalCatalog.forEach { v ->
                    OptionalRow(v = v, on = picked.contains(v.id)) {
                        picked = if (picked.contains(v.id)) picked - v.id else picked + v.id
                    }
                }
                HintBlock(
                    text = "价格为常见市场价区间，不同厂家、不同门诊会有差异；是否接种、何时接种请与接种门诊医生沟通。免疫规划疫苗（免费）优先保证。",
                )
                Spacer(Modifier.height(6.dp))
            }
            Box(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .padding(top = 10.dp, bottom = 14.dp)
                    .clip(RoundedCornerShape(15.dp))
                    .background(if (picked.isEmpty()) Palette.subtle.copy(alpha = 0.45f) else Palette.purple)
                    .clickable {
                        onSave(Standards.optionalCatalog.map { it.id }.filter { picked.contains(it) })
                        onDismiss()
                    }
                    .padding(vertical = 14.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    if (picked.isEmpty()) "确认（不选自费疫苗）" else "确认添加 ${picked.size} 种",
                    fontSize = 15.5.sp, fontWeight = FontWeight.SemiBold, color = Color.White,
                )
            }
        }
    }
}

@Composable
private fun OptionalRow(v: Standards.OptionalVaccine, on: Boolean, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Palette.card)
            .border(
                1.dp,
                if (on) Palette.purple.copy(alpha = 0.45f) else Palette.hairlineSoft,
                RoundedCornerShape(16.dp),
            )
            .clickable { onClick() }
            .padding(13.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            Modifier
                .padding(top = 2.dp)
                .size(22.dp)
                .clip(CircleShape)
                .background(if (on) Palette.purple else Color.Transparent)
                .border(if (on) 1.5.dp else 1.2.dp, if (on) Palette.purple else Palette.hairline, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            if (on) Text("✓", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Color.White)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(v.name, fontSize = 14.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
                Text(v.price, fontSize = 11.5.sp, fontWeight = FontWeight.Medium, color = Palette.purple)
            }
            Text(v.desc, fontSize = 11.5.sp, color = Palette.subtle, lineHeight = 17.sp)
        }
    }
}

// MARK: - 门诊列表

@Composable
fun ClinicListScreen(onBack: () -> Unit, onOpenYamiao: () -> Unit, onOpenDetail: (String) -> Unit) {
    var query by remember { mutableStateOf("") }
    var city by remember { mutableStateOf("全部城市") }
    var starOnly by remember { mutableStateOf(false) }

    val cityOptions = listOf("全部城市") + Standards.clinics.map { it.city }.distinct()
    val filtered = Standards.clinics.filter { c ->
        (city == "全部城市" || c.city == city)
            && (!starOnly || c.star)
            && (query.isBlank() || (c.name + c.address + c.district + c.vaccines).contains(query, ignoreCase = true))
    }
    // 全量数据时限制一次渲染的条数，保证滚动流畅
    val limit = if (city == "全部城市" && query.isBlank()) 80 else 500
    val visible = filtered.take(limit)

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = "接种门诊速查", onBack = onBack)
        LazyColumn(Modifier.fillMaxSize()) {
            item {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                        .padding(top = 12.dp)
                        .cardStyle(padding = 14.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(13.dp))
                            .background(Palette.purpleTint)
                            .clickable { onOpenYamiao() }
                            .padding(11.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(
                            Modifier
                                .size(34.dp)
                                .clip(RoundedCornerShape(10.dp))
                                .background(Palette.purple),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text("🗺", fontSize = 15.sp)
                        }
                        Spacer(Modifier.width(11.dp))
                        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(
                                "粤苗官方 · 定位查附近接种门诊",
                                fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink,
                            )
                            Text("省疾控官方名单，定位附近门诊、地图查看，权威实时", fontSize = 11.5.sp, color = Palette.subtle)
                        }
                        Spacer(Modifier.weight(1f))
                        Text("›", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.subtle)
                    }

                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(13.dp))
                            .background(Palette.purpleTint)
                            .padding(horizontal = 12.dp, vertical = 9.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("🔍", fontSize = 14.sp, color = Palette.subtle)
                        Spacer(Modifier.width(6.dp))
                        BasicTextField(
                            value = query,
                            onValueChange = { query = it },
                            singleLine = true,
                            textStyle = TextStyle(fontSize = 14.sp, color = Palette.ink),
                            modifier = Modifier.weight(1f),
                            decorationBox = { inner ->
                                if (query.isEmpty()) {
                                    Text("搜索门诊 / 区 / 路 / 疫苗", fontSize = 14.sp, color = Palette.subtle)
                                }
                                inner()
                            },
                        )
                    }

                    Row(
                        Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        cityOptions.forEach { c ->
                            ChipLabel(text = c, selected = city == c, onClick = { city = c })
                        }
                        ChipLabel(text = "★ 只看示范门诊", selected = starOnly, onClick = { starOnly = !starOnly })
                    }

                    Text(
                        "共 ${filtered.size} 家" +
                            if (visible.size < filtered.size) " · 当前显示前 ${visible.size} 家，可搜索或选城市"
                            else " · 出发前请电话确认",
                        fontSize = 12.sp, color = Palette.subtle,
                    )
                }
            }

            items(visible.size) { index ->
                val clinic = visible[index]
                Box(Modifier.padding(horizontal = 16.dp).padding(top = 10.dp)) {
                    ClinicRow(clinic = clinic, onClick = { onOpenDetail(clinic.id) })
                }
            }

            item {
                HintBlock(
                    text = "本页是离线速查名录（常见门诊地址与电话）。想看周边全部可接种单位，用上面的「粤苗官方 · 定位查附近接种门诊」，官方名单实时定位查询。门诊地址与开诊时间会变动，出发前请电话确认，预约以「粤苗」为准。",
                    modifier = Modifier.padding(horizontal = 16.dp).padding(top = 14.dp),
                )
                Spacer(Modifier.height(28.dp))
            }
        }
    }
}

@Composable
private fun ClinicRow(clinic: Clinic, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Column(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Palette.card)
            .border(1.dp, Palette.hairline, shape)
            .clickable { onClick() }
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Text(clinic.scootLabel, fontSize = 18.sp)
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(clinic.name, fontSize = 14.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
                Text(
                    "${clinic.city} · ${clinic.district} · ${clinic.tag}",
                    fontSize = 12.sp, color = Palette.subtle,
                )
            }
            if (clinic.star) {
                Spacer(Modifier.width(8.dp))
                TagView(text = "示范", tone = TagTone.PURPLE)
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text("🕐 ${clinic.hours}", fontSize = 12.5.sp, color = Palette.ink2, lineHeight = 18.sp)
            Text("💉 ${clinic.vaccines}", fontSize = 12.5.sp, color = Palette.ink2, lineHeight = 18.sp)
            Text("📍 ${clinic.address}", fontSize = 12.5.sp, color = Palette.ink2, lineHeight = 18.sp)
        }
    }
}

// MARK: - 门诊详情

@Composable
fun ClinicDetailScreen(clinicId: String, onBack: () -> Unit) {
    val clinic = Standards.clinics.firstOrNull { it.id == clinicId }
    val context = LocalContext.current

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = "门诊详情", onBack = onBack)
        if (clinic == null) {
            EmptyHint("未找到该门诊信息")
            return
        }

        val scopeText = clinic.scope.mapNotNull { scopeMap[it] }.joinToString(" · ")
        val lat = String.format(Locale.US, "%.6f", clinic.lat)
        val lng = String.format(Locale.US, "%.6f", clinic.lng)

        fun navigateHere() {
            val amap = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("androidamap://navi?sourceApplication=mengbao&lat=$lat&lon=$lng&dev=0&style=2"),
            )
            val resolved = runCatching { amap.resolveActivity(context.packageManager) }.getOrNull()
            if (resolved != null) {
                context.startActivity(amap)
            } else {
                runCatching {
                    context.startActivity(
                        Intent(
                            Intent.ACTION_VIEW,
                            Uri.parse(
                                "https://uri.amap.com/navigation?to=$lng,$lat," +
                                    Uri.encode(clinic.name) + "&mode=car&src=mengbao&coordinate=gaode&callnative=1",
                            ),
                        ),
                    )
                }
            }
        }

        fun openOnMap() {
            runCatching {
                context.startActivity(
                    Intent(
                        Intent.ACTION_VIEW,
                        Uri.parse(
                            "https://uri.amap.com/marker?position=$lng,$lat&name=" +
                                Uri.encode(clinic.name) + "&src=mengbao&coordinate=gaode",
                        ),
                    ),
                )
            }
        }

        fun callClinic() {
            runCatching {
                context.startActivity(
                    Intent(Intent.ACTION_DIAL, Uri.parse("tel:${clinic.phone.filter { it.isDigit() }}")),
                )
            }
        }

        fun copyAddress() {
            val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
            cm.setPrimaryClip(
                ClipData.newPlainText("clinic", "${clinic.name}\n${clinic.address}\n电话：${clinic.phone}"),
            )
        }

        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .cardStyle(),
            ) {
                KVRow(key = "城市 / 区", value = "${clinic.city} · ${clinic.district}")
                DividerLine(Palette.hairlineSoft)
                KVRow(key = "类型", value = clinic.tag)
                DividerLine(Palette.hairlineSoft)
                KVRow(key = "接种范围", value = scopeText)
                DividerLine(Palette.hairlineSoft)
                KVRow(key = "可接种", value = clinic.vaccines)
                DividerLine(Palette.hairlineSoft)
                KVRow(key = "开诊时间", value = clinic.hours)
                DividerLine(Palette.hairlineSoft)
                KVRow(key = "地址", value = clinic.address)
                DividerLine(Palette.hairlineSoft)
                KVRow(key = "提示", value = clinic.note, valueColor = Palette.warn)
            }

            Column(
                Modifier.fillMaxWidth().padding(top = 12.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                DetailButton(
                    text = "📞 打电话 ${clinic.phone}",
                    filled = true,
                    modifier = Modifier.fillMaxWidth(),
                    onClick = { callClinic() },
                )
                DetailButton(
                    text = "🧭 导航到这里（高德地图）",
                    filled = false,
                    modifier = Modifier.fillMaxWidth(),
                    onClick = { navigateHere() },
                )
                DetailButton(
                    text = "🗺 在地图上查看",
                    filled = false,
                    modifier = Modifier.fillMaxWidth(),
                    onClick = { openOnMap() },
                )
                DetailButton(
                    text = "📋 复制地址",
                    filled = false,
                    modifier = Modifier.fillMaxWidth(),
                    onClick = { copyAddress() },
                )
            }

            HintBlock(
                text = "门诊信息为离线示例数据，开诊时间与号源请以「粤苗」小程序或门诊公示为准。",
                modifier = Modifier.padding(top = 12.dp),
            )
        }
    }
}

@Composable
private fun DetailButton(text: String, filled: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier
            .clip(RoundedCornerShape(13.dp))
            .background(if (filled) Palette.purple else Palette.purpleSoft)
            .clickable { onClick() }
            .padding(vertical = 13.dp)
            .fillMaxWidth(),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text,
            fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
            color = if (filled) Color.White else Palette.purple,
            textAlign = TextAlign.Center,
        )
    }
}
