package com.zsonit.mengbao.ui.screens

import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
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
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zsonit.mengbao.data.Evaluation
import com.zsonit.mengbao.data.GrowthMath
import com.zsonit.mengbao.data.GrowthMetric
import com.zsonit.mengbao.data.LevelTone
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.GrowthRecord
import com.zsonit.mengbao.model.SizeRecord
import com.zsonit.mengbao.model.TodoItem
import com.zsonit.mengbao.ui.ChipLabel
import com.zsonit.mengbao.ui.DateField
import com.zsonit.mengbao.ui.DividerLine
import com.zsonit.mengbao.ui.EmptyHint
import com.zsonit.mengbao.ui.HintBlock
import com.zsonit.mengbao.ui.KVRow
import com.zsonit.mengbao.ui.NumberInput
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.PrimaryButton
import com.zsonit.mengbao.ui.SectionHeader
import com.zsonit.mengbao.ui.TagTone
import com.zsonit.mengbao.ui.TagView
import com.zsonit.mengbao.ui.TextInput
import com.zsonit.mengbao.ui.TopBar
import com.zsonit.mengbao.ui.cardStyle
import java.time.LocalDate
import java.util.Locale
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt

// MARK: - 生长曲线详情

@Composable
fun GrowthDetailScreen(onBack: () -> Unit) {
    var metric by remember { mutableStateOf(GrowthMetric.HEIGHT) }
    var editorOpen by remember { mutableStateOf(false) }
    var editingId by remember { mutableStateOf<String?>(null) }
    var sizeOpen by remember { mutableStateOf(false) }
    var todoOpen by remember { mutableStateOf(false) }
    var stageOpen by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()

    when {
        editorOpen -> RecordEditorScreen(
            recordId = editingId,
            onBack = {
                editorOpen = false
                editingId = null
            },
        )

        sizeOpen -> SizeEditorScreen(onBack = { sizeOpen = false })
        todoOpen -> TodoEditorScreen(onBack = { todoOpen = false })
        stageOpen -> StageScreen(onBack = { stageOpen = false })

        else -> {
            val child = Store.current
            Column(Modifier.fillMaxSize().background(Palette.background)) {
                TopBar(title = "生长曲线", onBack = onBack)
                if (child == null) {
                    EmptyHint(text = "先添加宝宝档案")
                } else {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = 8.dp),
                    ) {
                        item { ChartCard(child, metric) { metric = it } }
                        item { EvaluationSection(child) }
                        item { VelocitySection(child) }
                        item { PredictionSection(child) }
                        item {
                            RecordSection(
                                child = child,
                                onNew = {
                                    editingId = null
                                    editorOpen = true
                                },
                                onEdit = { record ->
                                    editingId = record.id
                                    editorOpen = true
                                },
                            )
                        }
                        item {
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp),
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                ChipLabel(text = "👟 鞋服尺码", onClick = { sizeOpen = true })
                                ChipLabel(text = "📋 待办", onClick = { todoOpen = true })
                                ChipLabel(text = "⭐ 阶段重点", onClick = { stageOpen = true })
                            }
                        }
                        item {
                            HintBlock(
                                text = "参考带按性别与月龄逐点计算：0–5 岁用 WHO 标准（LMS 法），5–7 岁用中国 7 岁以下参照标准中位数，7–18 岁用 WS/T 423 等级评价表。测量方式（脱鞋、同一台秤、晨起空腹）对曲线影响很大，看趋势比看单点更重要。",
                                modifier = Modifier.padding(horizontal = 16.dp).padding(top = 4.dp, bottom = 28.dp),
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: 曲线卡

@Composable
private fun ChartCard(child: Child, metric: GrowthMetric, onMetric: (GrowthMetric) -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(top = 12.dp)
            .cardStyle(),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "${metric.label}曲线",
                fontSize = 15.5.sp,
                fontWeight = FontWeight.Bold,
                color = Palette.ink,
            )
            Spacer(Modifier.weight(1f))
            Text(GrowthMath.ageText(child.birthDate), fontSize = 12.sp, color = Palette.subtle)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GrowthMetric.entries.forEach { m ->
                ChipLabel(text = m.label, selected = metric == m, onClick = { onMetric(m) })
            }
        }
        GrowthChart(
            child = child,
            metric = metric,
            modifier = Modifier
                .fillMaxWidth()
                .height(236.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(Palette.card),
        )
        Row(
            modifier = Modifier.padding(top = 2.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Legend(color = Color(0xFFE0513A), dash = true, text = "P3 / P97")
            Legend(color = Color(0xFFE2A33C), dash = true, text = "P15 / P85")
            Legend(color = Palette.purple, dash = false, text = "P50")
            Legend(color = Palette.ok, dash = false, text = "实测")
        }
    }
}

@Composable
private fun Legend(color: Color, dash: Boolean, text: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(
            Modifier
                .width(14.dp)
                .height(if (dash) 1.4.dp else 2.2.dp)
                .background(color.copy(alpha = if (dash) 0.85f else 1f)),
        )
        Text(text, fontSize = 10.5.sp, color = Palette.subtle)
    }
}

// MARK: 评估

@Composable
private fun EvaluationSection(child: Child) {
    val last = child.latestRecord
    val evaluation = last?.let { GrowthMath.evaluate(child, it) }
    if (last == null || evaluation == null) {
        EmptyHint(text = "录入 1 条以上测量数据后显示评估")
        return
    }
    val shape = RoundedCornerShape(18.dp)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(top = 12.dp)
            .clip(shape)
            .background(
                Brush.linearGradient(
                    listOf(Palette.purpleSoft, Palette.purpleTint),
                    start = Offset.Zero,
                    end = Offset(800f, 600f),
                ),
            )
            .border(1.dp, Palette.purple.copy(alpha = 0.22f), shape)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            "身高 ${GrowthMath.percentileLabel(evaluation.heightPercentile ?: 50.0)} · ${evaluation.heightLevel?.label ?: ""}",
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            color = Palette.purple,
        )
        Text(
            detailText(child, last, evaluation),
            fontSize = 13.sp,
            color = Palette.ink2,
            lineHeight = 19.sp,
        )
    }
}

