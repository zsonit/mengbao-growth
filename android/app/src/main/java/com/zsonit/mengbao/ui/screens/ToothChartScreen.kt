package com.zsonit.mengbao.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.ToothDecay
import com.zsonit.mengbao.ui.DateField
import com.zsonit.mengbao.ui.DividerLine
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.PrimaryButton
import com.zsonit.mengbao.ui.TopBar
import com.zsonit.mengbao.ui.cardStyle
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.material3.OutlinedTextField
import java.time.LocalDate
import java.time.Period
import java.time.format.DateTimeFormatter

// MARK: - 乳牙标准（与 iOS ToothDef 保持一致）

/** 恒牙（28 颗，不含智齿）：龋齿记录选牙图使用；FDI 1/2 象限上颌（右/左），3/4 象限下颌（左/右） */
object PermanentTooth {
    val upperOrder = listOf(17, 16, 15, 14, 13, 12, 11, 21, 22, 23, 24, 25, 26, 27)
    val lowerOrder = listOf(47, 46, 45, 44, 43, 42, 41, 31, 32, 33, 34, 35, 36, 37)
    val names: Map<Int, String> = mapOf(
        11 to "上中切牙", 12 to "上侧切牙", 13 to "上尖牙", 14 to "上第一前磨牙",
        15 to "上第二前磨牙", 16 to "上第一磨牙", 17 to "上第二磨牙",
        21 to "上中切牙", 22 to "上侧切牙", 23 to "上尖牙", 24 to "上第一前磨牙",
        25 to "上第二前磨牙", 26 to "上第一磨牙", 27 to "上第二磨牙",
        31 to "下中切牙", 32 to "下侧切牙", 33 to "下尖牙", 34 to "下第一前磨牙",
        35 to "下第二前磨牙", 36 to "下第一磨牙", 37 to "下第二磨牙",
        41 to "下中切牙", 42 to "下侧切牙", 43 to "下尖牙", 44 to "下第一前磨牙",
        45 to "下第二前磨牙", 46 to "下第一磨牙", 47 to "下第二磨牙",
    )

    /** 统一取名：先查恒牙，再查乳牙 */
    fun toothName(code: Int): String =
        names[code] ?: ToothDef.all[code]?.name ?: "牙位 $code"
}

data class ToothDef(
    val code: Int,
    val name: String,
    val earlyMonths: Int,
    val lateMonths: Int,
) {
    val isUpper: Boolean get() = code < 70

    val windowLabel: String
        get() = "${yearLabel(earlyMonths)} ~ ${yearLabel(lateMonths)}"

    private fun yearLabel(m: Int): String =
        if (m % 12 == 0) "${m / 12}岁" else "${m / 12}岁半"

    companion object {
        val upperOrder = listOf(55, 54, 53, 52, 51, 61, 62, 63, 64, 65)
        val lowerOrder = listOf(85, 84, 83, 82, 81, 71, 72, 73, 74, 75)

        val all: Map<Int, ToothDef> = listOf(
            Triple(51, "上乳中切牙", 72 to 96), Triple(52, "上乳侧切牙", 84 to 102),
            Triple(53, "上乳尖牙", 114 to 144), Triple(54, "上乳第一磨牙", 114 to 138),
            Triple(55, "上乳第二磨牙", 120 to 150),
            Triple(61, "上乳中切牙", 72 to 96), Triple(62, "上乳侧切牙", 84 to 102),
            Triple(63, "上乳尖牙", 114 to 144), Triple(64, "上乳第一磨牙", 114 to 138),
            Triple(65, "上乳第二磨牙", 120 to 150),
            Triple(71, "下乳中切牙", 66 to 84), Triple(72, "下乳侧切牙", 78 to 96),
            Triple(73, "下乳尖牙", 108 to 126), Triple(74, "下乳第一磨牙", 108 to 132),
            Triple(75, "下乳第二磨牙", 114 to 138),
            Triple(81, "下乳中切牙", 66 to 84), Triple(82, "下乳侧切牙", 78 to 96),
            Triple(83, "下乳尖牙", 108 to 126), Triple(84, "下乳第一磨牙", 108 to 132),
            Triple(85, "下乳第二磨牙", 114 to 138),
        ).associate { (code, name, window) -> code to ToothDef(code, name, window.first, window.second) }
    }
}

