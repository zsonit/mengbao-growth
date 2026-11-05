package com.zsonit.mengbao.ui.screens

import android.Manifest
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Event
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zsonit.mengbao.data.Clinic
import com.zsonit.mengbao.data.CalendarSync
import com.zsonit.mengbao.data.Dose
import com.zsonit.mengbao.data.GrowthMath
import com.zsonit.mengbao.data.Standards
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.CustomShot
import com.zsonit.mengbao.model.DosePlan
import com.zsonit.mengbao.ui.ChipLabel
import com.zsonit.mengbao.ui.Avatar
import com.zsonit.mengbao.ui.DateField
import com.zsonit.mengbao.ui.DividerLine
import com.zsonit.mengbao.ui.EmptyHint
import com.zsonit.mengbao.ui.HintBlock
import com.zsonit.mengbao.ui.KVRow
import com.zsonit.mengbao.ui.NumberInput
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.SectionHeader
import com.zsonit.mengbao.ui.TagTone
import com.zsonit.mengbao.ui.TagView
import com.zsonit.mengbao.ui.TextInput
import com.zsonit.mengbao.ui.TopBar
import com.zsonit.mengbao.ui.cardStyle
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.util.Locale

// MARK: - 接种计划

/** 按年龄段折叠分组（每组一个年龄段，点开显示该年龄段要打的疫苗） */
private data class AgeGroup(val months: Int, val label: String, val doses: List<Dose>)

/** 年龄段标签：优先用程序表叫法，自选疫苗的月龄现场生成 */
private fun ageGroupLabel(months: Int): String {
    Standards.vaccineAges.firstOrNull { it.second == months }?.let { return it.first }
    return when {
        months < 12 -> "${months} 月龄"
        months % 12 == 0 -> "${months / 12} 岁"
        else -> "${months} 月龄"
    }
}

private val scopeMap = mapOf(
    '①' to "儿童免疫规划",
    '②' to "卡介苗 / 乙肝首针",
    '③' to "狂犬病疫苗",
    '④' to "非免疫规划（自费）",
)

