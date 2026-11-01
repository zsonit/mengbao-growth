package com.zsonit.mengbao.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.model.QuickEntry
import com.zsonit.mengbao.ui.DividerLine
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.PrimaryButton
import com.zsonit.mengbao.ui.SectionHeader
import com.zsonit.mengbao.ui.TopBar
import com.zsonit.mengbao.ui.cardStyle

/** 自定义入口可选的 emoji */
private val emojiOptions = listOf(
    "📝", "🍼", "🤱", "🧴", "😴", "🧷",
    "🍚", "💊", "🌡️", "⚖️", "📏", "🧢",
    "🛁", "🪥", "🧸", "🎈", "🚽", "🍎",
)

@Composable
fun QuickEntryManagerScreen(onBack: () -> Unit) {
    var showAdd by remember { mutableStateOf(false) }
    var pendingDelete by remember { mutableStateOf<QuickEntry?>(null) }

    val all = Store.quickEntries
    val shown = all.withIndex().filter { it.value.visible }
    val hidden = all.withIndex().filterNot { it.value.visible }

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(
            title = "快捷入口管理",
            onBack = onBack,
            actions = {
                Text(
                    "恢复默认", fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple,
                    modifier = Modifier.clickable { Store.resetQuickEntries() }.padding(horizontal = 14.dp, vertical = 8.dp),
                )
            },
        )
        LazyColumn(Modifier.fillMaxSize()) {
            item {
                Text(
                    "自定义首页记录入口",
                    fontSize = 12.5.sp, color = Palette.subtle,
                    modifier = Modifier.padding(start = 18.dp, end = 18.dp, top = 2.dp, bottom = 4.dp),
                )
            }

            item { SectionHeader("显示中（${shown.size}）") }
            item {
                Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle(padding = 6.dp)) {
                    if (shown.isEmpty()) {
                        Text(
                            "没有显示中的入口，去下面打开一个",
                            fontSize = 13.sp, color = Palette.subtle,
                            modifier = Modifier.padding(14.dp),
                        )
                    } else {
                        shown.forEachIndexed { pos, indexed ->
                            EntryRow(
                                entry = indexed.value,
                                tintIndex = indexed.index,
                                canUp = pos > 0,
                                canDown = pos < shown.size - 1,
                                onUp = { Store.moveQuickEntry(indexed.index, shown[pos - 1].index) },
                                onDown = { Store.moveQuickEntry(indexed.index, shown[pos + 1].index) },
                                onToggle = { Store.toggleQuickEntry(indexed.value.id) },
                                onDelete = { pendingDelete = indexed.value },
                            )
                            if (pos != shown.size - 1) DividerLine()
                        }
                    }
                }
            }

            item { SectionHeader("已隐藏（${hidden.size}）") }
            item {
                Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle(padding = 6.dp)) {
                    if (hidden.isEmpty()) {
                        Text(
                            "全部入口都已显示",
                            fontSize = 13.sp, color = Palette.subtle,
                            modifier = Modifier.padding(14.dp),
                        )
                    } else {
                        hidden.forEachIndexed { pos, indexed ->
                            EntryRow(
                                entry = indexed.value,
                                tintIndex = indexed.index,
                                canUp = pos > 0,
                                canDown = pos < hidden.size - 1,
                                onUp = { Store.moveQuickEntry(indexed.index, hidden[pos - 1].index) },
                                onDown = { Store.moveQuickEntry(indexed.index, hidden[pos + 1].index) },
                                onToggle = { Store.toggleQuickEntry(indexed.value.id) },
                                onDelete = { pendingDelete = indexed.value },
                            )
                            if (pos != hidden.size - 1) DividerLine()
                        }
                    }
                }
            }

            item {
                Column(Modifier.padding(16.dp)) {
                    PrimaryButton(text = "＋ 自定义入口", filled = false) { showAdd = true }
                    Spacer(Modifier.height(10.dp))
                    Text(
                        "「恢复默认」会还原内置入口的顺序与显示状态，自定义入口会被移除。",
                        fontSize = 11.5.sp, color = Palette.subtle, lineHeight = 17.sp,
                    )
                }
            }
            item { Spacer(Modifier.height(24.dp)) }
        }
    }

    if (showAdd) {
        AddEntryDialog(onClose = { showAdd = false })
    }
    pendingDelete?.let { target ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text("删除「${target.title}」？", fontSize = 16.sp, fontWeight = FontWeight.SemiBold) },
            text = { Text("删除后不可恢复，已记录的条目不受影响。", fontSize = 13.sp, color = Palette.subtle) },
            confirmButton = {
                TextButton(onClick = {
                    Store.deleteQuickEntry(target.id)
                    pendingDelete = null
                }) { Text("删除", color = Palette.bad) }
            },
            dismissButton = {
                TextButton(onClick = { pendingDelete = null }) { Text("取消", color = Palette.subtle) }
            },
            containerColor = Palette.card,
        )
    }
}