// MARK: - 状态

enum class ToothStatus(val label: String, val color: Color) {
    FALLEN("已脱落/换牙", Color(0xFF1F9D6B)),
    OVERDUE("超期未换", Color(0xFF6A48F5)),
    WARN("临近/预警", Color(0xFFD97706)),
    NORMAL("未到换牙期", Color(0xFF8B86A4));
}

data class ToothState(val def: ToothDef, val status: ToothStatus, val fallenDate: LocalDate?, val decay: ToothDecay? = null)

/** 龋齿程度配色，与 iOS DecayTone 保持一致 */
object DecayTone {
    fun color(severity: Int): Color = when (severity) {
        3 -> Color(0xFFE0513A)
        2 -> Color(0xFFD97706)
        else -> Color(0xFFC08A2E)
    }

    fun bg(severity: Int): Color = when (severity) {
        3 -> Color(0x1AE0513A)
        2 -> Color(0x1AD97706)
        else -> Color(0x12D97706)
    }
}

// MARK: - 主屏

@Composable
fun ToothChartScreen(onBack: () -> Unit) {
    var tab by remember { mutableIntStateOf(0) }
    var selected by remember { mutableStateOf<ToothDef?>(null) }
    var decayEditFor by remember { mutableStateOf<Int?>(null) }
    var decayAddOpen by remember { mutableStateOf(false) }

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = "换牙档案", onBack = onBack)
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            SummaryCard(onOpenDecay = { tab = 2 })
            TabBar(tab) { tab = it }
            when (tab) {
                0 -> Column(
                    Modifier
                        .padding(horizontal = 16.dp)
                        .fillMaxWidth()
                        .cardStyle(padding = 6.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    ArchChart(isUpper = true) { selected = ToothDef.all[it] }
                    ArchChart(isUpper = false) { selected = ToothDef.all[it] }
                    LegendRow()
                }
                1 -> ScheduleSection { selected = ToothDef.all[it] }
                else -> DecaySection(onOpen = { selected = it }, onAdd = { decayAddOpen = true })
            }
            HintCard()
        }
    }

    selected?.let { def ->
        ToothDialog(
            def = def,
            onDismiss = { selected = null },
            onEditDecay = { decayEditFor = def.code },
        )
    }
    // 记录/修改龋齿：从「龋齿记录」页添加，或从单颗牙详情进来
    val editCode = decayEditFor
    if (editCode != null) {
        DecayDialog(initialCode = editCode, onDismiss = { decayEditFor = null })
    } else if (decayAddOpen) {
        DecayDialog(initialCode = null, onDismiss = { decayAddOpen = false })
    }
}

// MARK: 状态推导

private fun ageMonthsOf(child: Child): Int {
    val p = Period.between(child.birthDate, LocalDate.now())
    return p.years * 12 + p.months
}

@Composable
private fun toothState(code: Int): ToothState {
    val def = ToothDef.all[code] ?: return ToothState(ToothDef(code, "", 0, 0), ToothStatus.NORMAL, null)
    val child = Store.current
    val fallen = child?.teethFallen?.get(code)
    val status = when {
        fallen != null -> ToothStatus.FALLEN
        child == null -> ToothStatus.NORMAL
        else -> {
            val ageM = ageMonthsOf(child)
            when {
                ageM > def.lateMonths -> ToothStatus.OVERDUE
                ageM >= def.earlyMonths - 6 -> ToothStatus.WARN
                else -> ToothStatus.NORMAL
            }
        }
    }
    return ToothState(def, status, fallen, child?.teethDecay?.get(code))
}

@Composable
private fun allStates(): List<ToothState> =
    (ToothDef.upperOrder + ToothDef.lowerOrder).map { toothState(it) }

// MARK: 顶部统计卡