@Composable
fun VaccineScreen(onBack: () -> Unit, onOpenClinics: () -> Unit, onOpenYamiao: () -> Unit, onOpenNearby: () -> Unit) {
    val child = Store.current
    var statusFilter by remember { mutableStateOf("全部") }
    var showOptional by remember { mutableStateOf(false) }
    var planDose by remember { mutableStateOf<Dose?>(null) }
    var showCustomShot by remember { mutableStateOf(false) }

    val scrollState = rememberScrollState()
    var containerTopY by remember { mutableIntStateOf(0) }

    val context = LocalContext.current
    val calPerm = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { }

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = "接种计划", onBack = onBack)
        if (child == null) {
            EmptyHint("先添加宝宝档案，自动生成接种计划")
        } else {
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(scrollState)
                    .onGloballyPositioned { containerTopY = it.positionInRoot().y.toInt() },
            ) {
                VaccineContent(
                    child = child,
                    statusFilter = statusFilter,
                    onStatusFilter = { statusFilter = it },
                    scrollState = scrollState,
                    containerTopY = containerTopY,
                    onOpenClinics = onOpenClinics,
                    onOpenYamiao = onOpenYamiao,
                    onOpenNearby = onOpenNearby,
                    onOpenOptional = { showOptional = true },
                    onPlan = { planDose = it },
                    onAddCustomShot = { showCustomShot = true },
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

    if (planDose != null && child != null) {
        DosePlanDialog(
            dose = planDose!!,
            child = child,
            onDismiss = { planDose = null },
            onRequestCalendarPermission = {
                if (!CalendarSync.permissionGranted(context)) {
                    calPerm.launch(Manifest.permission.WRITE_CALENDAR)
                }
            },
        )
    }

    if (showCustomShot) {
        CustomShotDialog(onDismiss = { showCustomShot = false })
    }
}

@Composable
private fun VaccineContent(
    child: Child,
    statusFilter: String,
    onStatusFilter: (String) -> Unit,
    scrollState: ScrollState,
    containerTopY: Int,
    onOpenClinics: () -> Unit,
    onOpenYamiao: () -> Unit,
    onOpenNearby: () -> Unit,
    onOpenOptional: () -> Unit,
    onPlan: (Dose) -> Unit,
    onAddCustomShot: () -> Unit,
) {
    val schedule = GrowthMath.schedule(child)
    val done = schedule.count { it.status == Dose.Status.DONE }
    val due = schedule.count { it.status == Dose.Status.DUE }
    val total = schedule.size
    val percent = (done.toDouble() / maxOf(total, 1).toDouble() * 100).toInt()
    val next = schedule.firstOrNull { it.status == Dose.Status.SOON }
    val statusFilters = listOf("全部", "待接种", "已完成")

    // 按年龄段（月龄）分组，含自选疫苗剂次，按月龄升序
    val buckets = linkedMapOf<Int, MutableList<Dose>>()
    schedule.forEach { dose -> buckets.getOrPut(dose.months) { mutableListOf() }.add(dose) }
    val groups = buckets.keys.sorted().map { m -> AgeGroup(m, ageGroupLabel(m), buckets[m].orEmpty()) }
    val groupVisible = groups.mapNotNull { g ->
        val doses = when (statusFilter) {
            "待接种" -> g.doses.filter { it.status != Dose.Status.DONE }
            "已完成" -> g.doses.filter { it.status == Dose.Status.DONE }
            else -> g.doses
        }
        if (doses.isEmpty()) null else g.copy(doses = doses)
    }
    val visibleCount = groupVisible.sumOf { it.doses.size }

    // 默认展开「已到期 / 近期接种」的年龄段；手动展开收起的状态保存在 remember(child)
    val expanded = remember(child) {
        mutableStateOf(
            schedule.filter { it.status == Dose.Status.DUE || it.status == Dose.Status.SOON }
                .map { it.months }.toSet(),
        )
    }
    // 各分组标题在滚动内容中的纵向偏移，供顶部年龄段 chips 跳转定位
    val groupOffsets = remember { mutableStateMapOf<Int, Int>() }
    val scope = rememberCoroutineScope()

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

    // 年龄段导航：点一下展开并跳到对应分组
    Row(
        Modifier
            .fillMaxWidth()
            .padding(top = 14.dp)
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        groups.forEach { group ->
            ChipLabel(
                text = group.label,
                selected = expanded.value.contains(group.months),
                onClick = {
                    expanded.value = expanded.value + group.months
                    scope.launch {
                        groupOffsets[group.months]?.let { scrollState.animateScrollTo(it) }
                    }
                },
            )
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
        Text("$visibleCount 剂", fontSize = 11.5.sp, color = Palette.subtle)
    }

    HintBlock(
        text = "点年龄段可展开 / 收起这一阶段要打的疫苗；点击疫苗卡片可切换「已接种 / 未接种」。同一天可同时接种多种疫苗（不同部位），接种后需留观 30 分钟。",
        modifier = Modifier.padding(horizontal = 16.dp).padding(top = 10.dp),
    )

    if (groupVisible.isEmpty()) {
        EmptyHint("这个筛选下还没有疫苗")
    }

    groupVisible.forEach { group ->
        AgeGroupSection(
            group = group,
            isExpanded = expanded.value.contains(group.months),
            onToggleExpand = {
                expanded.value = if (expanded.value.contains(group.months)) {
                    expanded.value - group.months
                } else {
                    expanded.value + group.months
                }
            },
            onDoseToggle = { dose ->
                if (dose.status != Dose.Status.LOCKED) Store.toggleShot(dose.key)
            },
            onPlan = onPlan,
            planOf = { dose -> (child.plans ?: emptyMap())[dose.key] },
            recordOffset = { y -> groupOffsets[group.months] = y - containerTopY + scrollState.value },
        )
    }

    CustomShotsCard(child = child, onAdd = onAddCustomShot)

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

/** 年龄段折叠分组：标题（年龄段 · 已种 x/y）+ 展开后的疫苗卡列表 */
@Composable
private fun AgeGroupSection(
    group: AgeGroup,
    isExpanded: Boolean,
    onToggleExpand: () -> Unit,
    onDoseToggle: (Dose) -> Unit,
    onPlan: (Dose) -> Unit,
    planOf: (Dose) -> DosePlan?,
    recordOffset: (Int) -> Unit,
) {
    // 灭活分支卡（乙脑灭活 / 甲肝灭活）：照常显示，但不计入组内 x/y 总数
    val branchCodes = setOf("JE-I", "HepA-I")
    val counted = group.doses.count { it.vaccine.code !in branchCodes }
    val doneCount = minOf(group.doses.count { it.status == Dose.Status.DONE }, counted)
    val dueCount = group.doses.count { it.status == Dose.Status.DUE }
    val allDone = counted > 0 && doneCount == counted
    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(top = 10.dp),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(13.dp))
                .background(Palette.card)
                .border(
                    1.dp,
                    if (dueCount > 0) Palette.bad.copy(alpha = 0.35f) else Palette.hairlineSoft,
                    RoundedCornerShape(13.dp),
                )
                .clickable { onToggleExpand() }
                .padding(horizontal = 14.dp, vertical = 11.dp)
                .onGloballyPositioned { recordOffset(it.positionInRoot().y.toInt()) },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier
                    .size(9.dp)
                    .clip(CircleShape)
                    .background(
                        when {
                            dueCount > 0 -> Palette.bad
                            allDone -> Palette.ok
                            else -> Palette.subtle.copy(alpha = 0.55f)
                        },
                    ),
            )
            Spacer(Modifier.width(9.dp))
            Text(group.label, fontSize = 15.5.sp, fontWeight = FontWeight.Bold, color = Palette.ink)
            if (group.months == 156) {
                Spacer(Modifier.width(6.dp))
                TagView(text = "推荐关注", tone = TagTone.WARN)
            }
            Spacer(Modifier.width(7.dp))
            Text(
                "已种 $doneCount/$counted",
                fontSize = 12.sp, fontWeight = FontWeight.Medium,
                color = when {
                    allDone -> Palette.ok
                    dueCount > 0 -> Palette.bad
                    else -> Palette.subtle
                },
            )
            Spacer(Modifier.weight(1f))
            Text(
                if (isExpanded) "⌃" else "⌄",
                fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.subtle,
            )
        }

        if (isExpanded) {
            group.doses.forEach { dose ->
                Column(
                    Modifier.padding(top = 9.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    DoseCard(dose = dose, onToggle = { onDoseToggle(dose) })
                    PlanBar(dose = dose, plan = planOf(dose), onClick = { onPlan(dose) })
                }
            }
        }
    }
}

