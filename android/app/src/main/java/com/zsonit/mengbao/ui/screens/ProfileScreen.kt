package com.zsonit.mengbao.ui.screens

import android.Manifest
import android.content.Intent
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberTimePickerState
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
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zsonit.mengbao.data.GrowthMath
import com.zsonit.mengbao.data.Reminders
import com.zsonit.mengbao.data.Standards
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.ui.DividerLine
import com.zsonit.mengbao.ui.Avatar
import com.zsonit.mengbao.ui.KVRow
import com.zsonit.mengbao.ui.NumberInput
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.PrimaryButton
import com.zsonit.mengbao.ui.SectionHeader
import com.zsonit.mengbao.ui.TagTone
import com.zsonit.mengbao.ui.TagView
import com.zsonit.mengbao.ui.TopBar
import com.zsonit.mengbao.ui.cardStyle
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.Locale

// MARK: - 我的

@Composable
fun ProfileScreen(onOpenKids: () -> Unit, onOpenAI: () -> Unit = {}) {
    val context = LocalContext.current
    val clipboard = LocalClipboardManager.current

    var showImport by remember { mutableStateOf(false) }
    var showReset by remember { mutableStateOf(false) }
    var showFinalReset by remember { mutableStateOf(false) }
    var showParents by remember { mutableStateOf(false) }
    var showSync by remember { mutableStateOf(false) }
    var importText by remember { mutableStateOf("") }

    fun shareText(title: String, text: String) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        context.startActivity(Intent.createChooser(intent, title))
    }

    val openBackupFile = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            val json = runCatching {
                context.contentResolver.openInputStream(uri)?.use { it.readBytes().toString(Charsets.UTF_8) }
            }.getOrNull()
            if (json.isNullOrBlank()) {
                Toast.makeText(context, "读取失败，文件可能是空的", Toast.LENGTH_LONG).show()
            } else {
                Store.importJson(json).fold(
                    onSuccess = { Toast.makeText(context, "恢复成功", Toast.LENGTH_SHORT).show() },
                    onFailure = { Toast.makeText(context, "恢复失败：${it.message}", Toast.LENGTH_LONG).show() },
                )
            }
        }
    }

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = "我的")
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            ProfileCard(onOpenKids)
            StatsGrid()
            AISection(onOpenAI = onOpenAI)
            ReminderSection()
            SettingsSection(
                onOpenParents = { showParents = true },
            )
            ChildrenSection(onOpenKids)
            DataSection(
                onExportJson = {
                    val json = Store.exportJson()
                    clipboard.setText(AnnotatedString(json))
                    Toast.makeText(context, "备份已复制到剪贴板", Toast.LENGTH_SHORT).show()
                    shareText("萌宝成长备份", json)
                },
                onExportCsv = {
                    val child = Store.current
                    if (child == null) {
                        Toast.makeText(context, "还没有孩子档案", Toast.LENGTH_SHORT).show()
                    } else {
                        shareText("${child.name}-生长记录", Store.exportCsv(child))
                    }
                },
                onImport = { showImport = true },
                onPickFile = {
                    runCatching {
                        openBackupFile.launch(arrayOf("application/json", "text/plain", "application/octet-stream"))
                    }
                },
                onReset = { showReset = true },
                onOpenSync = { showSync = true },
                onLoadDemo = {
                    Store.loadDemo()
                    Toast.makeText(context, "已载入示例数据", Toast.LENGTH_SHORT).show()
                },
            )
            LogSection()
            AboutSection()
            Spacer(Modifier.height(28.dp))
        }
    }

    if (showSync) {
        SyncScreen(onClose = { showSync = false })
    }

    if (showImport) {
        AlertDialog(
            onDismissRequest = { showImport = false },
            title = { Text("从备份恢复") },
            text = {
                OutlinedTextField(
                    value = importText,
                    onValueChange = { importText = it },
                    label = { Text("粘贴之前导出的 JSON") },
                    minLines = 4,
                    modifier = Modifier.fillMaxWidth(),
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    val result = Store.importJson(importText)
                    showImport = false
                    importText = ""
                    result.fold(
                        onSuccess = { Toast.makeText(context, "恢复成功", Toast.LENGTH_SHORT).show() },
                        onFailure = { Toast.makeText(context, "恢复失败：${it.message}", Toast.LENGTH_LONG).show() },
                    )
                }) { Text("恢复") }
            },
            dismissButton = {
                TextButton(onClick = { showImport = false }) { Text("取消") }
            },
        )
    }

    if (showReset) {
        AlertDialog(
            onDismissRequest = { showReset = false },
            title = { Text("清空全部数据？") },
            text = { Text("所有宝宝与记录都会被删除，建议先导出备份。") },
            confirmButton = {
                TextButton(onClick = {
                    showReset = false
                    showFinalReset = true
                }) { Text("继续", color = Palette.bad) }
            },
            dismissButton = {
                TextButton(onClick = { showReset = false }) { Text("取消") }
            },
        )
    }

    if (showFinalReset) {
        AlertDialog(
            onDismissRequest = { showFinalReset = false },
            title = { Text("最后确认：真的要清空吗？") },
            text = { Text("删除后无法恢复（除非之前导出过备份）。点击「确定清空」后所有宝宝与记录立即删除。") },
            confirmButton = {
                TextButton(onClick = {
                    Store.reset()
                    showFinalReset = false
                    Toast.makeText(context, "已清空全部数据", Toast.LENGTH_SHORT).show()
                }) { Text("确定清空", color = Palette.bad) }
            },
            dismissButton = {
                TextButton(onClick = { showFinalReset = false }) { Text("再想想") }
            },
        )
    }

    if (showParents) {
        ParentsHeightDialog(onClose = { showParents = false })
    }
}

