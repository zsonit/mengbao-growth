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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import com.zsonit.mengbao.ui.DateField
import com.zsonit.mengbao.ui.DividerLine
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.TopBar
import com.zsonit.mengbao.ui.cardStyle
import java.time.LocalDate
import java.time.Period
import java.time.format.DateTimeFormatter

// MARK: - 乳牙标准（与 iOS ToothDef 保持一致）

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

data class ToothState(val def: ToothDef, val status: ToothStatus, val fallenDate: LocalDate?)

// MARK: - 主屏

@Composable
fun ToothChartScreen(onBack: () -> Unit) {
    var tab by remember { mutableIntStateOf(0) }
    var selected by remember { mutableStateOf<ToothDef?>(null) }

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = "换牙档案", onBack = onBack)
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            SummaryCard()
            TabBar(tab) { tab = it }
            if (tab == 0) {
                Column(
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
            } else {
                ScheduleSection { selected = ToothDef.all[it] }
            }
            HintCard()
        }
    }

    selected?.let { def ->
        ToothDialog(def = def, onDismiss = { selected = null })
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
    return ToothState(def, status, fallen)
}

@Composable
private fun allStates(): List<ToothState> =
    (ToothDef.upperOrder + ToothDef.lowerOrder).map { toothState(it) }

// MARK: 顶部统计卡

@Composable
private fun SummaryCard() {
    val states = allStates()
    val counts = states.groupingBy { it.status }.eachCount()
    val child = Store.current
    val years = child?.let { Period.between(it.birthDate, LocalDate.now()).years } ?: 0

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
        listOf("拟真牙弓图", "换牙时间表").forEachIndexed { i, title ->
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
                    fontSize = 14.sp,
                    fontWeight = if (active) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (active) Palette.ink else Palette.subtle,
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
private fun ArchChart(isUpper: Boolean, onTap: (Int) -> Unit) {
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

        val codes = if (isUpper) ToothDef.upperOrder else ToothDef.lowerOrder
        val nineDp = with(density) { 9.dp.toPx() }
        val fortySixDp = with(density) { 46.dp.toPx() }
        codes.forEachIndexed { idx, code ->
            // 从左端 175° 到右端 5°，均匀分布 10 颗
            val theta = Math.toRadians(175.0 - idx * 18.888)
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
                ToothCell(code = code, isUpper = isUpper, onTap = onTap)
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
private fun ToothCell(code: Int, isUpper: Boolean, onTap: (Int) -> Unit) {
    val st = toothState(code)
    Column(
        Modifier
            .width(44.dp)
            .clickable { onTap(code) },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (isUpper) ToothNumber(st)
        Box(
            Modifier
                .size(width = 28.dp, height = 34.dp)
                .shadow(
                    elevation = if (st.status == ToothStatus.WARN || st.status == ToothStatus.OVERDUE) 7.dp else 0.dp,
                    shape = RoundedCornerShape(9.dp),
                    ambientColor = st.status.color,
                    spotColor = st.status.color,
                )
                .clip(RoundedCornerShape(9.dp))
                .background(if (st.status == ToothStatus.NORMAL) Palette.card else st.status.color)
                .then(
                    if (st.status == ToothStatus.NORMAL) {
                        Modifier.border(1.5.dp, Palette.hairline, RoundedCornerShape(9.dp))
                    } else {
                        Modifier
                    },
                ),
            contentAlignment = Alignment.Center,
        ) {
            when (st.status) {
                ToothStatus.FALLEN -> Text("✓", color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                ToothStatus.WARN, ToothStatus.OVERDUE ->
                    Text("!", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                ToothStatus.NORMAL -> {}
            }
        }
        if (!isUpper) ToothNumber(st)
    }
}

@Composable
private fun ToothNumber(st: ToothState) {
    Text(
        "${st.def.code}",
        fontSize = 10.5.sp,
        fontWeight = FontWeight.SemiBold,
        color = if (st.status == ToothStatus.NORMAL) Palette.subtle else st.status.color,
        modifier = Modifier.height(15.dp),
    )
}

@Composable
private fun LegendRow() {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 10.dp),
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
}

// MARK: 时间表

private val fmt: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")

@Composable
private fun ScheduleSection(onTap: (Int) -> Unit) {
    Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        ScheduleGroup("上颌（Maxillary）", listOf(51, 52, 53, 54, 55, 61, 62, 63, 64, 65), onTap)
        ScheduleGroup("下颌（Mandibular）", listOf(71, 72, 73, 74, 75, 81, 82, 83, 84, 85), onTap)
    }
}

@Composable
private fun ScheduleGroup(title: String, codes: List<Int>, onTap: (Int) -> Unit) {
    Column(Modifier.fillMaxWidth()) {
        Text(
            title,
            fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.subtle,
            modifier = Modifier.padding(bottom = 8.dp),
        )
        Column(Modifier.fillMaxWidth().cardStyle(padding = 4.dp)) {
            codes.forEachIndexed { i, code ->
                val st = toothState(code)
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { onTap(code) }
                        .padding(horizontal = 12.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        "$code",
                        fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Palette.purple,
                        modifier = Modifier.width(36.dp),
                    )
                    Column(Modifier.weight(1f)) {
                        Text(st.def.name, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Palette.ink)
                        Text("换牙期 ${st.def.windowLabel}", fontSize = 11.5.sp, color = Palette.subtle)
                    }
                    if (st.fallenDate != null) {
                        Text("已脱落 · ${st.fallenDate.format(fmt)}", fontSize = 11.5.sp, color = ToothStatus.FALLEN.color)
                    } else {
                        Text(
                            st.status.label,
                            fontSize = 11.5.sp, fontWeight = FontWeight.Medium,
                            color = if (st.status == ToothStatus.NORMAL) Palette.subtle else st.status.color,
                        )
                    }
                }
                if (i != codes.lastIndex) DividerLine()
            }
        }
    }
}

@Composable
private fun HintCard() {
    Text(
        "点击牙弓图上的任意一颗牙，可以记录脱落日期或恢复。换牙期为大多数孩子的普遍规律，个体差异 ±6 个月都属正常；" +
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

// MARK: 单颗牙弹窗

@Composable
private fun ToothDialog(def: ToothDef, onDismiss: () -> Unit) {
    val st = toothState(def.code)
    var pickDate by remember { mutableStateOf(LocalDate.now()) }
    val context = androidx.compose.ui.platform.LocalContext.current

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column {
                Text("${def.name}（${def.code}）", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = Palette.ink)
                Text(
                    "换牙期 ${def.windowLabel} · 当前：${st.status.label}",
                    fontSize = 12.sp, color = Palette.subtle,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        },
        text = {
            Column {
                if (st.fallenDate != null) {
                    Text(
                        "记录的脱落日期：${st.fallenDate.format(fmt)}",
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
                    Store.updateCurrent { c -> c.copy(teethFallen = (c.teethFallen ?: emptyMap()) - def.code) }
                } else {
                    Store.updateCurrent { c ->
                        c.copy(teethFallen = (c.teethFallen ?: emptyMap()) + (def.code to pickDate))
                    }
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