@Composable
private fun SummaryCard(onOpenDecay: () -> Unit) {
    val states = allStates()
    val counts = states.groupingBy { it.status }.eachCount()
    val child = Store.current
    val years = child?.let { Period.between(it.birthDate, LocalDate.now()).years } ?: 0
    val decayMap = child?.teethDecay ?: emptyMap()
    val decayCount = decayMap.size
    val needVisit = decayMap.values.count { it.needsVisit }

    Column(
        Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .cardStyle(padding = 16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "儿童年龄：${maxOf(years, 0)}岁",
                fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink,
            )
            Spacer(Modifier.weight(1f))
            Text("总牙数 28 颗 · 乳牙 20 颗（6-12 岁换完）", fontSize = 12.sp, color = Palette.subtle)
        }
        Spacer(Modifier.height(12.dp))
        Row(Modifier.fillMaxWidth()) {
            StatCell(counts[ToothStatus.FALLEN] ?: 0, "已脱落", ToothStatus.FALLEN.color, Modifier.weight(1f))
            StatCell(counts[ToothStatus.WARN] ?: 0, "临近/预警", ToothStatus.WARN.color, Modifier.weight(1f))
            StatCell(counts[ToothStatus.OVERDUE] ?: 0, "超期未换", ToothStatus.OVERDUE.color, Modifier.weight(1f))
            StatCell(counts[ToothStatus.NORMAL] ?: 0, "未到换牙期", ToothStatus.NORMAL.color, Modifier.weight(1f))
        }
        Spacer(Modifier.height(12.dp))
        // 20 格状态条
        Row(
            Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)),
            horizontalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            (ToothDef.upperOrder + ToothDef.lowerOrder).forEach { code ->
                Box(
                    Modifier
                        .weight(1f)
                        .height(8.dp)
                        .background(toothState(code).status.color),
                )
            }
        }
        Spacer(Modifier.height(10.dp))
        // 龋齿（烂牙）入口
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(if (decayCount > 0) Color(0x1AE0513A) else Palette.purpleTint)
                .clickable { onOpenDecay() }
                .padding(horizontal = 11.dp, vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                if (decayCount > 0) {
                    "已记录 $decayCount 颗龋齿（烂牙）" + if (needVisit > 0) " · $needVisit 颗建议就诊" else ""
                } else {
                    "还没有记录龋齿（烂牙）"
                },
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (decayCount > 0) DecayTone.color(3) else Palette.purple,
            )
            Spacer(Modifier.weight(1f))
            Text(
                if (decayCount > 0) "查看 →" else "去记录 →",
                fontSize = 11.5.sp,
                fontWeight = FontWeight.Medium,
                color = if (decayCount > 0) DecayTone.color(3) else Palette.purple,
            )
        }
    }
}

@Composable
private fun RowScope.StatCell(value: Int, label: String, color: Color, modifier: Modifier = Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text("$value", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = color)
            Text("颗", fontSize = 11.sp, color = Palette.subtle, modifier = Modifier.padding(start = 2.dp, bottom = 2.dp))
        }
        Text(label, fontSize = 11.sp, color = Palette.subtle)
    }
}

// MARK: 分段选择

@Composable
private fun TabBar(tab: Int, onSelect: (Int) -> Unit) {
    Row(
        Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(50))
            .background(Palette.hairlineSoft)
            .padding(3.dp),
    ) {
        listOf("牙弓图", "换牙时间表", "龋齿记录").forEachIndexed { i, title ->
            val active = tab == i
            Box(
                Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(50))
                    .background(if (active) Palette.card else Color.Transparent)
                    .clickable { onSelect(i) }
                    .padding(vertical = 10.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    title,
                    fontSize = 13.sp,
                    fontWeight = if (active) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (active) Palette.ink else Palette.subtle,
                    maxLines = 1,
                )
            }
        }
    }
}

// MARK: 牙弓图（单颌）

/** 单颗牙单元格总高度：编号 15dp + 间距 2dp + 牙冠 34dp */
private val TOOTH_CELL_H = 51.dp

/** 单颌牙弓图固定高度（ry 不随容器撑满，避免上下颌弧重叠） */
private val ARCH_HEIGHT = 210.dp

