package com.zsonit.mengbao.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DatePicker
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.FeedLog
import com.zsonit.mengbao.model.GrowthRecord
import com.zsonit.mengbao.ui.ChipLabel
import com.zsonit.mengbao.ui.EmptyHint
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.TopBar
import com.zsonit.mengbao.ui.cardStyle
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

// MARK: - 趋势指标定义

enum class TrendMetric(
    val key: String,
    val title: String,
    val icon: String,
    val unit: String,
) {
    SLEEP("sleep", "睡眠", "😴", "分钟"),
    MILK("milk", "奶量", "🍼", "ml"),
    DIAPER("diaper", "尿布", "🧷", "次"),
    PUMPING("pumping", "吸奶", "🧴", "ml"),
    SOLID("solid", "辅食次数", "🍚", "次"),
    TEMP("temp", "体温", "🌡️", "℃"),
    WEIGHT("weight", "体重", "⚖️", "kg"),
    HEIGHT("height", "身高", "📏", "cm"),
    HEAD_CIRC("headCirc", "头围", "🧢", "cm"),
    ;

    /** 曲线来自哪类喂养记录（体型类返回 null） */
    val feedKind: FeedLog.Kind?
        get() = when (this) {
            SLEEP -> FeedLog.Kind.SLEEP
            MILK -> FeedLog.Kind.BOTTLE
            DIAPER -> FeedLog.Kind.DIAPER
            PUMPING -> FeedLog.Kind.PUMPING
            SOLID -> FeedLog.Kind.SOLID
            TEMP -> FeedLog.Kind.TEMP
            else -> null
        }

    val color: Color
        get() = when (this) {
            SLEEP -> Color(0xFF5B7CFA)
            MILK -> Color(0xFFE2A33C)
            DIAPER -> Color(0xFF1F9D6B)
            PUMPING -> Color(0xFFB06BD6)
            SOLID -> Color(0xFFD97706)
            TEMP -> Color(0xFFE0513A)
            WEIGHT -> Color(0xFF7C5CFF)
            HEIGHT -> Color(0xFF2C8BC9)
            HEAD_CIRC -> Color(0xFF4CA6A0)
        }

    companion object {
        fun of(key: String?): TrendMetric? = entries.firstOrNull { it.key == key }
    }
}

/** date = 归属日期；at = 精确时刻（按次描点时用）；agg = 是否是当天汇总 */
data class TrendPoint(
    val date: LocalDate,
    val value: Double,
    val at: LocalDateTime? = null,
    val agg: Boolean = false,
)

/** 绘图用的横轴时间 */
fun TrendPoint.xTime(): LocalDateTime = at ?: date.atStartOfDay()

fun TrendPoint.xSec(): Long = xTime().toEpochSecond(ZoneOffset.UTC)

// MARK: - 曲线数据构建

object TrendSeries {

    /** 短周期（≤7 天）里能按「一次一条记录」描点的指标 → 时间可精确到几点几分 */
    fun perRecord(metric: TrendMetric, days: Int?): Boolean {
        if (days == null || days > 7) return false
        return when (metric) {
            TrendMetric.SLEEP, TrendMetric.MILK, TrendMetric.PUMPING,
            TrendMetric.TEMP, TrendMetric.WEIGHT, TrendMetric.HEIGHT, TrendMetric.HEAD_CIRC -> true
            // 尿布/辅食次数按次会是一条水平线，保持按天汇总
            else -> false
        }
    }