// MARK: 宝宝卡片

@Composable
private fun ProfileCard(onOpenKids: () -> Unit) {
    val child = Store.current
    if (child != null) {
        Row(
            modifier = Modifier
                .padding(horizontal = 16.dp, vertical = 14.dp)
                .fillMaxWidth()
                .cardStyle(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Avatar(child = child, size = 54.dp, fontSize = 26.sp, bg = Palette.purpleSoft)
            Spacer(Modifier.width(13.dp))
            Column {
                Text(child.name, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Palette.ink)
                Text(
                    "${child.sex.label} · ${GrowthMath.ageText(child.birthDate)} · ${GrowthMath.dateString(child.birthDate)}",
                    fontSize = 12.5.sp, color = Palette.subtle,
                )
            }
            Spacer(Modifier.weight(1f))
            Text(
                "编辑", fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple,
                modifier = Modifier.clickable { onOpenKids() }.padding(4.dp),
            )
        }
    } else {
        PrimaryButton(
            text = "＋ 添加宝宝档案",
            modifier = Modifier.padding(16.dp),
            onClick = onOpenKids,
        )
    }
}

// MARK: 统计

@Composable
private fun StatsGrid() {
    val children = Store.state.children
    val records = children.sumOf { it.records.size }
    val feeds = children.sumOf { it.feeds.size }
    val firstDate = children.minOfOrNull { it.createdAt }
    val days = if (firstDate == null) 1 else maxOf(1, ChronoUnit.DAYS.between(firstDate, LocalDate.now()).toInt() + 1)
    val items = listOf(
        "${children.size}" to "宝宝",
        "$records" to "生长",
        "$feeds" to "喂养",
        "$days" to "使用天",
    )
    Row(
        Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items.forEach { (value, label) ->
            Column(
                Modifier.weight(1f).clip(RoundedCornerShape(16.dp)).background(Palette.card)
                    .padding(vertical = 11.dp).wrapContentSize(Alignment.Center),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(value, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Palette.purple)
                Text(label, fontSize = 10.5.sp, color = Palette.subtle)
            }
        }
    }
}

// MARK: AI 助手

@Composable
private fun AISection(onOpenAI: () -> Unit) {
    SectionHeader(title = "AI 助手")
    Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle(padding = 14.dp)) {
        Row(
            Modifier.fillMaxWidth().clickable { onOpenAI() },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("🎙️", fontSize = 17.sp)
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text("语音助手", fontSize = 14.sp, color = Palette.ink)
                Text(
                    "说一句话就能记喂养、加待办、查今天的数据",
                    fontSize = 11.5.sp, color = Palette.subtle,
                )
            }
            Text(
                "免费", fontSize = 10.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple,
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(Palette.purpleTint)
                    .padding(horizontal = 7.dp, vertical = 3.dp),
            )
            Spacer(Modifier.width(6.dp))
            Text("›", fontSize = 16.sp, color = Palette.subtle)
        }
    }
}