@Composable
private fun ArchChart(isUpper: Boolean, selected: Int? = null, codes: List<Int>? = null, onTap: (Int) -> Unit) {
    val density = LocalDensity.current
    BoxWithConstraints(
        Modifier
            .fillMaxWidth()
            .height(ARCH_HEIGHT),
    ) {
        val wPx = with(density) { maxWidth.toPx() }
        val cx = wPx / 2f
        val rx = wPx / 2f - with(density) { 40.dp.toPx() }
        val ry = with(density) { 120.dp.toPx() }
        val cy = with(density) { (if (isUpper) ARCH_HEIGHT - 35.dp else 35.dp).toPx() }

        // 牙龈弧：椭圆弧线（外扩 14dp，线宽 28dp），只画本颌那一段
        Canvas(Modifier.fillMaxSize()) {
            val gr = rx + with(density) { 14.dp.toPx() }
            val gy = ry + with(density) { 14.dp.toPx() }
            drawArc(
                color = Color(0x29F48FB1),
                topLeft = Offset(cx - gr, cy - gy),
                size = Size(2 * gr, 2 * gy),
                startAngle = if (isUpper) 180f else 0f,
                sweepAngle = 180f,
                useCenter = false,
                style = Stroke(width = with(density) { 28.dp.toPx() }, cap = StrokeCap.Round),
            )
        }

        val list = codes ?: if (isUpper) ToothDef.upperOrder else ToothDef.lowerOrder
        val step = if (list.size > 1) 170.0 / (list.size - 1) else 0.0
        val nineDp = with(density) { 9.dp.toPx() }
        val fortySixDp = with(density) { 46.dp.toPx() }
        list.forEachIndexed { idx, code ->
            // 从左端 175° 到右端 5°，均匀分布
            val theta = Math.toRadians(175.0 - idx * step)
            val x = cx + rx * kotlin.math.cos(theta).toFloat()
            val y = if (isUpper) {
                cy - ry * kotlin.math.sin(theta).toFloat()
            } else {
                cy + ry * kotlin.math.sin(theta).toFloat()
            }

            val xDp = with(density) { x.toDp() }
            val yDp = with(density) { (y + (if (isUpper) -nineDp else nineDp)).toDp() }

            Box(
                Modifier
                    .align(Alignment.TopStart)
                    .offset(x = xDp - 22.dp, y = yDp - TOOTH_CELL_H / 2),
            ) {
                ToothCell(code = code, isUpper = isUpper, onTap = onTap, selected = selected == code)
            }
        }

        Text(
            if (isUpper) "上颌（Maxillary）" else "下颌（Mandibular）",
            fontSize = 11.sp, color = Palette.subtle,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .offset(y = with(density) { (cy + (if (isUpper) -fortySixDp else fortySixDp)).toDp() } - 10.dp),
        )
    }
}