    /** days = null 表示全部历史，否则最近 N 天（含今天） */
    fun points(child: Child, metric: TrendMetric, days: Int?): List<TrendPoint> {
        val cutoff = days?.let { LocalDate.now().minusDays((it - 1).toLong()) }
        fun inRange(d: LocalDate) = cutoff?.let { !d.isBefore(it) } ?: true
        val byRecord = perRecord(metric, days)

        return when (metric) {
            TrendMetric.SLEEP, TrendMetric.MILK, TrendMetric.DIAPER, TrendMetric.PUMPING, TrendMetric.SOLID -> {
                val kind = metric.feedKind ?: return emptyList()
                if (byRecord) {
                    return child.feeds
                        .filter { it.kind == kind && inRange(it.date) }
                        .mapNotNull { f ->
                            val v = when (metric) {
                                TrendMetric.SLEEP -> (f.minutes ?: 0).toDouble()
                                else -> f.ml ?: 0.0
                            }
                            if (v <= 0) null
                            else TrendPoint(f.date, v, LocalDateTime.of(f.date, f.time ?: LocalTime.MIDNIGHT), false)
                        }
                        .sortedBy { it.xTime() }
                }
                val byDay = linkedMapOf<LocalDate, Double>()
                for (f in child.feeds) {
                    if (f.kind != kind || !inRange(f.date)) continue
                    val v = when (metric) {
                        TrendMetric.SLEEP -> (f.minutes ?: 0).toDouble()
                        TrendMetric.MILK, TrendMetric.PUMPING -> f.ml ?: 0.0
                        else -> 1.0
                    }
                    byDay[f.date] = (byDay[f.date] ?: 0.0) + v
                }
                byDay.filter { it.value > 0 }
                    .map { TrendPoint(it.key, it.value, agg = true) }
                    .sortedBy { it.date }
            }

            TrendMetric.TEMP ->
                child.feeds
                    .filter { it.kind == FeedLog.Kind.TEMP && it.value != null && inRange(it.date) }
                    .map {
                        val at = LocalDateTime.of(it.date, it.time ?: LocalTime.MIDNIGHT)
                        TrendPoint(it.date, it.value!!, at)
                    }
                    .sortedBy { it.xTime() }

            TrendMetric.WEIGHT, TrendMetric.HEIGHT, TrendMetric.HEAD_CIRC ->
                child.records
                    .filter { r -> inRange(r.date) && valueOf(metric, r) != null }
                    .map { TrendPoint(it.date, valueOf(metric, it)!!) }
                    .sortedBy { it.xTime() }
        }
    }

    private fun valueOf(metric: TrendMetric, r: GrowthRecord): Double? = when (metric) {
        TrendMetric.WEIGHT -> r.weight
        TrendMetric.HEIGHT -> r.height
        TrendMetric.HEAD_CIRC -> r.headCirc
        else -> null
    }

    /** 曲线点的合计文案 */
    fun describe(metric: TrendMetric, value: Double): String = when (metric) {
        TrendMetric.SLEEP -> {
            val h = value.toInt() / 60
            val m = value.toInt() % 60
            if (h > 0) "$h 小时 $m 分钟" else "$m 分钟"
        }
        TrendMetric.MILK, TrendMetric.PUMPING -> "${value.toInt()} ml"
        TrendMetric.DIAPER, TrendMetric.SOLID -> "${value.toInt()} 次"
        TrendMetric.TEMP -> String.format(Locale.US, "%.1f ℃", value)
        TrendMetric.WEIGHT -> String.format(Locale.US, "%.2f kg", value)
        else -> String.format(Locale.US, "%.1f cm", value)
    }
}

// MARK: - 成长趋势页