private fun detailText(child: Child, record: GrowthRecord, evaluation: Evaluation): String {
    val parts = mutableListOf<String>()
    val h = record.height
    val hp = evaluation.heightPercentile
    if (h != null && hp != null) {
        parts.add("${GrowthMath.dateString(record.date)} 测 ${fmt1(h)}cm，超过同龄 ${hp.roundToInt()}% 的孩子。")
    }
    val level = evaluation.heightLevel
    if (level != null && level.tone != LevelTone.OK) parts.add(level.desc)
    val wp = evaluation.weightPercentile
    val bmi = evaluation.bmi
    if (wp != null && bmi != null) {
        parts.add("体重 ${GrowthMath.percentileLabel(wp)}，BMI ${fmt1(bmi)}（${GrowthMath.percentileLabel(evaluation.bmiPercentile ?: 50.0)}）。")
    }
    parts.add("参考：${evaluation.source}。")
    return parts.joinToString("\n")
}

// MARK: 速度

@Composable
private fun VelocitySection(child: Child) {
    val velocity = GrowthMath.velocity(child)
    Column(Modifier.fillMaxWidth()) {
        SectionHeader(title = "变化与速度")
        Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle()) {
            KVRow(
                key = "最近一次增长",
                value = velocity?.let { String.format(Locale.US, "%+.1f cm / %d 天", it.delta, it.days) } ?: "—",
            )
            DividerLine(Palette.hairlineSoft)
            KVRow(
                key = "年化生长速度",
                value = velocity?.let { String.format(Locale.US, "%.1f cm/年", it.perYear) } ?: "—",
            )
            DividerLine(Palette.hairlineSoft)
            KVRow(
                key = "速度评价",
                value = velocity?.let { GrowthMath.velocityComment(child, it.perYear) } ?: "数据不足",
            )
        }
    }
}

// MARK: 身高预测