@Composable
private fun ToothCell(code: Int, isUpper: Boolean, onTap: (Int) -> Unit, selected: Boolean = false) {
    val st = toothState(code)
    val decayed = st.decay != null
    Column(
        Modifier
            .width(44.dp)
            .clickable { onTap(code) },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (isUpper) ToothNumber(st, selected)
        Box {
            Box(
                Modifier
                    .size(width = 28.dp, height = 34.dp)
                    .shadow(
                        elevation = if (selected || st.status == ToothStatus.WARN || st.status == ToothStatus.OVERDUE) 7.dp else 0.dp,
                        shape = RoundedCornerShape(9.dp),
                        ambientColor = if (selected) Palette.purple else st.status.color,
                        spotColor = if (selected) Palette.purple else st.status.color,
                    )
                    .clip(RoundedCornerShape(9.dp))
                    .background(
                        when {
                            selected -> Palette.purple
                            st.status == ToothStatus.NORMAL -> Palette.card
                            else -> st.status.color
                        },
                    )
                    .then(
                        if (st.status == ToothStatus.NORMAL && !selected) {
                            Modifier.border(
                                if (decayed) 1.8.dp else 1.5.dp,
                                if (decayed) DecayTone.color(3) else Palette.hairline,
                                RoundedCornerShape(9.dp),
                            )
                        } else {
                            Modifier
                        },
                    ),
                contentAlignment = Alignment.Center,
            ) {
                when (st.status) {
                    ToothStatus.FALLEN -> Text(
                        "✓",
                        color = Color.White,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    ToothStatus.WARN, ToothStatus.OVERDUE ->
                        Text("!", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                    ToothStatus.NORMAL -> {}
                }
            }
            // 龋齿标记：右上角小红点（不影响脱落/预警状态）
            if (decayed) {
                Box(
                    Modifier
                        .align(Alignment.TopEnd)
                        .padding(top = 0.dp, end = 0.dp)
                        .size(9.dp)
                        .background(Color.White, CircleShape)
                        .padding(1.dp)
                        .background(DecayTone.color(3), CircleShape),
                )
            }
        }
        if (!isUpper) ToothNumber(st, selected)
    }
}

@Composable
private fun ToothNumber(st: ToothState, selected: Boolean = false) {
    Text(
        "${st.def.code}",
        fontSize = 10.5.sp,
        fontWeight = FontWeight.SemiBold,
        color = when {
            selected -> Palette.purple
            st.decay != null -> DecayTone.color(3)
            st.status == ToothStatus.NORMAL -> Palette.subtle
            else -> st.status.color
        },
        modifier = Modifier.height(15.dp),
    )
}

@Composable
private fun LegendRow() {
    Column(Modifier.fillMaxWidth().padding(vertical = 10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Row(
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            listOf(
                ToothStatus.NORMAL, ToothStatus.WARN, ToothStatus.FALLEN, ToothStatus.OVERDUE,
            ).forEach { s ->
                Row(
                    Modifier.padding(horizontal = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        Modifier
                            .size(10.dp)
                            .border(1.5.dp, s.color, CircleShape),
                    )
                    Text(" ${s.label}", fontSize = 10.5.sp, color = Palette.subtle)
                }
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 4.dp)) {
            Box(
                Modifier
                    .size(8.dp)
                    .background(DecayTone.color(3), CircleShape),
            )
            Text("  龋齿（烂牙）· 牙冠右上角红点", fontSize = 10.5.sp, color = Palette.subtle)
        }
    }
}

// MARK: 时间表

private val fmt: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")

@Composable
private fun ScheduleSection(onTap: (Int) -> Unit) {
    Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        // 换牙时间表：文字列表（按用户反馈从牙图版改回）
        ScheduleGroup("上颌（Maxillary）", ToothDef.upperOrder, onTap)
        ScheduleGroup("下颌（Mandibular）", ToothDef.lowerOrder, onTap)
    }
}

@Composable
private fun ScheduleGroup(title: String, codes: List<Int>, onTap: (Int) -> Unit) {
    Column(Modifier.fillMaxWidth()) {
        Text(title, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.subtle)
        Spacer(Modifier.height(8.dp))
        Column(Modifier.fillMaxWidth().cardStyle(padding = 4.dp)) {
            codes.forEachIndexed { idx, code ->
                val st = toothState(code)
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { onTap(code) }
                        .padding(vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        "$code",
                        fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Palette.purple,
                        modifier = Modifier.width(34.dp),
                    )
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) {
                        Text(st.def.name, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Palette.ink)
                        Text("换牙期 ${st.def.windowLabel}", fontSize = 11.5.sp, color = Palette.subtle)
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        if (st.fallenDate != null) {
                            Text("已脱落 · ${st.fallenDate.format(fmt)}", fontSize = 11.5.sp, color = Palette.ok)
                        } else {
                            Text(
                                st.status.label,
                                fontSize = 11.5.sp, fontWeight = FontWeight.Medium,
                                color = if (st.status == ToothStatus.NORMAL) Palette.subtle else st.status.color,
                            )
                        }
                        st.decay?.let { d ->
                            Text(
                                "🦷 龋齿 · ${d.severityLabel}",
                                fontSize = 10.5.sp, fontWeight = FontWeight.Medium,
                                color = DecayTone.color(d.severity),
                            )
                        }
                    }
                }
                if (idx != codes.lastIndex) {
                    androidx.compose.material3.HorizontalDivider(color = Palette.hairlineSoft)
                }
            }
        }
    }
}

