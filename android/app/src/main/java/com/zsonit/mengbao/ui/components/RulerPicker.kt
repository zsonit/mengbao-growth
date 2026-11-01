package com.zsonit.mengbao.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zsonit.mengbao.ui.Palette
import java.util.Locale
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.roundToLong

/**
 * 横向标尺选择器：中间指针固定，刻度随拖动滚动，抬手吸附到 step。
 *
 * - 拖动过程中只回调「吸附后的值」，且值没变就不回调，避免上层重组的抖动。
 * - 数值范围外自动夹住，不会越界。
 */
@Composable
fun RulerPicker(
    value: Double,
    onValueChange: (Double) -> Unit,
    range: ClosedRange<Double>,
    step: Double,
    format: String = "%.1f",
    unit: String = "",
    accent: Color = Palette.pinkDeep,
) {
    val start = range.start
    val end = range.endInclusive
    val safeStep = if (step > 0.0) step else 1.0

    val density = LocalDensity.current
    val stepPx = with(density) { 15.dp.toPx() }
    val labelGapPx = with(density) { 46.dp.toPx() }
    val labelSizePx = with(density) { 10.sp.toPx() }

    // 吸附：先按 step 取整，再夹到区间内
    fun snap(v: Double): Double {
        val k = ((v - start) / safeStep).roundToLong()
        return (start + k * safeStep).coerceIn(start, end)
    }

    // 拖动用的连续值（不吸附），保证滑动跟手
    var raw by remember(start, end, safeStep) { mutableStateOf(value.coerceIn(start, end)) }
    var lastEmit by remember(start, end, safeStep) { mutableStateOf(snap(value.coerceIn(start, end))) }
    val onChange by rememberUpdatedState(onValueChange)

    // 外部改值（chips、语音识别）时同步内部状态
    LaunchedEffect(value) {
        val v = value.coerceIn(start, end)
        if (abs(v - lastEmit) > safeStep * 0.001) {
            raw = v
            lastEmit = v
        }
    }

    val subtle = Palette.subtle
    val ink = Palette.ink
    val paint = remember { android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG) }

    // 主刻度间隔：从「好看的数字」里挑一个，保证标签不挤在一起
    val candidates = listOf(0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0)
    val majorStep = candidates.firstOrNull {
        it >= safeStep - 1e-9 && (it / safeStep) * stepPx >= labelGapPx
    } ?: candidates.last()

    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                String.format(Locale.US, format, snap(raw)),
                fontSize = 30.sp,
                fontWeight = FontWeight.Bold,
                color = accent,
            )
            if (unit.isNotEmpty()) {
                Text(
                    unit,
                    fontSize = 13.sp,
                    color = Palette.subtle,
                    modifier = Modifier.padding(start = 4.dp, bottom = 5.dp),
                )
            }
        }
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(76.dp)
                .pointerInput(start, end, safeStep, stepPx) {
                    detectDragGestures(
                        onDrag = { change, drag ->
                            change.consume()
                            raw = (raw - drag.x / stepPx * safeStep).coerceIn(start, end)
                            val snapped = snap(raw)
                            if (abs(snapped - lastEmit) > safeStep * 0.001) {
                                lastEmit = snapped
                                onChange(snapped)
                            }
                        },
                        onDragEnd = {
                            val snapped = snap(raw)
                            raw = snapped
                            if (abs(snapped - lastEmit) > safeStep * 0.001) {
                                lastEmit = snapped
                                onChange(snapped)
                            }
                        },
                        onDragCancel = { raw = snap(raw) },
                    )
                },
        ) {
            val baseline = size.height - 14.dp.toPx()
            val centerX = size.width / 2f
            val curIndex = (raw - start) / safeStep
            val halfCount = (size.width / 2f) / stepPx + 1f
            val from = floor(curIndex - halfCount).toInt()
            val to = ceil(curIndex + halfCount).toInt()

            paint.textSize = labelSizePx
            paint.textAlign = android.graphics.Paint.Align.CENTER
            paint.color = subtle.toArgb()

            for (i in from..to) {
                val v = start + i * safeStep
                if (v < start - 1e-9 || v > end + 1e-9) continue
                val x = centerX + ((i - curIndex) * stepPx).toFloat()
                if (x < -stepPx || x > size.width + stepPx) continue

                val majorRatio = v / majorStep
                val isMajor = abs(majorRatio - majorRatio.roundToLong()) < 1e-6
                val tickH = if (isMajor) 16.dp.toPx() else 8.dp.toPx()
                drawLine(
                    color = if (isMajor) ink.copy(alpha = 0.45f) else subtle.copy(alpha = 0.45f),
                    start = Offset(x, baseline - tickH),
                    end = Offset(x, baseline),
                    strokeWidth = if (isMajor) 1.6.dp.toPx() else 1.dp.toPx(),
                    cap = StrokeCap.Round,
                )
                if (isMajor) {
                    val label = String.format(Locale.US, format, v)
                    drawContext.canvas.nativeCanvas.drawText(
                        label,
                        x,
                        baseline - 22.dp.toPx(),
                        paint,
                    )
                }
            }

            // 中间指针
            drawLine(
                color = accent,
                start = Offset(centerX, 4.dp.toPx()),
                end = Offset(centerX, baseline + 8.dp.toPx()),
                strokeWidth = 2.5.dp.toPx(),
                cap = StrokeCap.Round,
            )
        }
    }
}