@Composable
private fun EntryRow(
    entry: QuickEntry,
    tintIndex: Int,
    canUp: Boolean,
    canDown: Boolean,
    onUp: () -> Unit,
    onDown: () -> Unit,
    onToggle: () -> Unit,
    onDelete: () -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 6.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(38.dp).clip(RoundedCornerShape(12.dp)).background(tintOf(tintIndex)),
            contentAlignment = Alignment.Center,
        ) { Text(entry.icon, fontSize = 18.sp) }
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(entry.title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
            Text(
                if (entry.isBuiltin) "内置入口" else "自定义入口",
                fontSize = 10.5.sp, color = Palette.subtle,
            )
        }
        ArrowButton("↑", enabled = canUp, onClick = onUp)
        ArrowButton("↓", enabled = canDown, onClick = onDown)
        Spacer(Modifier.width(2.dp))
        Switch(
            checked = entry.visible,
            onCheckedChange = { onToggle() },
            colors = SwitchDefaults.colors(checkedTrackColor = Palette.pinkDeep),
        )
        if (!entry.isBuiltin) {
            Text(
                "✕", fontSize = 13.sp, color = Palette.bad,
                modifier = Modifier.clickable { onDelete() }.padding(start = 6.dp, end = 2.dp, top = 8.dp, bottom = 8.dp),
            )
        }
    }
}

@Composable
private fun ArrowButton(glyph: String, enabled: Boolean, onClick: () -> Unit) {
    Box(
        Modifier
            .size(26.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(if (enabled) Palette.purpleTint else Color.Transparent)
            .clickable(enabled = enabled) { onClick() },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            glyph, fontSize = 13.sp, fontWeight = FontWeight.Bold,
            color = if (enabled) Palette.ink2 else Palette.hairline,
        )
    }
}

@Composable
private fun AddEntryDialog(onClose: () -> Unit) {
    var title by remember { mutableStateOf("") }
    var emoji by remember { mutableStateOf(emojiOptions.first()) }

    AlertDialog(
        onDismissRequest = onClose,
        containerColor = Palette.card,
        title = { Text("新建自定义入口", fontSize = 16.sp, fontWeight = FontWeight.SemiBold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(
                    value = title,
                    onValueChange = { if (it.length <= 8) title = it },
                    label = { Text("入口名称") },
                    placeholder = { Text("例如 洗澡", color = Palette.subtle, fontSize = 13.sp) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                Text("选一个图标", fontSize = 12.sp, color = Palette.subtle)
                emojiOptions.chunked(6).forEach { row ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        row.forEach { e ->
                            val selected = emoji == e
                            Box(
                                Modifier
                                    .weight(1f)
                                    .height(38.dp)
                                    .clip(RoundedCornerShape(11.dp))
                                    .background(if (selected) Palette.pinkBg else Palette.purpleTint)
                                    .clickable { emoji = e },
                                contentAlignment = Alignment.Center,
                            ) { Text(e, fontSize = 18.sp) }
                        }
                        repeat(6 - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val name = title.trim()
                    if (name.isNotEmpty()) {
                        Store.addCustomQuickEntry(name, emoji)
                        onClose()
                    }
                },
            ) { Text("创建", color = Palette.pinkDeep) }
        },
        dismissButton = {
            TextButton(onClick = onClose) { Text("取消", color = Palette.subtle) }
        },
    )
}

@Composable
private fun tintOf(index: Int): Color {
    val list = listOf(
        Palette.pinkBg, Palette.blueBg, Palette.okBg, Palette.purpleSoft, Palette.warnBg,
    )
    return list[index % list.size]
}