// MARK: 记录设置

@Composable
// MARK: - 提醒（本机通知）

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
private fun ReminderSection() {
    val context = LocalContext.current
    val settings = Store.settings

    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            Reminders.rescheduleNow(context)
        } else {
            Toast.makeText(context, "没开通知权限，提醒发不出来；可在系统设置 → 应用 → 萌宝成长 → 通知里打开", Toast.LENGTH_LONG).show()
        }
    }

    fun toggle(on: Boolean, set: (Boolean) -> Unit) {
        set(on)
        if (on && !Reminders.permissionGranted(context)) {
            permLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    SectionHeader(title = "提醒")
    Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle(padding = 14.dp)) {
        SettingToggle(
            title = "待办到期提醒",
            subtitle = "截止前一天 20:00 与当天 9:00 各提醒一次",
            checked = settings.todoReminderOn,
            onChange = { toggle(it) { Store.setTodoReminder(it) } },
        )
        DividerLine()
        SettingToggle(
            title = "定期测量提醒",
            subtitle = "到点提醒量身高体重，间隔和时间可调",
            checked = settings.growthReminderOn,
            onChange = { toggle(it) { Store.setGrowthReminder(on = it) } },
        )
        if (settings.growthReminderOn) {
            DividerLine()
            val base = Store.current?.records?.maxByOrNull { it.date }?.date
            val dayFmt = java.time.format.DateTimeFormatter.ofPattern("M月d日")

            Row(Modifier.fillMaxWidth().padding(vertical = 9.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("提醒间隔", fontSize = 14.sp, color = Palette.ink)
                Spacer(Modifier.weight(1f))
                Segmented(
                    options = listOf("一周", "两周", "一个月", "三个月"),
                    selected = when (settings.growthReminderDays) {
                        7 -> "一周"
                        14 -> "两周"
                        90 -> "三个月"
                        else -> "一个月"
                    },
                    onSelect = { v ->
                        Store.setGrowthReminder(days = when (v) {
                            "一周" -> 7
                            "两周" -> 14
                            "三个月" -> 90
                            else -> 30
                        })
                    },
                    modifier = Modifier.width(215.dp),
                )
            }
            DividerLine()

            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("自定义天数", fontSize = 14.sp, color = Palette.ink)
                    Text("不用上面的档位，就自己定（1～180 天）", fontSize = 11.5.sp, color = Palette.subtle)
                }
                TextButton(onClick = { Store.setGrowthReminder(days = (settings.growthReminderDays - 1).coerceIn(1, 180)) }) {
                    Text("−", fontSize = 18.sp, color = Palette.purple)
                }
                Text(
                    "${settings.growthReminderDays} 天",
                    fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple,
                    modifier = Modifier.padding(horizontal = 4.dp),
                )
                TextButton(onClick = { Store.setGrowthReminder(days = (settings.growthReminderDays + 1).coerceIn(1, 180)) }) {
                    Text("＋", fontSize = 18.sp, color = Palette.purple)
                }
            }
            DividerLine()

            var showTime by remember { mutableStateOf(false) }
            Row(
                Modifier.fillMaxWidth().padding(vertical = 9.dp).clickable { showTime = true },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("提醒时间", fontSize = 14.sp, color = Palette.ink)
                Spacer(Modifier.weight(1f))
                Text(
                    String.format(Locale.US, "%02d:%02d", settings.growthReminderHour, settings.growthReminderMinute),
                    fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple,
                )
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null,
                    tint = Palette.subtle, modifier = Modifier.size(16.dp),
                )
            }
            DividerLine()

            val next = nextGrowthReminderDate(settings, base)
            Text(
                "上次测量：" + (base?.format(dayFmt) ?: "还没有记录") +
                    " · 下次提醒：" + (next?.format(dayFmt) ?: "—"),
                fontSize = 11.5.sp, color = Palette.subtle,
            )

            if (showTime) {
                val state = rememberTimePickerState(
                    initialHour = settings.growthReminderHour,
                    initialMinute = settings.growthReminderMinute,
                    is24Hour = true,
                )
                AlertDialog(
                    onDismissRequest = { showTime = false },
                    title = { Text("提醒时间") },
                    text = { TimePicker(state = state) },
                    confirmButton = {
                        TextButton(onClick = {
                            Store.setGrowthReminder(hour = state.hour, minute = state.minute)
                            showTime = false
                        }) { Text("好") }
                    },
                    dismissButton = {
                        TextButton(onClick = { showTime = false }) { Text("取消") }
                    },
                )
            }
        }
    }
}