@Composable
fun TrendsScreen(onBack: () -> Unit, onOpenDay: (date: String, metric: String) -> Unit) {
    var metric by remember { mutableStateOf(TrendMetric.SLEEP) }
    var days by remember { mutableStateOf<Int?>(30) }
    val child = Store.current

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = "成长趋势", onBack = onBack)
        if (child == null) {
            EmptyHint(text = "先添加宝宝档案")
        } else {
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 28.dp)) {
                // 指标选择
                Row(
                    Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())
                        .padding(horizontal = 16.dp, vertical = 6.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    TrendMetric.entries.forEach { m ->
                        ChipLabel(text = "${m.icon} ${m.title}", selected = metric == m, onClick = { metric = m })
                    }
                }

                // 时间范围
                Row(
                    Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())
                        .padding(horizontal = 18.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    listOf(
                        "今天" to 1, "3 天" to 3, "5 天" to 5, "7 天" to 7,
                        "15 天" to 15, "30 天" to 30, "90 天" to 90, "全部" to null,
                    ).forEach { (label, d) ->
                        Text(
                            label,
                            fontSize = 12.sp,
                            fontWeight = if (days == d) FontWeight.SemiBold else FontWeight.Normal,
                            color = if (days == d) Palette.purple else Palette.subtle,
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(if (days == d) Palette.purpleSoft else Color.Transparent)
                                .clickable { days = d }
                                .padding(horizontal = 12.dp, vertical = 5.dp),
                        )
                    }
                }

                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 18.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        if (TrendSeries.perRecord(metric, days)) "按次描点 · 每个点是一个时刻"
                        else "按天汇总 · 每个点是一天的合计",
                        fontSize = 11.sp, color = Palette.subtle,
                    )
                    Spacer(Modifier.weight(1f))
                    Text("单位：${metric.unit}", fontSize = 11.5.sp, color = Palette.subtle)
                }

                // 曲线卡
                val points = remember(child.feeds.size, child.records.size, metric, days) {
                    TrendSeries.points(child, metric, days)
                }
                Column(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 8.dp).cardStyle(),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            "${metric.icon} ${metric.title}曲线",
                            fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Palette.ink,
                        )
                        Spacer(Modifier.weight(1f))
                        points.lastOrNull()?.let { last ->
                            Text(
                                "最新 ${TrendSeries.describe(metric, last.value)}",
                                fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = metric.color,
                            )
                        }
                    }
                    points.lastOrNull()?.let { last ->
                        Text(stamp(last), fontSize = 11.sp, color = Palette.subtle)
                    }

                    if (points.isEmpty()) {
                        Column(
                            Modifier.fillMaxWidth().padding(vertical = 26.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Text("这个区间这个指标还没有记录", fontSize = 13.sp, color = Palette.subtle)
                            Text(
                                "换一个时间范围，或先在首页补一条记录",
                                fontSize = 11.5.sp, color = Palette.subtle.copy(alpha = 0.8f),
                                modifier = Modifier.padding(top = 4.dp),
                            )
                        }
                    } else {
                        TrendChart(
                            points = points,
                            metric = metric,
                            modifier = Modifier.fillMaxWidth().height(250.dp),
                            onOpenDay = { date -> onOpenDay(date.toString(), metric.key) },
                        )
                    }

                    Spacer(Modifier.height(2.dp))
                    Row(
                        Modifier.fillMaxWidth().clickable {
                            onOpenDay(LocalDate.now().toString(), "all")
                        }.padding(vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("📅 按日期看历史明细", fontSize = 13.sp, fontWeight = FontWeight.Medium, color = Palette.purple)
                        Spacer(Modifier.weight(1f))
                        Text("›", fontSize = 16.sp, color = Palette.purple)
                    }
                }

                // 当日快览
                DayPeek(child, onOpenDay = { onOpenDay(LocalDate.now().toString(), "all") })
            }
        }
    }
}

private fun fmtDay(d: LocalDate): String = "${d.year}年${d.monthValue}月${d.dayOfMonth}日"

private val FMT_HM: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm")
private val FMT_MD_HM: DateTimeFormatter = DateTimeFormatter.ofPattern("M/d\nHH:mm")
private val FMT_MD: DateTimeFormatter = DateTimeFormatter.ofPattern("M月d日")
private val FMT_YM: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy年M月")
private val FMT_FULL: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy年M月d日")
private val FMT_FULL_HM: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy年M月d日 HH:mm")

/** 曲线点的完整时间：精确到年/月/日/时/分 */
private fun stamp(p: TrendPoint): String {
    if (p.agg) return p.date.format(FMT_FULL) + " 全天"
    val t = p.xTime()
    return if (t.hour == 0 && t.minute == 0) t.format(FMT_FULL) else t.format(FMT_FULL_HM)
}

/** 横轴刻度：跨度越长越粗 */
private fun axisLabel(t: LocalDateTime, spanDays: Long): String = when {
    spanDays <= 1 -> t.format(FMT_HM)
    spanDays <= 10 -> t.format(FMT_MD_HM)
    spanDays <= 400 -> t.format(FMT_MD)
    else -> t.format(FMT_YM)
}