@Composable
private fun PredictionSection(child: Child) {
    val settings = Store.settings
    val prediction = child.latestRecord?.let { GrowthMath.predictedHeight(child, it, settings) }
    val father = settings.fatherHeight
    val mother = settings.motherHeight
    Column(Modifier.fillMaxWidth()) {
        SectionHeader(title = "18 岁身高预测")
        Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle()) {
            KVRow(
                key = "预测值",
                value = prediction?.let {
                    "${it.value.roundToInt()} cm（${it.low.roundToInt()}–${it.high.roundToInt()}）"
                } ?: "需先记录身高",
                valueColor = Palette.purple,
            )
            DividerLine(Palette.hairlineSoft)
            KVRow(key = "预测方法", value = prediction?.method ?: "—")
            DividerLine(Palette.hairlineSoft)
            KVRow(
                key = "父母身高",
                value = if (father != null && mother != null) {
                    "${father.toInt()} / ${mother.toInt()} cm"
                } else {
                    "未填写（在「我的」中补全）"
                },
            )
            Text(
                "预测误差约 ±5cm，仅作趋势参考。青春期发育节奏个体差异大，不建议据此做任何医疗决策。",
                fontSize = 12.sp,
                color = Palette.subtle,
                lineHeight = 18.sp,
                modifier = Modifier.padding(top = 10.dp),
            )
        }
    }
}

// MARK: 记录列表

@Composable
private fun RecordSection(child: Child, onNew: () -> Unit, onEdit: (GrowthRecord) -> Unit) {
    Column(Modifier.fillMaxWidth()) {
        SectionHeader(title = "测量记录", trailing = "新增", onAction = onNew)
        val records = child.sortedRecords.reversed()
        if (records.isEmpty()) {
            EmptyHint(text = "还没有记录，点「新增」开始")
        } else {
            records.forEach { record ->
                RecordMini(
                    child = child,
                    record = record,
                    modifier = Modifier.padding(horizontal = 16.dp).padding(bottom = 10.dp),
                    onClick = { onEdit(record) },
                )
            }
        }
    }
}

@Composable
private fun RecordMini(child: Child, record: GrowthRecord, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val evaluation = GrowthMath.evaluate(child, record)
    val weightUnit = Store.settings.weightUnit
    val shape = RoundedCornerShape(18.dp)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Palette.card)
            .border(1.dp, Palette.hairline, shape)
            .clickable { onClick() }
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                GrowthMath.dateString(record.date),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = Palette.ink2,
            )
            Spacer(Modifier.width(8.dp))
            Text(
                GrowthMath.ageText(child.birthDate, record.date),
                fontSize = 12.sp,
                color = Palette.subtle,
            )
            Spacer(Modifier.weight(1f))
            val p = evaluation.heightPercentile
            if (p != null) {
                val tone = when (evaluation.heightLevel?.tone) {
                    LevelTone.BAD -> TagTone.BAD
                    LevelTone.WARN -> TagTone.WARN
                    else -> TagTone.OK
                }
                TagView(text = GrowthMath.percentileLabel(p), tone = tone)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MiniValue(
                value = record.height?.let { fmt1(it) } ?: "—",
                unit = "身高cm",
                modifier = Modifier.weight(1f),
            )
            MiniValue(
                value = record.weight?.let { fmt1(if (weightUnit == "斤") it * 2 else it) } ?: "—",
                unit = "体重$weightUnit",
                modifier = Modifier.weight(1f),
            )
            MiniValue(
                value = evaluation.bmi?.let { fmt1(it) } ?: "—",
                unit = "BMI",
                modifier = Modifier.weight(1f),
            )
            MiniValue(
                value = record.footLength?.let { String.format(Locale.US, "%.0f", it) } ?: "—",
                unit = "脚长cm",
                modifier = Modifier.weight(1f),
            )
        }
        if (record.note.isNotEmpty()) {
            Text(record.note, fontSize = 12.sp, color = Palette.subtle)
        }
    }
}

@Composable
private fun MiniValue(value: String, unit: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Palette.purpleTint)
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(1.dp),
    ) {
        Text(value, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Palette.ink)
        Text(unit, fontSize = 10.5.sp, color = Palette.subtle)
    }
}

// MARK: - 生长曲线（Canvas 百分位带 + 实测折线）

private data class ChartPoint(val month: Int, val value: Double)

private data class LineSpec(val index: Int, val color: Color, val dash: FloatArray?, val width: Float)