private fun nextGrowthReminderDate(s: com.zsonit.mengbao.model.AppSettings, base: LocalDate?): LocalDate? {
    if (!s.growthReminderOn) return null
    var cursor = base ?: LocalDate.now()
    var guard = 0
    while (guard < 400) {
        guard += 1
        cursor = cursor.plusDays(maxOf(1, s.growthReminderDays).toLong())
        val fire = cursor.atTime(s.growthReminderHour, s.growthReminderMinute)
        if (fire.isAfter(java.time.LocalDateTime.now())) return cursor
    }
    return null
}

private fun SettingsSection(onOpenParents: () -> Unit) {
    val settings = Store.settings

    SectionHeader(title = "记录设置")
    Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle(padding = 14.dp)) {
        Row(
            Modifier.fillMaxWidth().padding(vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("体重单位", fontSize = 14.sp, color = Palette.ink)
            Spacer(Modifier.weight(1f))
            Segmented(
                options = listOf("kg", "斤"),
                selected = settings.weightUnit,
                onSelect = { Store.setWeightUnit(it) },
                modifier = Modifier.width(120.dp),
            )
        }
        DividerLine()

        Row(
            Modifier.fillMaxWidth().padding(vertical = 9.dp).clickable { onOpenParents() },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column {
                Text("父母身高", fontSize = 14.sp, color = Palette.ink)
                Text("用于 18 岁靶身高预测", fontSize = 11.5.sp, color = Palette.subtle)
            }
            Spacer(Modifier.weight(1f))
            Text(parentsText(), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple)
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null,
                tint = Palette.subtle, modifier = Modifier.size(16.dp),
            )
        }
        DividerLine()

        SettingToggle(
            title = "喂养模块",
            subtitle = "关闭后隐藏「喂养」Tab、首页今日记录统计与喂养类快捷入口",
            checked = settings.showFeed,
            onChange = { Store.setShowFeed(it) },
        )
        DividerLine()

        SettingToggle(
            title = "接种模块",
            subtitle = "广东免疫规划 ${GrowthMath.totalDoses} 剂",
            checked = settings.showShot,
            onChange = { Store.setShowShot(it) },
        )
        DividerLine()

        SettingToggle(
            title = "鞋服尺码模块",
            subtitle = "关闭后隐藏首页「鞋服尺码」入口与尺码记录（记录不会被删除）",
            checked = settings.showSize,
            onChange = { Store.setShowSize(it) },
        )
        DividerLine()

        Row(
            Modifier.fillMaxWidth().padding(vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("外观", fontSize = 14.sp, color = Palette.ink)
            Spacer(Modifier.weight(1f))
            Segmented(
                options = listOf("跟随系统", "浅色", "深色"),
                selected = themeValue(),
                onSelect = { v ->
                    Store.setDarkMode(when (v) {
                        "跟随系统" -> null
                        "深色" -> true
                        else -> false
                    })
                },
                modifier = Modifier.width(190.dp),
            )
        }
    }
}

@Composable
private fun SettingToggle(title: String, subtitle: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, fontSize = 14.sp, color = Palette.ink)
            Text(subtitle, fontSize = 11.5.sp, color = Palette.subtle)
        }
        Switch(
            checked = checked, onCheckedChange = onChange,
            colors = SwitchDefaults.colors(checkedTrackColor = Palette.purple),
        )
    }
}

@Composable
private fun Segmented(
    options: List<String>,
    selected: String,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier
            .clip(RoundedCornerShape(9.dp))
            .background(Palette.purpleTint)
            .padding(3.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        options.forEach { option ->
            val isSelected = option == selected
            Text(
                option,
                fontSize = 12.sp,
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                color = if (isSelected) Color.White else Palette.ink2,
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(7.dp))
                    .background(if (isSelected) Palette.purple else Color.Transparent)
                    .clickable { onSelect(option) }
                    .padding(vertical = 5.dp)
                    .wrapContentSize(Alignment.Center),
            )
        }
    }
}

