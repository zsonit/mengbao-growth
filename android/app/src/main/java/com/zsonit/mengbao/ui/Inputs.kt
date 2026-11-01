package com.zsonit.mengbao.ui

import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.PressInteraction
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/** 统一顶栏：返回按钮 + 标题 + 右侧内容 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TopBar(
    title: String,
    onBack: (() -> Unit)? = null,
    actions: @Composable () -> Unit = {},
) {
    TopAppBar(
        title = { Text(title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink) },
        navigationIcon = {
            if (onBack != null) {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回", tint = Palette.ink)
                }
            }
        },
        actions = { actions() },
        colors = TopAppBarDefaults.topAppBarColors(containerColor = Palette.background),
    )
}

/** 日期选择：点输入框任意位置弹日历，也可以直接键入 2024-06-01 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DateField(
    label: String,
    date: LocalDate,
    modifier: Modifier = Modifier,
    onDate: (LocalDate) -> Unit,
) {
    var show by remember { mutableStateOf(false) }
    var text by remember(date) {
        mutableStateOf("%04d-%02d-%02d".format(date.year, date.monthValue, date.dayOfMonth))
    }

    fun looseParse(s: String): LocalDate? {
        val parts = s.trim().split('-', '/', '.')
        if (parts.size != 3) return null
        val y = parts[0].toIntOrNull() ?: return null
        val m = parts[1].toIntOrNull() ?: return null
        val d = parts[2].toIntOrNull() ?: return null
        return runCatching { LocalDate.of(y, m, d) }.getOrNull()
    }

    // 让点击输入框本身（而不只是右侧"选择"按钮）也能弹出日历
    val interactionSource = remember { MutableInteractionSource() }
    LaunchedEffect(interactionSource) {
        interactionSource.interactions.collect { interaction ->
            if (interaction is PressInteraction.Release) show = true
        }
    }

    OutlinedTextField(
        value = text,
        onValueChange = { t ->
            text = t
            looseParse(t)?.let { if (it != date) onDate(it) }
        },
        label = { Text(label) },
        placeholder = { Text("如 2024-06-01，或点右侧选择", color = Palette.subtle, fontSize = 13.sp) },
        isError = text.length >= 8 && looseParse(text) == null,
        supportingText = {
            if (text.length >= 8 && looseParse(text) == null) {
                Text("没认出来，按 2024-06-01 格式填，或点「选择」", fontSize = 11.sp)
            }
        },
        trailingIcon = {
            TextButton(onClick = { show = true }) { Text("选择", color = Palette.purple, fontSize = 13.sp) }
        },
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
        singleLine = true,
        interactionSource = interactionSource,
        modifier = modifier.fillMaxWidth(),
    )
    if (show) {
        val millis = date.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
        val state = rememberDatePickerState(initialSelectedDateMillis = millis)
        DatePickerDialog(
            onDismissRequest = { show = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let {
                        val picked = Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()
                        onDate(picked)
                        text = "%04d-%02d-%02d".format(picked.year, picked.monthValue, picked.dayOfMonth)
                    }
                    show = false
                }) { Text("确定") }
            },
            dismissButton = { TextButton(onClick = { show = false }) { Text("取消") } },
        ) {
            DatePicker(state = state)
        }
    }
}

@Composable
fun TextInput(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
    placeholder: String? = null,
    singleLine: Boolean = true,
    onChange: (String) -> Unit,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(label) },
        placeholder = placeholder?.let { { Text(it, color = Palette.subtle, fontSize = 13.sp) } },
        singleLine = singleLine,
        modifier = modifier.fillMaxWidth(),
    )
}

@Composable
fun NumberInput(
    label: String,
    value: String,
    unit: String = "",
    modifier: Modifier = Modifier,
    onChange: (String) -> Unit,
) {
    Row(modifier = modifier, verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
        OutlinedTextField(
            value = value,
            onValueChange = { text ->
                if (text.isEmpty() || text.matches(Regex("^\\d{0,3}(\\.\\d{0,2})?$"))) onChange(text)
            },
            label = { Text(label) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            modifier = Modifier.weight(1f),
        )
        if (unit.isNotEmpty()) {
            Spacer(Modifier.width(8.dp))
            Text(unit, fontSize = 13.sp, color = Palette.subtle)
        }
    }
}

@Composable
fun Label(text: String, color: Color = Palette.subtle) {
    Text(text, fontSize = 12.sp, color = color, modifier = Modifier.padding(vertical = 2.dp))
}