// MARK: - 单剂卡片

@Composable
private fun DoseCard(dose: Dose, onToggle: () -> Unit) {
    val isLocked = dose.status == Dose.Status.LOCKED
    val tone = when (dose.status) {
        Dose.Status.DONE -> TagTone.OK
        Dose.Status.DUE -> TagTone.BAD
        Dose.Status.SOON -> TagTone.WARN
        Dose.Status.LOCKED -> TagTone.GRAY
        Dose.Status.PENDING -> TagTone.GRAY
    }
    val statusText = when (dose.status) {
        Dose.Status.DONE -> "已接种" + (dose.doneDate?.let { " · " + GrowthMath.dateString(it) } ?: "")
        Dose.Status.DUE -> "已到期 · 尽快补种"
        Dose.Status.SOON -> "近期接种"
        Dose.Status.LOCKED -> "已锁定"
        Dose.Status.PENDING -> "待接种"
    }
    val statusColor = when (dose.status) {
        Dose.Status.DONE -> Palette.ok
        Dose.Status.DUE -> Palette.bad
        Dose.Status.LOCKED -> Palette.subtle
        else -> Palette.warn
    }
    val borderColor = when (dose.status) {
        Dose.Status.DUE -> Palette.bad.copy(alpha = 0.4f)
        Dose.Status.SOON -> Palette.warn.copy(alpha = 0.4f)
        else -> Palette.hairline
    }
    val shape = RoundedCornerShape(16.dp)
    val altGroup = Standards.altGroupOf(dose.vaccine.code)

    Column(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Palette.card)
            .border(1.dp, borderColor, shape)
            .alpha(
                when {
                    dose.status == Dose.Status.DONE -> 0.78f
                    isLocked -> 0.62f
                    else -> 1f
                }
            )
            .clickable(enabled = !isLocked) { onToggle() },
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

        // 减毒 / 灭活「二选一」提示条（橙红字）
        if (altGroup != null) {
            Text(
                if (isLocked) "已接种${Standards.altLabel[dose.vaccine.code] ?: "另一种"}，此项自动锁定"
                else "减毒 / 灭活 二选一。接种其一后另一种自动锁定",
                fontSize = 11.5.sp, fontWeight = FontWeight.SemiBold,
                color = if (isLocked) Palette.subtle else Palette.bad,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(if (isLocked) Palette.hairlineSoft.copy(alpha = 0.4f) else Palette.bad.copy(alpha = 0.08f))
                    .padding(horizontal = 15.dp, vertical = 8.dp),
            )
        }

        Column(Modifier.fillMaxWidth().padding(horizontal = 15.dp, vertical = 10.dp)) {
            KVRow(key = "推荐接种时间", value = GrowthMath.dateString(dose.dueDate))
            KVRow(key = "接种部位", value = dose.vaccine.site)
            KVRow(key = "状态", value = statusText, valueColor = statusColor)
            Box(Modifier.padding(vertical = 6.dp)) {
                DividerLine(Palette.hairlineSoft)
            }
            // 预防什么 + 接种方式 + 剂量（剂量加粗）
            val extra = Standards.extraByCode[dose.vaccine.code]
            if (extra != null) {
                Column {
                    Text("预防${extra.first}", fontSize = 12.5.sp, color = Palette.subtle, lineHeight = 17.sp)
                    Row {
                        Text("接种方式：${dose.vaccine.route}。剂量：", fontSize = 12.5.sp, color = Palette.subtle)
                        Text(extra.second, fontSize = 13.5.sp, fontWeight = FontWeight.Bold, color = Palette.ink)
                    }
                }
                Spacer(Modifier.height(4.dp))
            }
            Text(
                "📌 ${dose.vaccine.note}",
                fontSize = 12.sp, color = Palette.subtle, lineHeight = 18.sp,
            )
        }
    }
}