// MARK: 孩子

@Composable
private fun ChildrenSection(onOpenKids: () -> Unit) {
    val children = Store.state.children
    val currentId = Store.state.currentId

    SectionHeader(title = "孩子")
    Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle(padding = 14.dp)) {
        children.forEach { kid ->
            Row(
                Modifier.fillMaxWidth().padding(vertical = 9.dp).clickable { Store.selectChild(kid.id) },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Avatar(child = kid, size = 28.dp, fontSize = 19.sp)
                Spacer(Modifier.width(10.dp))
                Column {
                    Text(kid.name, fontSize = 14.sp, color = Palette.ink)
                    Text(GrowthMath.ageText(kid.birthDate), fontSize = 11.5.sp, color = Palette.subtle)
                }
                Spacer(Modifier.weight(1f))
                if (kid.id == currentId) {
                    TagView(text = "当前", tone = TagTone.OK)
                } else {
                    Text("切换", fontSize = 12.sp, color = Palette.purple)
                }
            }
            DividerLine()
        }
        Text(
            "＋ 添加另一个孩子", fontSize = 13.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple,
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onOpenKids() }
                .padding(vertical = 9.dp),
        )
    }
}

// MARK: 数据管理

@Composable
private fun DataSection(
    onExportJson: () -> Unit,
    onExportCsv: () -> Unit,
    onImport: () -> Unit,
    onPickFile: () -> Unit,
    onReset: () -> Unit,
    onOpenSync: () -> Unit,
    onLoadDemo: () -> Unit,
) {
    SectionHeader(title = "数据管理")
    Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle(padding = 14.dp)) {
        DataRow(title = "☁️ 配对同步", subtitle = "两台手机自动同步全部资料", onClick = onOpenSync)
        DividerLine()
        DataRow(title = "导出备份", subtitle = "JSON，可换手机恢复", onClick = onExportJson)
        DividerLine()
        DataRow(title = "导出 CSV", subtitle = "给医生看的表格", onClick = onExportCsv)
        DividerLine()
        DataRow(title = "选择备份文件恢复", subtitle = "从文件管理 / 网盘里挑 JSON", onClick = onPickFile)
        DividerLine()
        DataRow(title = "粘贴 JSON 恢复", subtitle = "手动粘贴之前导出的内容", onClick = onImport)
        DividerLine()
        DataRow(title = "载入示例数据", subtitle = "用虚拟数据体验功能", onClick = onLoadDemo)
        DividerLine()
        Row(
            Modifier.fillMaxWidth().padding(vertical = 11.dp).clickable { onReset() },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("清空全部数据", fontSize = 14.sp, color = Palette.bad)
            Spacer(Modifier.weight(1f))
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null,
                tint = Palette.subtle, modifier = Modifier.size(16.dp),
            )
        }
        Text(
            "升级 App 直接覆盖安装即可，数据不会丢（不要先卸载）。换手机前先「导出备份」。",
            fontSize = 11.sp, color = Palette.subtle, lineHeight = 15.sp,
        )
    }
}

@Composable
private fun DataRow(title: String, subtitle: String, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 9.dp).clickable { onClick() },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column {
            Text(title, fontSize = 14.sp, color = Palette.ink)
            Text(subtitle, fontSize = 11.5.sp, color = Palette.subtle)
        }
        Spacer(Modifier.weight(1f))
        Icon(
            Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null,
            tint = Palette.subtle, modifier = Modifier.size(16.dp),
        )
    }
}

// MARK: 运行日志