@Composable
private fun DayPeek(child: Child, onOpenDay: () -> Unit) {
    val today = LocalDate.now()
    val feeds = child.feeds.filter { it.date == today }
    fun sum(pred: (FeedLog) -> Boolean, v: (FeedLog) -> Double) = feeds.filter(pred).sumOf { v(it) }
    fun cnt(pred: (FeedLog) -> Boolean) = feeds.count(pred)
    val text = buildString {
        append("😴 睡眠 ${sum({ it.kind == FeedLog.Kind.SLEEP }) { (it.minutes ?: 0).toDouble() }.toInt()} 分钟　")
        append("🍼 奶量 ${sum({ it.kind == FeedLog.Kind.BOTTLE }) { it.ml ?: 0.0 }.toInt()} ml　")
        append("🧷 尿布 ${cnt { it.kind == FeedLog.Kind.DIAPER }} 次　")
        append("🧴 吸奶 ${sum({ it.kind == FeedLog.Kind.PUMPING }) { it.ml ?: 0.0 }.toInt()} ml　")
        append("🍚 辅食 ${cnt { it.kind == FeedLog.Kind.SOLID }} 次")
    }
    Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 12.dp).cardStyle()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("今天 · ${fmtDay(today)}", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
            Spacer(Modifier.weight(1f))
            Text(
                "全天明细 ›",
                fontSize = 12.sp, color = Palette.purple,
                modifier = Modifier.clickable { onOpenDay() }.padding(4.dp),
            )
        }
        Text(text, fontSize = 12.sp, color = Palette.ink2, modifier = Modifier.padding(top = 6.dp))
    }
}

// MARK: - 折线图（自绘）