@Composable
private fun HintCard() {
    Text(
        "点击牙弓图上的任意一颗牙，可以记录脱落日期、标记龋齿（烂牙）或恢复。换牙期为大多数孩子的普遍规律，个体差异 ±6 个月都属正常；" +
            "「超期未换」建议请口腔科医生看看，确认恒牙萌出情况。",
        fontSize = 11.5.sp, color = Palette.subtle, lineHeight = 17.sp,
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Palette.purpleTint)
            .padding(14.dp),
    )
}

// MARK: 单颗牙弹窗（脱落 + 龋齿）

@Composable
private fun ToothDialog(def: ToothDef, onDismiss: () -> Unit, onEditDecay: () -> Unit) {
    val st = toothState(def.code)
    var pickDate by remember { mutableStateOf(LocalDate.now()) }
    val context = androidx.compose.ui.platform.LocalContext.current

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column {
                Text("${def.name}（${def.code}）", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = Palette.ink)
                Text(
                    (if (def.earlyMonths > 0) "换牙期 ${def.windowLabel} · " else "") + "当前：${st.status.label}",
                    fontSize = 12.sp, color = Palette.subtle,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        },
        text = {
            Column {
                // 龋齿（烂牙）
                Text("🦷 龋齿（烂牙）", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.subtle)
                Spacer(Modifier.height(6.dp))
                val decay = st.decay
                if (decay != null) {
                    Text(
                        "${decay.severityLabel} · ${decay.date.format(fmt)}" + if (decay.needsVisit) " · 建议就诊" else "",
                        fontSize = 12.5.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = DecayTone.color(decay.severity),
                    )
                    if (decay.note.isNotEmpty()) {
                        Text(decay.note, fontSize = 12.sp, color = Palette.ink2, lineHeight = 17.sp)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        TextButton(onClick = onEditDecay) { Text("修改记录", color = Palette.purple) }
                        TextButton(onClick = {
                            Store.setToothDecay(def.code, null)
                        }) { Text("清除", color = Palette.bad) }
                    }
                } else {
                    Text(
                        "有黑点、蛀洞、牙齿发黄发黑或孩子喊牙疼时，记一下这颗牙。",
                        fontSize = 11.5.sp, color = Palette.subtle, lineHeight = 16.sp,
                    )
                    TextButton(onClick = onEditDecay) { Text("这颗牙有蛀牙 / 烂了", color = Palette.purple) }
                }
                DividerLine()
                Spacer(Modifier.height(6.dp))
                // 脱落记录
                Text("脱落记录", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.subtle)
                Spacer(Modifier.height(6.dp))
                if (st.fallenDate != null) {
                    Text(
                        "脱落日期：${st.fallenDate.format(fmt)}",
                        fontSize = 13.sp, color = ToothStatus.FALLEN.color,
                    )
                } else {
                    DateField(
                        label = "脱落日期（默认今天）",
                        date = pickDate,
                        onDate = { pickDate = it },
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                if (st.fallenDate != null) {
                    Store.setToothFallen(def.code, null)
                } else {
                    Store.setToothFallen(def.code, pickDate)
                    android.widget.Toast.makeText(context, "已记录 ${def.code} 号牙脱落", android.widget.Toast.LENGTH_SHORT).show()
                }
                onDismiss()
            }) {
                Text(if (st.fallenDate != null) "恢复为「未脱落」" else "标记这颗牙已脱落", color = Palette.purple)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("关闭", color = Palette.subtle) }
        },
    )
}

// MARK: 龋齿记录页

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DecaySection(onOpen: (ToothDef) -> Unit, onAdd: () -> Unit) {
    val decayMap = Store.current?.teethDecay ?: emptyMap()
    val rows = (ToothDef.all.keys + PermanentTooth.names.keys).sorted().filter { decayMap.containsKey(it) }

    Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.fillMaxWidth().cardStyle(padding = 6.dp)) {
            if (rows.isEmpty()) {
                Column(
                    Modifier.fillMaxWidth().padding(vertical = 22.dp, horizontal = 18.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text("🦷", fontSize = 30.sp)
                    Spacer(Modifier.height(6.dp))
                    Text("还没有记录龋齿", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
                    Text(
                        "发现哪颗牙有黑点、蛀洞或者孩子喊牙疼，就在这里记下来，复诊时一目了然。",
                        fontSize = 12.sp, color = Palette.subtle, lineHeight = 17.sp,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            } else {
                rows.forEachIndexed { i, code ->
                    val d = decayMap[code] ?: return@forEachIndexed
                    val def = ToothDef.all[code] ?: ToothDef(code, PermanentTooth.toothName(code), 0, 0)
                    val tone = DecayTone.color(d.severity)
                    val context = androidx.compose.ui.platform.LocalContext.current
                    val dismissState = rememberSwipeToDismissBoxState(
                        confirmValueChange = { value ->
                            if (value == SwipeToDismissBoxValue.EndToStart) {
                                Store.setToothDecay(code, null)
                                android.widget.Toast.makeText(
                                    context, "已删除 $code 号牙的龋齿记录", android.widget.Toast.LENGTH_SHORT,
                                ).show()
                                true
                            } else {
                                false
                            }
                        },
                    )
                    SwipeToDismissBox(
                        state = dismissState,
                        enableDismissFromStartToEnd = false,
                        backgroundContent = {
                            Box(
                                Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 4.dp, vertical = 3.dp)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(Color(0xFFE64F4D)),
                                contentAlignment = Alignment.CenterEnd,
                            ) {
                                Column(
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    modifier = Modifier.padding(end = 20.dp),
                                ) {
                                    Icon(
                                        Icons.Filled.Delete,
                                        contentDescription = "删除",
                                        tint = Color.White,
                                        modifier = Modifier.size(20.dp),
                                    )
                                    Text("删除", fontSize = 10.5.sp, color = Color.White)
                                }
                            }
                        },
                    ) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clickable { onOpen(def) }
                            .padding(horizontal = 8.dp, vertical = 9.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(
                            Modifier
                                .size(width = 42.dp, height = 46.dp)
                                .clip(RoundedCornerShape(10.dp))
                                .background(DecayTone.bg(d.severity)),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center,
                        ) {
                            Text("$code", fontSize = 12.5.sp, fontWeight = FontWeight.Bold, color = tone)
                            Text(def.name.removePrefix("上乳").removePrefix("下乳"), fontSize = 8.sp, color = tone.copy(alpha = 0.8f), maxLines = 1)
                        }
                        Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(def.name, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Palette.ink)
                                Spacer(Modifier.width(6.dp))
                                Text(
                                    d.severityLabel,
                                    fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = tone,
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(50))
                                        .background(DecayTone.bg(d.severity))
                                        .padding(horizontal = 5.dp, vertical = 1.5.dp),
                                )
                            }
                            Text(
                                "记录于 ${d.date.format(fmt)}" + if (d.needsVisit) " · 建议就诊" else "",
                                fontSize = 11.5.sp,
                                color = if (d.needsVisit) ToothStatus.WARN.color else Palette.subtle,
                            )
                            if (d.note.isNotEmpty()) {
                                Text(d.note, fontSize = 11.5.sp, color = Palette.ink2, maxLines = 2, lineHeight = 16.sp)
                            }
                        }
                    }
                    }
                    if (i != rows.lastIndex) DividerLine()
                }
            }
        }

        PrimaryButton(
            text = if (rows.isEmpty()) "记录一颗龋齿（烂牙）" else "再记录一颗",
            onClick = onAdd,
        )

        if (rows.isNotEmpty()) {
            Text(
                "点任意一条可以补充备注或清除记录，左滑一条记录可直接删除。中重度蛀牙建议尽快看儿童口腔科，乳牙龋坏会影响恒牙萌出和咀嚼。",
                fontSize = 11.5.sp, color = Palette.subtle, lineHeight = 16.sp,
                modifier = Modifier.padding(horizontal = 4.dp),
            )
        }
    }
}