@Composable
private fun LogSection() {
    val context = androidx.compose.ui.platform.LocalContext.current
    var showViewer by remember { mutableStateOf(false) }
    var logText by remember { mutableStateOf("") }

    SectionHeader(title = "运行日志（排查问题）")
    Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle(padding = 14.dp)) {
        SettingToggle(
            title = "记录运行日志",
            subtitle = "独立开关，默认关。开启后记录页面加载、接口调用等过程；崩溃无论开关都会记录",
            checked = Store.settings.showLog,
            onChange = { Store.setShowLog(it); com.zsonit.mengbao.data.AppLog.isEnabled = it },
        )
        DividerLine()
        DataRow(
            title = "查看日志",
            subtitle = "崩溃、异常与过程记录",
            onClick = {
                logText = com.zsonit.mengbao.data.AppLog.readAll()
                showViewer = true
            },
        )
        DividerLine()
        DataRow(
            title = "导出日志",
            subtitle = "分享文本，发给开发者排查",
            onClick = {
                val text = com.zsonit.mengbao.data.AppLog.readAll()
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_SUBJECT, "萌宝成长运行日志")
                    putExtra(Intent.EXTRA_TEXT, text.take(9000))
                }
                runCatching { context.startActivity(Intent.createChooser(intent, "导出运行日志")) }
            },
        )
        DividerLine()
        DataRow(
            title = "清空日志",
            subtitle = "删除本机全部日志",
            onClick = {
                com.zsonit.mengbao.data.AppLog.clear()
                Toast.makeText(context, "日志已清空", Toast.LENGTH_SHORT).show()
            },
        )
    }

    if (showViewer) {
        AlertDialog(
            onDismissRequest = { showViewer = false },
            title = { Text("运行日志", fontWeight = FontWeight.SemiBold) },
            text = {
                Text(
                    logText,
                    fontSize = 11.sp,
                    lineHeight = 15.sp,
                    color = Palette.ink2,
                    fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                    modifier = Modifier
                        .heightIn(max = 420.dp)
                        .verticalScroll(rememberScrollState()),
                )
            },
            confirmButton = {
                TextButton(onClick = { showViewer = false }) { Text("关闭", color = Palette.purple) }
            },
        )
    }
}

// MARK: 关于

@Composable
private fun AboutSection() {
    SectionHeader(title = "关于")
    Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle(padding = 14.dp)) {
        KVRow(key = "版本", value = com.zsonit.mengbao.BuildConfig.VERSION_NAME)
        DividerLine()
        KVRow(key = "数据存储", value = "本机，不上传云端")
        DividerLine()
        KVRow(key = "生长标准", value = "WHO / 中国 7 岁以下 / WS·T 423")
        DividerLine()
        KVRow(key = "接种程序", value = "广东省 · 2026 版")
        Text(
            Standards.disclaimer,
            fontSize = 12.sp, color = Palette.subtle,
            modifier = Modifier.padding(top = 10.dp),
        )
    }
}

// MARK: 父母身高

@Composable
private fun ParentsHeightDialog(onClose: () -> Unit) {
    val context = LocalContext.current
    val settings = Store.settings
    var father by remember {
        mutableStateOf(settings.fatherHeight?.let { String.format(Locale.US, "%.0f", it) } ?: "")
    }
    var mother by remember {
        mutableStateOf(settings.motherHeight?.let { String.format(Locale.US, "%.0f", it) } ?: "")
    }

    AlertDialog(
        onDismissRequest = onClose,
        title = { Text("父母身高") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                NumberInput(
                    label = "爸爸身高", value = father, unit = "cm", onChange = { father = it },
                )
                NumberInput(
                    label = "妈妈身高", value = mother, unit = "cm", onChange = { mother = it },
                )
                Text(
                    "靶身高公式：男孩 (父+母+13)/2，女孩 (父+母−13)/2，误差约 ±5cm。仅用于参考，不代表最终身高。",
                    fontSize = 12.sp, color = Palette.subtle,
                )
            }
        },
        confirmButton = {
            TextButton(onClick = {
                val f = father.toDoubleOrNull()
                val m = mother.toDoubleOrNull()
                if (f != null && (f < 120 || f > 220)) return@TextButton
                if (m != null && (m < 120 || m > 210)) return@TextButton
                Store.setParents(f, m)
                onClose()
                Toast.makeText(context, "已保存父母身高", Toast.LENGTH_SHORT).show()
            }) { Text("保存") }
        },
        dismissButton = {
            TextButton(onClick = onClose) { Text("取消") }
        },
    )
}

@Composable
private fun parentsText(): String {
    val settings = Store.settings
    val f = settings.fatherHeight
    val m = settings.motherHeight
    return if (f == null || m == null) "未填写" else "${f.toInt()} / ${m.toInt()} cm"
}

@Composable
private fun themeValue(): String {
    val dark = Store.settings.darkMode
    return when (dark) {
        null -> "跟随系统"
        true -> "深色"
        false -> "浅色"
    }
}