// MARK: - 安排接种条 / 弹窗

/** 「安排接种」小条：显示计划摘要，点开安排弹窗 */
@Composable
private fun PlanBar(dose: Dose, plan: DosePlan?, onClick: () -> Unit) {
    val summary = if (plan == null) {
        "推荐接种时间 ${GrowthMath.dateString(dose.dueDate)}"
    } else {
        buildList {
            add("计划 ${GrowthMath.dateString(plan.date?.toLocalDate() ?: dose.dueDate)}")
            if (plan.remindOn) add("提前 ${plan.advanceEffective} 天提醒")
            if (plan.place.isNotEmpty()) add("📍 ${plan.place}")
            if (plan.calSync) add("已同步日历")
        }.joinToString(" · ")
    }
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(11.dp))
            .background(Palette.card)
            .border(1.dp, Palette.hairlineSoft, RoundedCornerShape(11.dp))
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = Icons.Default.Event,
            contentDescription = null,
            tint = Palette.purple,
            modifier = Modifier.size(14.dp),
        )
        Spacer(Modifier.width(8.dp))
        Text(summary, fontSize = 11.5.sp, color = if (plan == null) Palette.subtle else Palette.ink, maxLines = 1)
        Spacer(Modifier.weight(1f))
        Text("安排", fontSize = 11.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple)
    }
}

