package com.zsonit.mengbao.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// MARK: - 卡片

@Composable
fun Modifier.cardStyle(padding: Dp = 16.dp, radius: Dp = 18.dp): Modifier {
    val shape = RoundedCornerShape(radius)
    return this
        .clip(shape)
        .background(Palette.card)
        .border(1.dp, Palette.hairline, shape)
        .padding(padding)
}

@Composable
fun CardBox(
    modifier: Modifier = Modifier,
    padding: Dp = 16.dp,
    radius: Dp = 18.dp,
    content: @Composable () -> Unit,
) {
    Box(modifier = modifier.fillMaxWidth().cardStyle(padding, radius)) { content() }
}

// MARK: - 标题

@Composable
fun SectionHeader(title: String, trailing: String? = null, onAction: (() -> Unit)? = null) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(start = 18.dp, end = 18.dp, top = 18.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.subtle)
        Spacer(Modifier.weight(1f))
        if (trailing != null) {
            Text(
                trailing, fontSize = 12.sp, color = Palette.purple,
                modifier = Modifier.clickable { onAction?.invoke() }.padding(4.dp),
            )
        }
    }
}

// MARK: - 标签

enum class TagTone { OK, WARN, BAD, GRAY, PURPLE }

/** 胶囊形状（Compose 没有内置 CapsuleShape） */
val CapsuleShape = RoundedCornerShape(50)

@Composable
fun TagView(text: String, tone: TagTone = TagTone.GRAY) {
    val fg = when (tone) {
        TagTone.OK -> Palette.ok
        TagTone.WARN -> Palette.warn
        TagTone.BAD -> Palette.bad
        TagTone.GRAY -> Palette.subtle
        TagTone.PURPLE -> Palette.purple
    }
    val bg = when (tone) {
        TagTone.OK -> Palette.okBg
        TagTone.WARN -> Palette.warnBg
        TagTone.BAD -> Palette.badBg
        TagTone.GRAY -> Palette.purpleTint
        TagTone.PURPLE -> Palette.purpleSoft
    }
    Text(
        text, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = fg,
        modifier = Modifier.clip(CapsuleShape).background(bg).padding(horizontal = 8.dp, vertical = 3.dp),
    )
}

// MARK: - 胶囊

@Composable
fun ChipLabel(text: String, selected: Boolean = false, icon: String? = null, onClick: (() -> Unit)? = null) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .clip(CapsuleShape)
            .background(if (selected) Palette.purple else Palette.purpleTint)
            .border(1.dp, if (selected) Palette.purple else Palette.hairline, CapsuleShape)
            .then(if (onClick != null) Modifier.clickable { onClick() } else Modifier)
            .padding(horizontal = 13.dp, vertical = 7.dp),
    ) {
        if (icon != null) {
            Text(icon, fontSize = 12.sp)
            Spacer(Modifier.width(4.dp))
        }
        Text(
            text,
            fontSize = 12.5.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) Color.White else Palette.ink2,
        )
    }
}

// MARK: - 主按钮

@Composable
fun PrimaryButton(text: String, filled: Boolean = true, modifier: Modifier = Modifier, enabled: Boolean = true, onClick: () -> Unit) {
    val shape = RoundedCornerShape(13.dp)
    val colors = ButtonDefaults.buttonColors(
        containerColor = if (filled) Palette.purple else Palette.card,
        contentColor = if (filled) Color.White else Palette.purple,
        disabledContainerColor = if (filled) Palette.purple.copy(alpha = 0.45f) else Palette.card,
        disabledContentColor = if (filled) Color.White else Palette.purple.copy(alpha = 0.45f),
    )
    if (filled) {
        Button(onClick = onClick, modifier = modifier.fillMaxWidth(), shape = shape, colors = colors, enabled = enabled) {
            Text(text, fontSize = 15.5.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(vertical = 5.dp))
        }
    } else {
        OutlinedButton(
            onClick = onClick, modifier = modifier.fillMaxWidth(), shape = shape, colors = colors,
            enabled = enabled,
            border = androidx.compose.foundation.BorderStroke(1.dp, Palette.purple),
        ) {
            Text(text, fontSize = 15.5.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(vertical = 5.dp))
        }
    }
}

// MARK: - 键值行

@Composable
fun KVRow(key: String, value: String, valueColor: Color? = null) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top,
    ) {
        Text(key, fontSize = 13.5.sp, color = Palette.subtle)
        Spacer(Modifier.width(12.dp))
        Text(
            value, fontSize = 13.5.sp, fontWeight = FontWeight.SemiBold,
            color = valueColor ?: Palette.ink, textAlign = TextAlign.End,
        )
    }
}

// MARK: - 提示块

@Composable
fun HintBlock(text: String, modifier: Modifier = Modifier) {
    Text(
        text, fontSize = 12.5.sp, color = Palette.warn, lineHeight = 18.sp,
        modifier = modifier.fillMaxWidth().clip(RoundedCornerShape(13.dp)).background(Palette.warnBg)
            .padding(14.dp),
    )
}

// MARK: - 进度条

@Composable
fun ProgressBar(value: Double, modifier: Modifier = Modifier) {
    val v = value.coerceIn(0.0, 1.0).toFloat()
    Box(
        modifier = modifier.fillMaxWidth().height(8.dp).clip(CapsuleShape).background(Palette.purpleTint),
    ) {
        Box(
            Modifier.fillMaxWidth(v).height(8.dp).clip(CapsuleShape)
                .background(androidx.compose.ui.graphics.Brush.horizontalGradient(listOf(Palette.ok, Color(0xFF4DBE91)))),
        )
    }
}

// MARK: - 空状态

@Composable
fun EmptyHint(text: String) {
    Text(
        text, fontSize = 13.5.sp, color = Palette.subtle, textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().padding(vertical = 28.dp),
    )
}

@Composable
fun DividerLine(color: Color? = null) {
    HorizontalDivider(thickness = 1.dp, color = color ?: Palette.hairlineSoft)
}