// MARK: 记录龋齿弹窗（点牙弓图选牙）

@Composable
private fun DecayDialog(initialCode: Int?, onDismiss: () -> Unit) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val existing = Store.current?.teethDecay?.get(initialCode)

    var code by remember { mutableStateOf(initialCode) }
    var date by remember { mutableStateOf(existing?.date ?: LocalDate.now()) }
    var severity by remember { mutableStateOf(existing?.severity ?: 1) }
    var note by remember { mutableStateOf(existing?.note ?: "") }

    val dayFmt = java.time.format.DateTimeFormatter.ofPattern("M月d日")
    val base = Store.current?.records?.maxByOrNull { it.date }?.date
    val next = nextMeasureReminder(base)

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(
            Modifier
                .fillMaxWidth(0.94f)
                .clip(RoundedCornerShape(24.dp))
                .background(Palette.card)
                .verticalScroll(rememberScrollState())
                .padding(18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    code?.let { "记录龋齿 · $it" } ?: "记录龋齿",
                    fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Palette.ink,
                )
                Spacer(Modifier.weight(1f))
                Text(
                    code?.let { c -> PermanentTooth.toothName(c) } ?: "点牙位选择（28 颗恒牙）",
                    fontSize = 11.5.sp, color = if (code == null) Palette.subtle else Palette.purple,
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    "✕", fontSize = 15.sp, color = Palette.subtle,
                    modifier = Modifier.clickable { onDismiss() }.padding(6.dp),
                )
            }

            // 与「牙弓图」同款排布（28 颗恒牙位）：直接点牙齿选
            ArchChart(isUpper = true, selected = code, codes = PermanentTooth.upperOrder) { code = it }
            ArchChart(isUpper = false, selected = code, codes = PermanentTooth.lowerOrder) { code = it }
            Text(
                "红点 = 已有记录 · 紫色 = 当前选择 · 图为 28 颗恒牙位",
                fontSize = 10.5.sp, color = Palette.subtle,
            )
            Spacer(Modifier.height(12.dp))

            DateField(
                label = "发现日期",
                date = date,
                onDate = { date = it },
            )
            Spacer(Modifier.height(10.dp))

            Text(
                "程度（${listOf("轻度：白斑发黑没洞，加强刷牙+涂氟", "中度：有蛀洞，1~2 周内补牙", "重度：深龋/疼过，尽快就诊")[severity - 1]}）",
                fontSize = 11.sp, color = DecayTone.color(severity),
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(6.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(1 to "轻度", 2 to "中度", 3 to "重度").forEach { (v, label) ->
                    val on = severity == v
                    Box(
                        Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (on) DecayTone.color(v) else Palette.hairlineSoft)
                            .clickable { severity = v }
                            .padding(vertical = 9.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            label,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (on) Color.White else Palette.ink2,
                        )
                    }
                }
            }
            Spacer(Modifier.height(10.dp))

            OutlinedTextField(
                value = note,
                onValueChange = { note = it },
                label = { Text("备注（可选）") },
                placeholder = { Text("如：咬合面有洞，医生已补") },
                modifier = Modifier.fillMaxWidth(),
            )

            if (next != null) {
                Spacer(Modifier.height(8.dp))
                Text(
                    "提醒：下次测量提醒排在 ${next.format(dayFmt)}",
                    fontSize = 10.5.sp, color = Palette.subtle,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            Spacer(Modifier.height(14.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                TextButton(onClick = onDismiss) { Text("取消", color = Palette.subtle) }
                Box(Modifier.weight(1f)) {
                    val enabled = code != null
                    PrimaryButton(
                        text = if (enabled) "保存" else "先选一颗牙",
                        enabled = enabled,
                        onClick = {
                            val c = code
                            if (c != null) {
                                Store.setToothDecay(c, ToothDecay(date = date, severity = severity, note = note.trim()))
                                android.widget.Toast.makeText(context, "已记录 $c 号牙龋齿", android.widget.Toast.LENGTH_SHORT).show()
                                onDismiss()
                            }
                        },
                    )
                }
            }
        }
    }
}

/** 测量提醒的下次日期（开着的才显示），与 Reminders 的算法一致 */
private fun nextMeasureReminder(base: LocalDate?): LocalDate? {
    val s = Store.settings
    if (!s.growthReminderOn) return null
    var cursor = base ?: LocalDate.now()
    var guard = 0
    while (guard < 400) {
        guard += 1
        cursor = cursor.plusDays(maxOf(1, s.growthReminderDays).toLong())
        if (cursor.atTime(s.growthReminderHour, s.growthReminderMinute).isAfter(java.time.LocalDateTime.now())) return cursor
    }
    return null
}