/** 「安排接种」弹窗：指定时刻 / 提醒提前天数 / 地点 / 备注 / 同步系统日历 */
@Composable
private fun DosePlanDialog(
    dose: Dose,
    child: Child,
    onDismiss: () -> Unit,
    onRequestCalendarPermission: () -> Unit,
) {
    val existing = (child.plans ?: emptyMap())[dose.key]
    var specifyTime by remember { mutableStateOf(existing?.date != null) }
    var planDate by remember {
        mutableStateOf(existing?.date?.toLocalDate() ?: dose.dueDate.coerceAtLeast(LocalDate.now()))
    }
    var planHour by remember { mutableStateOf(existing?.date?.hour ?: 9) }
    var planMinute by remember { mutableStateOf(existing?.date?.minute ?: 0) }
    var remindOn by remember { mutableStateOf(existing?.remindOn ?: true) }
    var advanceDays by remember { mutableStateOf(existing?.advanceEffective ?: 1) }
    var place by remember { mutableStateOf(existing?.place ?: "") }
    var note by remember { mutableStateOf(existing?.note ?: "") }
    var calSync by remember { mutableStateOf(existing?.calSync ?: false) }
    var calMsg by remember { mutableStateOf<String?>(null) }
    val context = LocalContext.current

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("${dose.vaccine.name} ${dose.vaccine.dose}", fontSize = 16.sp, fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "默认使用推荐接种时间（${GrowthMath.dateString(dose.dueDate)}），可按门诊安排调整。保存安排后仍需单独记录实际接种。",
                    fontSize = 11.5.sp, color = Palette.subtle, lineHeight = 16.sp,
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("指定接种时刻", fontSize = 14.sp, color = Palette.ink, modifier = Modifier.weight(1f))
                    Switch(
                        checked = specifyTime,
                        onCheckedChange = { specifyTime = it },
                        colors = SwitchDefaults.colors(checkedTrackColor = Palette.purple),
                    )
                }
                Text(
                    if (specifyTime) "计划接种时间（含时刻）" else "计划接种日期",
                    fontSize = 11.5.sp, color = Palette.subtle,
                )
                if (specifyTime) {
                    DateField(label = "日期", date = planDate, onDate = { planDate = it })
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        NumberInput("时", planHour.toString(), unit = "点", modifier = Modifier.weight(1f)) {
                            planHour = (it.toIntOrNull() ?: 9).coerceIn(0, 23)
                        }
                        NumberInput("分", planMinute.toString(), unit = "分", modifier = Modifier.weight(1f)) {
                            planMinute = (it.toIntOrNull() ?: 0).coerceIn(0, 59)
                        }
                    }
                } else {
                    DateField(label = "日期", date = planDate, onDate = { planDate = it })
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("接种提醒", fontSize = 14.sp, color = Palette.ink, modifier = Modifier.weight(1f))
                    Switch(
                        checked = remindOn,
                        onCheckedChange = { remindOn = it },
                        colors = SwitchDefaults.colors(checkedTrackColor = Palette.purple),
                    )
                }
                if (remindOn) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("提前", fontSize = 13.sp, color = Palette.subtle)
                        listOf(1, 3, 7).forEach { d ->
                            ChipLabel(text = if (d == 1) "提前一天" else "提前 $d 天", selected = advanceDays == d, onClick = { advanceDays = d })
                        }
                    }
                }
                TextInput(label = "接种地点（可选）", value = place, placeholder = "例如 区妇幼保健院", onChange = { place = it })
                TextInput(label = "备注（可选）", value = note, placeholder = "剂次、医生交代等", onChange = { note = it })
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("同步到系统日历", fontSize = 14.sp, color = Palette.ink)
                        Text("写进手机日历，到点由日历提醒", fontSize = 11.sp, color = Palette.subtle)
                    }
                    Switch(
                        checked = calSync,
                        onCheckedChange = { on ->
                            calSync = on
                            if (on) onRequestCalendarPermission()
                        },
                        colors = SwitchDefaults.colors(checkedTrackColor = Palette.purple),
                    )
                }
                calMsg?.let { Text(it, fontSize = 11.5.sp, color = Palette.bad) }
                Text("未指定接种时刻时，提醒以当天 09:00 计算。", fontSize = 11.sp, color = Palette.subtle)
            }
        },
        confirmButton = {
            TextButton(onClick = {
                val plan = DosePlan(
                    date = if (specifyTime) planDate.atTime(planHour, planMinute) else null,
                    remindOn = remindOn,
                    advanceDays = advanceDays,
                    place = place.trim(),
                    note = note.trim(),
                    calSync = calSync,
                )
                Store.setDosePlan(dose.key, plan)
                if (calSync) {
                    val err = CalendarSync.addDoseEvent(context, child, dose, plan)
                    if (err != null) {
                        calMsg = err
                        return@TextButton
                    }
                }
                onDismiss()
            }) { Text("保存安排") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        },
    )
}