@Composable
private fun TrendChart(
    points: List<TrendPoint>,
    metric: TrendMetric,
    modifier: Modifier = Modifier,
    onOpenDay: (LocalDate) -> Unit = {},
) {
    var selected by remember(points) { mutableStateOf<TrendPoint?>(null) }
    val measurer = rememberTextMeasurer()
    // Canvas 绘制作用域里不能调用 @Composable 的 Palette，先在这里取好
    val hairline = Palette.hairline
    val subtleC = Palette.subtle
    val cardC = Palette.card

    val spanDays = if (points.size > 1) {
        (points.last().xSec() - points.first().xSec()) / 86400L
    } else 0L

    Column(modifier) {
        Box(Modifier.fillMaxWidth().weight(1f)) {
            Canvas(
                Modifier.fillMaxSize().pointerInput(points) {
                    detectTapGestures { pos ->
                        if (points.isEmpty()) return@detectTapGestures
                        val padL = 44.dp.toPx()
                        val right = size.width.toFloat() - 14.dp.toPx()
                        val xs = points.map { xPos(it, points, padL, right) }
                        var best = 0
                        var bestD = Float.MAX_VALUE
                        xs.forEachIndexed { i, x ->
                            val d = abs(x - pos.x)
                            if (d < bestD) { bestD = d; best = i }
                        }
                        selected = if (bestD <= 48.dp.toPx()) points[best] else null
                    }
                },
            ) {
                val w = size.width
                val h = size.height
                val padL = 44.dp.toPx()
                val padR = 14.dp.toPx()
                val padT = 12.dp.toPx()
                val padB = 38.dp.toPx()
                val chartW = w - padL - padR
                val chartH = h - padT - padB

                val values = points.map { it.value }
                var vmin = values.min()
                var vmax = values.max()
                if (vmin == vmax) {
                    val pad = (abs(vmin) * 0.12).coerceAtLeast(1.0)
                    vmin -= pad; vmax += pad
                }
                val span = vmax - vmin
                vmin -= span * 0.10
                vmax += span * 0.10

                fun yPos(v: Double): Float = (padT + chartH * (1 - (v - vmin) / (vmax - vmin))).toFloat()
                fun xOf(p: TrendPoint): Float = xPos(p, points, padL, w - padR)

                // 横向网格 + Y 轴标签
                val yLabelStyle = TextStyle(fontSize = 9.5.sp, color = subtleC)
                for (i in 0..2) {
                    val v = vmin + (vmax - vmin) * i / 2.0
                    val y = yPos(v)
                    drawLine(hairline, Offset(padL, y), Offset(w - padR, y), 1f)
                    val label = labelFor(metric, v)
                    val laid = measurer.measure(label, yLabelStyle)
                    drawText(laid, topLeft = Offset(0.dp.toPx(), (y - laid.size.height / 2).coerceAtLeast(0f)))
                }

                // X 轴时间标签（首 / 中 / 尾，含年月日/时分）
                val xLabelStyle = TextStyle(fontSize = 9.5.sp, color = subtleC)
                listOf(0, (points.size - 1) / 2, points.size - 1).distinct().forEach { idx ->
                    val p = points[idx]
                    val laid = measurer.measure(axisLabel(p.xTime(), spanDays), xLabelStyle)
                    val x = xOf(p)
                    drawText(
                        laid,
                        topLeft = Offset(
                            (x - laid.size.width / 2).coerceIn(0f, w - laid.size.width),
                            h - padB + 6.dp.toPx(),
                        ),
                    )
                }

                // 折线（至少两个点才连）
                if (points.size > 1) {
                    val path = Path()
                    points.forEachIndexed { i, p ->
                        val x = xOf(p)
                        val y = yPos(p.value)
                        if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
                    }
                    drawPath(
                        path, metric.color,
                        style = Stroke(width = 2.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round),
                    )
                }

                // 数据点
                points.forEach { p ->
                    val x = xOf(p)
                    val y = yPos(p.value)
                    drawCircle(metric.color, 3.4.dp.toPx(), Offset(x, y))
                    drawCircle(cardC, 1.4.dp.toPx(), Offset(x, y))
                }

                // 选中点高亮 + 数值气泡
                selected?.let { sel ->
                    val x = xOf(sel)
                    val y = yPos(sel.value)
                    drawCircle(metric.color.copy(alpha = 0.18f), 11.dp.toPx(), Offset(x, y))
                    drawCircle(metric.color, 5.dp.toPx(), Offset(x, y))
                    drawCircle(cardC, 2.dp.toPx(), Offset(x, y))
                    val text = "${compactStamp(sel)}  ${TrendSeries.describe(metric, sel.value)}"
                    val laid = measurer.measure(text, TextStyle(fontSize = 10.5.sp, color = Color.White))
                    val bw = laid.size.width + 20.dp.toPx()
                    val bh = laid.size.height + 10.dp.toPx()
                    val bx = (x - bw / 2).coerceIn(padL, (w - padR - bw).coerceAtLeast(padL))
                    val by = (y - bh - 10.dp.toPx()).coerceAtLeast(2f)
                    drawRoundRect(
                        metric.color.copy(alpha = 0.92f),
                        Offset(bx, by),
                        androidx.compose.ui.geometry.Size(bw, bh),
                        androidx.compose.ui.geometry.CornerRadius(8.dp.toPx()),
                    )
                    drawText(laid, topLeft = Offset(bx + 10.dp.toPx(), by + 5.dp.toPx()))
                }
            }
        }

        // 选中信息（精确到年月日时分）+ 跳当日明细
        selected?.let { sel ->
            Column(
                Modifier.fillMaxWidth().padding(top = 6.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(Palette.purpleTint)
                    .padding(horizontal = 11.dp, vertical = 8.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        "${metric.icon} ${stamp(sel)}",
                        fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink,
                    )
                    Spacer(Modifier.weight(1f))
                    Text(TrendSeries.describe(metric, sel.value), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = metric.color)
                }
                Text(
                    "查看这天的明细 ›",
                    fontSize = 12.sp, color = Palette.purple,
                    modifier = Modifier
                        .clickable { onOpenDay(sel.date) }
                        .padding(top = 4.dp),
                )
            }
        }
    }
}

/** 气泡里的短标签：今天只写时刻，其它带月日 */
private fun compactStamp(p: TrendPoint): String {
    val t = p.xTime()
    val isToday = t.toLocalDate() == LocalDate.now()
    return when {
        p.agg -> "${t.monthValue}/${t.dayOfMonth} 全天"
        isToday -> t.format(FMT_HM)
        else -> t.format(DateTimeFormatter.ofPattern("M/d HH:mm"))
    }
}

private fun xPos(p: TrendPoint, points: List<TrendPoint>, padL: Float, right: Float): Float {
    val chartW = right - padL
    val s0 = points.first().xSec().toFloat()
    val s1 = points.last().xSec().toFloat()
    val s = p.xSec().toFloat()
    val t = if (s1 == s0) 0.5f else (s - s0) / (s1 - s0)
    return padL + chartW * t
}