private fun chartPoints(child: Child, metric: GrowthMetric): List<ChartPoint> =
    child.sortedRecords.mapNotNull { record ->
        val months = GrowthMath.ageMonths(child.birthDate, record.date)
        when (metric) {
            GrowthMetric.HEIGHT -> record.height?.let { ChartPoint(months, it) }
            GrowthMetric.WEIGHT -> record.weight?.let { ChartPoint(months, it) }
            GrowthMetric.BMI -> {
                val h = record.height
                val w = record.weight
                if (h != null && w != null) ChartPoint(months, GrowthMath.bmiValue(h, w)) else null
            }
        }
    }

@Composable
private fun GrowthChart(child: Child, metric: GrowthMetric, modifier: Modifier = Modifier) {
    val tickStyle = TextStyle(fontSize = 9.sp, color = Palette.subtle)
    val measurer = rememberTextMeasurer()
    val gridColor = Palette.hairline
    val purpleColor = Palette.purple
    val okColor = Palette.ok
    val cardColor = Palette.card
    val redLine = Color(0xFFE0513A)
    val amberLine = Color(0xFFE2A33C)
    val points = remember(child.records, child.birthDate, metric) { chartPoints(child, metric) }

    Canvas(modifier) {
        val padLeft = 34.dp.toPx()
        val padRight = 14.dp.toPx()
        val padTop = 16.dp.toPx()
        val padBottom = 26.dp.toPx()
        val plotW = size.width - padLeft - padRight
        val plotH = size.height - padTop - padBottom
        if (plotW <= 10f || plotH <= 10f) return@Canvas

        val latestMonth = points.maxOfOrNull { it.month } ?: 0
        val maxMonth = max(36, min(216, latestMonth + 6))

        var low = Double.MAX_VALUE
        var high = -Double.MAX_VALUE
        var m = 0
        while (m <= maxMonth) {
            val band = GrowthMath.refBands(child.sex, metric, m)
            low = min(low, band[0])
            high = max(high, band[4])
            m += 3
        }
        for (p in points) {
            low = min(low, p.value)
            high = max(high, p.value)
        }
        if (!low.isFinite() || !high.isFinite()) return@Canvas

        // 纵向范围取整
        val span = max(1.0, high - low)
        val step = 10.0.pow(floor(log10(span))) / 2.0
        val yMin = floor(low * 0.96 / step) * step
        val yMax = ceil(high * 1.02 / step) * step
        if (yMax <= yMin) return@Canvas

        fun xOf(month: Int): Float = padLeft + month.toFloat() / maxMonth.toFloat() * plotW
        fun yOf(value: Double): Float =
            padTop + plotH - ((value - yMin) / (yMax - yMin)).toFloat() * plotH

        // 网格
        var tickStep = 6
        if (maxMonth > 36) tickStep = 12
        if (maxMonth > 84) tickStep = 24
        var tick = 0
        while (tick <= maxMonth) {
            drawLine(gridColor, Offset(xOf(tick), padTop), Offset(xOf(tick), padTop + plotH), 1.dp.toPx())
            val label = if (tick == 0) "0" else if (tick % 12 == 0) "${tick / 12}岁" else "${tick}月"
            val layout = measurer.measure(AnnotatedString(label), style = tickStyle)
            drawText(
                textLayoutResult = layout,
                topLeft = Offset(
                    xOf(tick) - layout.size.width / 2f,
                    size.height - 8.dp.toPx() - layout.size.height,
                ),
            )
            tick += tickStep
        }

        var yTick = yMin
        val yTickStep = (yMax - yMin) / 4
        var guard = 0
        while (yTick <= yMax + 0.0001 && guard < 64) {
            val y = yOf(yTick)
            drawLine(gridColor, Offset(padLeft, y), Offset(size.width - padRight, y), 1.dp.toPx())
            val label = if (metric == GrowthMetric.HEIGHT) "${yTick.roundToInt()}" else fmt1(yTick)
            val layout = measurer.measure(AnnotatedString(label), style = tickStyle)
            drawText(
                textLayoutResult = layout,
                topLeft = Offset(padLeft - 6.dp.toPx() - layout.size.width, y - layout.size.height / 2f),
            )
            yTick += yTickStep
            guard++
        }

        // 百分位带
        fun bandPath(lowerIndex: Int, upperIndex: Int): Path {
            val path = Path()
            var first = true
            var month = 0
            while (month <= maxMonth) {
                val v = GrowthMath.refBands(child.sex, metric, month)[upperIndex]
                val px = xOf(month)
                val py = yOf(v)
                if (first) {
                    path.moveTo(px, py)
                    first = false
                } else {
                    path.lineTo(px, py)
                }
                month += 3
            }
            var back = maxMonth - (maxMonth % 3)
            while (back >= 0) {
                val v = GrowthMath.refBands(child.sex, metric, back)[lowerIndex]
                path.lineTo(xOf(back), yOf(v))
                back -= 3
            }
            path.close()
            return path
        }

        drawPath(bandPath(0, 4), purpleColor.copy(alpha = 0.07f))
        drawPath(bandPath(1, 3), purpleColor.copy(alpha = 0.12f))

        // 百分位线
        val dashFine = floatArrayOf(5.dp.toPx(), 4.dp.toPx())
        val dashSoft = floatArrayOf(4.dp.toPx(), 3.dp.toPx())
        val specs = listOf(
            LineSpec(0, redLine, dashFine, 1.2f),
            LineSpec(1, amberLine, dashSoft, 1.2f),
            LineSpec(2, purpleColor, null, 2f),
            LineSpec(3, amberLine, dashSoft, 1.2f),
            LineSpec(4, redLine, dashFine, 1.2f),
        )
        for (spec in specs) {
            val path = Path()
            var month = 0
            var first = true
            while (month <= maxMonth) {
                val v = GrowthMath.refBands(child.sex, metric, month)[spec.index]
                val px = xOf(month)
                val py = yOf(v)
                if (first) {
                    path.moveTo(px, py)
                    first = false
                } else {
                    path.lineTo(px, py)
                }
                month += 3
            }
            drawPath(
                path = path,
                color = spec.color,
                style = Stroke(
                    width = spec.width.dp.toPx(),
                    pathEffect = spec.dash?.let { PathEffect.dashPathEffect(it) },
                ),
            )
        }

        // 实测折线
        val sorted = points.sortedBy { it.month }
        if (sorted.size > 1) {
            val path = Path()
            sorted.forEachIndexed { index, p ->
                val px = xOf(p.month)
                val py = yOf(p.value)
                if (index == 0) path.moveTo(px, py) else path.lineTo(px, py)
            }
            drawPath(
                path = path,
                color = okColor,
                style = Stroke(width = 2.4.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round),
            )
        }
        for (p in sorted) {
            val center = Offset(xOf(p.month), yOf(p.value))
            drawCircle(cardColor, radius = 4.dp.toPx(), center = center)
            drawCircle(okColor, radius = 4.dp.toPx(), center = center, style = Stroke(width = 2.2.dp.toPx()))
        }

        // 末点标注
        val last = sorted.lastOrNull()
        if (last != null) {
            val text = if (metric == GrowthMetric.HEIGHT) {
                "${last.value.roundToInt()}cm"
            } else {
                String.format(Locale.US, "%.1f%s", last.value, metric.unit)
            }
            val layout = measurer.measure(
                AnnotatedString(text),
                style = TextStyle(fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = Color.White),
            )
            val boxWidth = (if (metric == GrowthMetric.HEIGHT) 46.dp else 44.dp).toPx()
            val boxHeight = 17.dp.toPx()
            val center = Offset(xOf(last.month), yOf(last.value))
            var bx = center.x + 9.dp.toPx()
            if (bx + boxWidth > size.width - padRight) bx = center.x - boxWidth - 9.dp.toPx()
            val by = max(padTop, center.y - 26.dp.toPx())
            drawRoundRect(
                color = okColor.copy(alpha = 0.95f),
                topLeft = Offset(bx, by),
                size = Size(boxWidth, boxHeight),
                cornerRadius = CornerRadius(8.5.dp.toPx()),
            )
            drawText(
                textLayoutResult = layout,
                topLeft = Offset(
                    bx + (boxWidth - layout.size.width) / 2f,
                    by + (boxHeight - layout.size.height) / 2f,
                ),
            )
        }
    }
}