// MARK: - 其他接种记录

/** 其他接种记录卡片（狂犬、破伤风等时间表外的疫苗） */
@Composable
private fun CustomShotsCard(child: Child, onAdd: () -> Unit) {
    val shots = child.customShots ?: emptyList()
    SectionHeader(title = "其他接种记录")
    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .cardStyle(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (shots.isEmpty()) {
            Text(
                "暂无记录。狂犬、破伤风等时间表外的疫苗可以在这里登记。",
                fontSize = 12.sp, color = Palette.subtle,
            )
        } else {
            shots.forEach { shot ->
                Row(verticalAlignment = Alignment.Top) {
                    Text("💉", fontSize = 15.sp)
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) {
                        Text(shot.name, fontSize = 13.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
                        Text(
                            GrowthMath.dateString(shot.date) + if (shot.place.isNotEmpty()) " · ${shot.place}" else "",
                            fontSize = 11.5.sp, color = Palette.subtle,
                        )
                        if (shot.note.isNotEmpty()) {
                            Text(shot.note, fontSize = 11.5.sp, color = Palette.subtle)
                        }
                    }
                    TextButton(onClick = { Store.removeCustomShot(shot.id) }) {
                        Text("删除", fontSize = 12.sp, color = Palette.subtle)
                    }
                }
            }
        }
        TextButton(onClick = onAdd) {
            Text("＋ 记一次", fontSize = 13.sp, color = Palette.purple, fontWeight = FontWeight.SemiBold)
        }
    }
}

/** 其他接种登记弹窗 */
@Composable
private fun CustomShotDialog(onDismiss: () -> Unit) {
    var name by remember { mutableStateOf("") }
    var date by remember { mutableStateOf(LocalDate.now()) }
    var place by remember { mutableStateOf("") }
    var note by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("其他疫苗接种登记", fontSize = 16.sp, fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "狂犬、破伤风、流感等时间表外的疫苗：打了什么、时间、地点、剂次都可以记。",
                    fontSize = 11.5.sp, color = Palette.subtle, lineHeight = 16.sp,
                )
                TextInput(label = "疫苗名称", value = name, placeholder = "例如 狂犬疫苗 第 2 针", onChange = { name = it })
                DateField(label = "接种日期", date = date, onDate = { date = it })
                TextInput(label = "接种地点（可选）", value = place, placeholder = "例如 市疾控中心", onChange = { place = it })
                TextInput(label = "备注（可选）", value = note, placeholder = "剂次、厂家等", onChange = { note = it })
            }
        },
        confirmButton = {
            TextButton(onClick = {
                if (name.trim().isEmpty()) return@TextButton
                Store.addCustomShot(CustomShot(name = name.trim(), date = date, place = place.trim(), note = note.trim()))
                onDismiss()
            }) { Text("保存") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        },
    )
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