private fun labelFor(metric: TrendMetric, v: Double): String = when (metric) {
    TrendMetric.TEMP -> String.format(Locale.US, "%.1f", v)
    TrendMetric.WEIGHT -> String.format(Locale.US, "%.1f", v)
    else -> if (v >= 100) v.roundToInt().toString() else String.format(Locale.US, "%.1f", v)
}

// MARK: - 当日明细（精确到几点几分）

private data class DayEntry(
    val id: String,
    val time: LocalTime?,
    val icon: String,
    val title: String,
    val detail: String,
    val note: String,
    val metric: TrendMetric?,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DayHistoryScreen(
    initialDate: String,
    initialMetric: String,
    onBack: () -> Unit,
) {
    var day by remember {
        mutableStateOf(runCatching { LocalDate.parse(initialDate) }.getOrDefault(LocalDate.now()))
    }
    var filter by remember { mutableStateOf(TrendMetric.of(initialMetric)) }
    var showPicker by remember { mutableStateOf(false) }
    val child = Store.current
    val timeFmt = DateTimeFormatter.ofPattern("HH:mm")

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = "当日明细", onBack = onBack)
        if (child == null) {
            EmptyHint(text = "先添加宝宝档案")
        } else {
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 28.dp)) {
                // 日期导航
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        "‹",
                        fontSize = 18.sp, color = Palette.purple, textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                        modifier = Modifier
                            .size(34.dp)
                            .clip(CircleShape)
                            .background(Palette.purpleTint)
                            .clickable { day = day.minusDays(1) }
                            .padding(vertical = 4.dp),
                    )
                    Row(
                        Modifier.weight(1f).clip(RoundedCornerShape(12.dp))
                            .background(Palette.purpleTint)
                            .clickable { showPicker = true }
                            .padding(vertical = 9.dp),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            "${day.year} 年 ${day.monthValue} 月 ${day.dayOfMonth} 日 · ${day.dayOfWeek.value.let { dow -> listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")[(dow + 6) % 7] }}",
                            fontSize = 13.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple,
                        )
                    }
                    val isToday = !day.isBefore(LocalDate.now())
                    Text(
                        "›",
                        fontSize = 18.sp,
                        color = if (isToday) Palette.hairline else Palette.purple,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                        modifier = Modifier
                            .size(34.dp)
                            .clip(CircleShape)
                            .background(if (isToday) Palette.hairlineSoft else Palette.purpleTint)
                            .clickable(enabled = !isToday) { day = day.plusDays(1) }
                            .padding(vertical = 4.dp),
                    )
                }

                // 指标筛选
                Row(
                    Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())
                        .padding(horizontal = 16.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    ChipLabel(text = "全部", selected = filter == null, onClick = { filter = null })
                    TrendMetric.entries.forEach { m ->
                        ChipLabel(text = "${m.icon} ${m.title}", selected = filter == m, onClick = { filter = m })
                    }
                }

                // 明细列表
                val entries = remember(child.feeds.size, child.records.size, day) { buildEntries(child, day) }
                val visible = filter?.let { f -> entries.filter { it.metric == f } } ?: entries
                if (visible.isEmpty()) {
                    Column(
                        Modifier.fillMaxWidth().padding(vertical = 40.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text("这天没有相关记录", fontSize = 13.5.sp, color = Palette.subtle)
                        Text(
                            "在首页点「＋」或语音说一句就能补记",
                            fontSize = 12.sp, color = Palette.subtle.copy(alpha = 0.8f),
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                } else {
                    Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 8.dp).cardStyle(padding = 14.dp)) {
                        visible.forEachIndexed { idx, e ->
                            if (idx > 0) {
                                Box(
                                    Modifier.fillMaxWidth().padding(vertical = 2.dp)
                                        .height(1.dp).background(Palette.hairlineSoft),
                                )
                            }
                            Row(Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
                                Text(e.icon, fontSize = 17.sp)
                                Spacer(Modifier.width(11.dp))
                                Column(Modifier.weight(1f)) {
                                    Text(e.title, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Palette.ink)
                                    Text(e.detail, fontSize = 12.5.sp, color = Palette.ink2, modifier = Modifier.padding(top = 1.dp))
                                    if (e.note.isNotBlank()) {
                                        Text("📝 ${e.note}", fontSize = 12.sp, color = Palette.subtle, modifier = Modifier.padding(top = 1.dp))
                                    }
                                }
                                Text(
                                    e.time?.format(timeFmt) ?: "全天",
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = if (e.time == null) Palette.subtle else Palette.purple,
                                )
                            }
                        }
                    }
                }

                Text(
                    "共 ${visible.size} 条 · 睡眠/奶量/尿布/吸奶/辅食/体温来自喂养记录，体重/身高/头围来自生长测量",
                    fontSize = 11.sp, color = Palette.subtle,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp),
                )
            }
        }
    }

    if (showPicker) {
        val millis = day.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
        val state = androidx.compose.material3.rememberDatePickerState(initialSelectedDateMillis = millis)
        DatePickerDialog(
            onDismissRequest = { showPicker = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let {
                        day = Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()
                    }
                    showPicker = false
                }) { Text("确定") }
            },
            dismissButton = { TextButton(onClick = { showPicker = false }) { Text("取消") } },
        ) {
            DatePicker(state = state)
        }
    }
}