// MARK: - 记录编辑

@Composable
fun RecordEditorScreen(recordId: String?, onBack: () -> Unit) {
    val child = Store.current
    val existing = remember(recordId) {
        recordId?.let { id -> child?.records?.firstOrNull { it.id == id } }
    }
    var date by remember { mutableStateOf(existing?.date ?: LocalDate.now()) }
    var height by remember { mutableStateOf(existing?.height?.let { fmt1(it) } ?: "") }
    var weight by remember { mutableStateOf(existing?.weight?.let { fmt1(it) } ?: "") }
    var foot by remember { mutableStateOf(existing?.footLength?.let { fmt1(it) } ?: "") }
    var head by remember { mutableStateOf(existing?.headCirc?.let { fmt1(it) } ?: "") }
    var note by remember { mutableStateOf(existing?.note ?: "") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var confirmDelete by remember { mutableStateOf(false) }

    fun save() {
        val h = parseNum(height)
        val w = parseNum(weight)
        val f = parseNum(foot)
        val hc = parseNum(head)
        if (h == null && w == null) {
            errorMessage = "身高和体重至少填一项"
            return
        }
        if (h != null && (h < 30 || h > 220)) {
            errorMessage = "身高数值看起来不太对"
            return
        }
        if (w != null && (w < 1 || w > 150)) {
            errorMessage = "体重数值看起来不太对"
            return
        }
        if (date.isAfter(LocalDate.now())) {
            errorMessage = "测量日期不能晚于今天"
            return
        }
        val base = existing ?: GrowthRecord(date = date)
        val record = base.copy(
            date = date,
            height = h,
            weight = w,
            footLength = f,
            headCirc = hc,
            note = note.trim(),
        )
        if (existing == null) Store.addRecord(record) else Store.updateRecord(record)
        onBack()
    }

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = if (existing == null) "记录生长数据" else "修改记录", onBack = onBack)
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Column(
                    modifier = Modifier.fillMaxWidth().cardStyle(),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    DateField(label = "测量日期", date = date, onDate = { date = it })
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        NumberInput("身高", height, "cm", Modifier.weight(1f)) { height = it }
                        NumberInput("体重", weight, "kg", Modifier.weight(1f)) { weight = it }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        NumberInput("脚长", foot, "cm", Modifier.weight(1f)) { foot = it }
                        NumberInput("头围", head, "cm", Modifier.weight(1f)) { head = it }
                    }
                    TextInput("备注", note, placeholder = "晨起空腹 / 换季衣服尺码") { note = it }
                    Text(
                        "身高脱鞋靠墙站直量；体重建议晨起空腹、同一台秤。测量方式不同会让曲线跳动，别误读成生长异常。",
                        fontSize = 12.sp,
                        color = Palette.subtle,
                        lineHeight = 18.sp,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
            item {
                errorMessage?.let { message ->
                    Text(
                        message,
                        fontSize = 13.sp,
                        color = Palette.bad,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(Palette.badBg)
                            .padding(12.dp),
                    )
                }
            }
            item {
                PrimaryButton(text = if (existing == null) "保存" else "保存修改") { save() }
            }
            if (existing != null) {
                item {
                    TextButton(
                        onClick = { confirmDelete = true },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("删除这条记录", fontSize = 15.sp, color = Palette.bad)
                    }
                }
            }
        }
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("删除这条记录？", fontSize = 16.sp, fontWeight = FontWeight.SemiBold) },
            text = { Text("删除后无法恢复。", fontSize = 13.sp, color = Palette.subtle) },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    existing?.let { Store.deleteRecord(it.id) }
                    onBack()
                }) { Text("删除", color = Palette.bad) }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("取消", color = Palette.subtle) }
            },
            containerColor = Palette.card,
        )
    }
}

// MARK: - 工具

private fun fmt1(value: Double): String = String.format(Locale.US, "%.1f", value)

private fun parseNum(text: String): Double? =
    text.trim().replace("，", ".").replace(",", ".").toDoubleOrNull()