private fun buildEntries(child: Child, day: LocalDate): List<DayEntry> {
    val list = mutableListOf<DayEntry>()

    for (f in child.feeds) {
        if (f.date != day) continue
        val metric: TrendMetric?
        val title: String
        val detail: String
        when (f.kind) {
            FeedLog.Kind.SLEEP -> { metric = TrendMetric.SLEEP; title = "睡眠"; detail = "${f.minutes ?: 0} 分钟" }
            FeedLog.Kind.BOTTLE -> { metric = TrendMetric.MILK; title = "瓶喂"; detail = "${(f.ml ?: 0.0).toInt()} ml" }
            FeedLog.Kind.BREAST -> { metric = null; title = "亲喂"; detail = "${f.side ?: "左"}侧 · ${f.minutes ?: 0} 分钟" }
            FeedLog.Kind.PUMPING -> { metric = TrendMetric.PUMPING; title = "吸奶"; detail = "${(f.ml ?: 0.0).toInt()} ml" }
            FeedLog.Kind.DIAPER -> { metric = TrendMetric.DIAPER; title = "尿布"; detail = f.diaperKind ?: "小便" }
            FeedLog.Kind.SOLID -> { metric = TrendMetric.SOLID; title = "辅食"; detail = f.note.ifEmpty { "已添加" } }
            FeedLog.Kind.TEMP -> { metric = TrendMetric.TEMP; title = "体温"; detail = String.format(Locale.US, "%.1f ℃", f.value ?: 0.0) }
            FeedLog.Kind.SUPPLEMENT -> { metric = null; title = "补剂"; detail = f.note.ifEmpty { "已服用" } }
            FeedLog.Kind.CUSTOM -> { metric = null; title = "记录"; detail = f.note.ifEmpty { "—" } }
        }
        list.add(
            DayEntry(
                id = "f-${f.id}", time = f.time, icon = f.kind.icon,
                title = title, detail = detail, note = f.note, metric = metric,
            ),
        )
    }

    for (r in child.records) {
        if (r.date != day) continue
        r.height?.let {
            list.add(DayEntry("r-h-${r.id}", null, "📏", "身高测量", String.format(Locale.US, "%.1f cm", it), r.note, TrendMetric.HEIGHT))
        }
        r.weight?.let {
            list.add(DayEntry("r-w-${r.id}", null, "⚖️", "体重测量", String.format(Locale.US, "%.2f kg", it), r.note, TrendMetric.WEIGHT))
        }
        r.headCirc?.let {
            list.add(DayEntry("r-hc-${r.id}", null, "🧢", "头围测量", String.format(Locale.US, "%.1f cm", it), r.note, TrendMetric.HEAD_CIRC))
        }
        if (r.footLength != null && r.height == null && r.weight == null && r.headCirc == null) {
            list.add(DayEntry("r-fl-${r.id}", null, "📝", "生长测量", "脚长 ${String.format(Locale.US, "%.1f", r.footLength!!)} cm", r.note, null))
        }
    }

    return list.sortedWith(
        compareBy<DayEntry> { it.time == null }
            .thenBy { it.time ?: LocalTime.MIDNIGHT },
    )
}
