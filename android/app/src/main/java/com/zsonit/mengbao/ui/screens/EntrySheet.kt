package com.zsonit.mengbao.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zsonit.mengbao.data.EntryPresets
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.FeedLog
import com.zsonit.mengbao.model.GrowthRecord
import com.zsonit.mengbao.model.QuickEntry
import com.zsonit.mengbao.ui.CapsuleShape
import com.zsonit.mengbao.ui.DateField
import com.zsonit.mengbao.ui.Label
import com.zsonit.mengbao.ui.NumberInput
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.PrimaryButton
import com.zsonit.mengbao.ui.TextInput
import com.zsonit.mengbao.ui.cardStyle
import com.zsonit.mengbao.ui.components.RulerPicker
import java.time.LocalDate
import java.time.LocalTime
import kotlin.math.roundToInt

/**
 * 底部弹层录入：按快捷入口的 kind 决定用标尺、chips 还是输入框。
 * 复用数据层的 EntryPresets，保证与 iOS 的预设一致。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EntrySheet(entry: QuickEntry, child: Child, onDismiss: () -> Unit) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = Palette.background,
        dragHandle = {
            Box(
                Modifier.fillMaxWidth().padding(top = 10.dp, bottom = 8.dp),
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    Modifier.size(width = 38.dp, height = 4.dp)
                        .clip(CapsuleShape).background(Palette.hairline),
                )
            }
        },
    ) {
        EntrySheetBody(entry = entry, child = child, onDismiss = onDismiss)
    }
}

@Composable
private fun EntrySheetBody(entry: QuickEntry, child: Child, onDismiss: () -> Unit) {
    val now = remember { LocalTime.now().withSecond(0).withNano(0) }
    var date by remember { mutableStateOf(LocalDate.now()) }
    var hour by remember { mutableStateOf("%02d".format(now.hour)) }
    var minute by remember { mutableStateOf("%02d".format(now.minute)) }

    // 各类型的录入状态
    var ml by remember { mutableStateOf(120.0) }
    var side by remember { mutableStateOf("左") }
    var breastMin by remember { mutableStateOf(15.0) }
    var sleepMin by remember { mutableStateOf(30.0) }
    var diaperKind by remember { mutableStateOf("小便") }
    var food by remember { mutableStateOf("") }
    var grams by remember { mutableStateOf(50.0) }
    var trackGrams by remember { mutableStateOf(false) }
    var note by remember { mutableStateOf("") }
    var temp by remember { mutableStateOf(36.5) }
    var weight by remember { mutableStateOf(child.latestWeight ?: 3.5) }
    var height by remember { mutableStateOf(child.latestHeight ?: 50.0) }
    var head by remember { mutableStateOf(40.0) }
    // 新增：瓶喂奶源 / 储奶方式 / 喂药 / 记事本
    var milkSource by remember { mutableStateOf("奶粉") }
    var storageKind by remember { mutableStateOf("冷藏") }
    var dose by remember { mutableStateOf(5.0) }
    var medicineReason by remember { mutableStateOf("") }
    var notebookTag by remember { mutableStateOf("") }

    val isGrowth = entry.kind == "weight" || entry.kind == "height" || entry.kind == "head"

    fun save() {
        val h = hour.toIntOrNull()?.coerceIn(0, 23) ?: now.hour
        val m = minute.toIntOrNull()?.coerceIn(0, 59) ?: now.minute
        val time = LocalTime.of(h, m)

        if (isGrowth) {
            // 生长数据：同一天已有记录就合并，避免一天多条重复
            val existing = child.records.firstOrNull { it.date == date }
            val base = existing ?: GrowthRecord(date = date)
            val record = when (entry.kind) {
                "weight" -> base.copy(date = date, weight = weight, note = note.trim().ifEmpty { base.note })
                "height" -> base.copy(date = date, height = height, note = note.trim().ifEmpty { base.note })
                else -> base.copy(date = date, headCirc = head, note = note.trim().ifEmpty { base.note })
            }
            if (existing != null) Store.updateRecord(record) else Store.addRecord(record)
            onDismiss()
            return
        }

        val kind = kindOf(entry.kind)
        val log = when (entry.kind) {
            "bottle" -> FeedLog(date = date, time = time, kind = kind, ml = ml, tag = milkSource)
            "pumping" -> FeedLog(date = date, time = time, kind = kind, ml = ml)
            "storage" -> FeedLog(date = date, time = time, kind = kind, ml = ml, tag = storageKind)
            "medicine" -> FeedLog(
                date = date, time = time, kind = kind,
                note = food.trim().ifEmpty { "喂药" },
                value = dose,
                tag = medicineReason.ifEmpty { null },
            )
            "notebook" -> FeedLog(
                date = date, time = time, kind = kind,
                note = note.trim().ifEmpty { notebookTag.ifEmpty { "记事本" } },
                tag = notebookTag.ifEmpty { null },
            )
            "breast" -> FeedLog(
                date = date, time = time, kind = kind,
                minutes = breastMin.roundToInt(), side = side,
            )
            "sleep" -> FeedLog(date = date, time = time, kind = kind, minutes = sleepMin.roundToInt())
            "diaper" -> FeedLog(date = date, time = time, kind = kind, diaperKind = diaperKind)
            "solid" -> FeedLog(
                date = date, time = time, kind = kind,
                value = if (trackGrams) grams else null,
                note = listOf(food.trim(), note.trim()).filter { it.isNotEmpty() }.joinToString("，")
                    .ifEmpty { "已添加辅食" },
            )
            "supplement" -> FeedLog(
                date = date, time = time, kind = kind,
                note = listOf(food.trim(), note.trim()).filter { it.isNotEmpty() }.joinToString("，")
                    .ifEmpty { "补剂" },
            )
            "temp" -> FeedLog(date = date, time = time, kind = kind, value = temp, note = note.trim())
            else -> FeedLog(
                date = date, time = time, kind = FeedLog.Kind.CUSTOM,
                note = note.trim().ifEmpty { entry.title },
            )
        }
        Store.addFeed(log)
        onDismiss()
    }

    val screenH = LocalConfiguration.current.screenHeightDp.dp

    Column(
        Modifier
            .fillMaxWidth()
            // 弹层固定为屏幕高度的 70%：比半屏高（备注能直接看到），又不至于顶满全屏
            .height(screenH * 0.7f)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(bottom = 26.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // 标题
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(38.dp).clip(RoundedCornerShape(13.dp)).background(Palette.pinkBg),
                contentAlignment = Alignment.Center,
            ) { Text(entry.icon, fontSize = 18.sp) }
            Spacer(Modifier.width(10.dp))
            Column {
                Text(entry.title, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Palette.ink)
                Text(
                    "${child.name} · ${kindHint(entry.kind)}",
                    fontSize = 11.5.sp, color = Palette.subtle,
                )
            }
        }

        // 主体：按类型分支
        Column(
            Modifier.fillMaxWidth().cardStyle(padding = 14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            when (entry.kind) {
                "bottle" -> {
                    Label("这一顿喝的是")
                    ChipRow(
                        labels = EntryPresets.milkSources,
                        isSelected = { i -> milkSource == EntryPresets.milkSources[i] },
                        onSelect = { i -> milkSource = EntryPresets.milkSources[i] },
                    )
                    RulerPicker(
                        value = ml, onValueChange = { ml = it },
                        range = 0.0..300.0, step = 5.0, format = "%.0f", unit = "ml",
                    )
                    ChipRow(
                        labels = EntryPresets.milkAmounts.map { "${it.roundToInt()}" },
                        isSelected = { i -> ml == EntryPresets.milkAmounts[i] },
                        onSelect = { i -> ml = EntryPresets.milkAmounts[i] },
                    )
                    Label("拖动标尺快速选择奶量")
                }

                "pumping" -> {
                    RulerPicker(
                        value = ml, onValueChange = { ml = it },
                        range = 0.0..300.0, step = 5.0, format = "%.0f", unit = "ml",
                    )
                    ChipRow(
                        labels = EntryPresets.milkAmounts.map { "${it.roundToInt()}" },
                        isSelected = { i -> ml == EntryPresets.milkAmounts[i] },
                        onSelect = { i -> ml = EntryPresets.milkAmounts[i] },
                    )
                    Label("拖动标尺快速选择奶量")
                }

                "storage" -> {
                    Label("存放方式")
                    ChipRow(
                        labels = EntryPresets.storageKinds,
                        isSelected = { i -> storageKind == EntryPresets.storageKinds[i] },
                        onSelect = { i -> storageKind = EntryPresets.storageKinds[i] },
                    )
                    RulerPicker(
                        value = ml, onValueChange = { ml = it },
                        range = 0.0..300.0, step = 5.0, format = "%.0f", unit = "ml",
                    )
                    ChipRow(
                        labels = EntryPresets.milkAmounts.map { "${it.roundToInt()}" },
                        isSelected = { i -> ml == EntryPresets.milkAmounts[i] },
                        onSelect = { i -> ml = EntryPresets.milkAmounts[i] },
                    )
                    Label(
                        if (storageKind == "冷冻") "冷冻一般可存 3 个月左右，放冰箱最里层，写明日期先存先用。"
                        else "冷藏一般 24 小时内喝完，放冰箱最里层，别放门上。",
                    )
                }

                "medicine" -> {
                    TextInput(
                        label = "吃了什么药",
                        value = food,
                        placeholder = "例如 美林 布洛芬混悬液",
                        onChange = { food = it },
                    )
                    ChipRow(
                        labels = EntryPresets.medicineNames,
                        isSelected = { i -> food == EntryPresets.medicineNames[i] },
                        onSelect = { i -> food = EntryPresets.medicineNames[i] },
                    )
                    Label("吃了多少")
                    RulerPicker(
                        value = dose, onValueChange = { dose = it },
                        range = 0.0..20.0, step = 0.5, format = "%.1f", unit = "ml",
                    )
                    Label("为什么吃（可不选）")
                    ChipRow(
                        labels = EntryPresets.medicineReasons,
                        isSelected = { i -> medicineReason == EntryPresets.medicineReasons[i] },
                        onSelect = { i ->
                            val picked = EntryPresets.medicineReasons[i]
                            medicineReason = if (medicineReason == picked) "" else picked
                        },
                    )
                }

                "notebook" -> {
                    Label("异常情况（点一下加进记录）")
                    ChipRow(
                        labels = EntryPresets.notebookTags,
                        isSelected = { i -> notebookTag == EntryPresets.notebookTags[i] },
                        onSelect = { i ->
                            val picked = EntryPresets.notebookTags[i]
                            notebookTag = if (notebookTag == picked) "" else picked
                        },
                    )
                    TextInput(
                        label = "详细记一笔",
                        value = note,
                        placeholder = "什么时候、什么样、有没有处理…",
                        singleLine = false,
                        onChange = { note = it },
                    )
                }

                "breast" -> {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf("左", "右", "双侧").forEach { s ->
                            Box(
                                Modifier.clip(CapsuleShape)
                                    .background(if (side == s) Palette.pinkDeep else Palette.purpleTint)
                                    .clickable { side = s }
                                    .padding(horizontal = 18.dp, vertical = 7.dp),
                            ) {
                                Text(
                                    s, fontSize = 13.sp,
                                    fontWeight = if (side == s) FontWeight.SemiBold else FontWeight.Normal,
                                    color = if (side == s) Color.White else Palette.ink2,
                                )
                            }
                        }
                    }
                    RulerPicker(
                        value = breastMin, onValueChange = { breastMin = it },
                        range = 0.0..60.0, step = 1.0, format = "%.0f", unit = "分钟",
                    )
                    ChipRow(
                        labels = classicBreastMinutes.map { "${it.roundToInt()}" },
                        isSelected = { i -> breastMin == classicBreastMinutes[i] },
                        onSelect = { i -> breastMin = classicBreastMinutes[i] },
                    )
                }

                "sleep" -> {
                    RulerPicker(
                        value = sleepMin, onValueChange = { sleepMin = it },
                        range = 0.0..240.0, step = 5.0, format = "%.0f", unit = "分钟",
                    )
                    ChipRow(
                        labels = EntryPresets.sleepMinutes.map { "$it" },
                        isSelected = { i -> sleepMin == EntryPresets.sleepMinutes[i].toDouble() },
                        onSelect = { i -> sleepMin = EntryPresets.sleepMinutes[i].toDouble() },
                    )
                }

                "diaper" -> {
                    Label("这次换了什么")
                    ChipRow(
                        labels = EntryPresets.diaperKinds,
                        isSelected = { i -> diaperKind == EntryPresets.diaperKinds[i] },
                        onSelect = { i -> diaperKind = EntryPresets.diaperKinds[i] },
                    )
                }

                "solid" -> {
                    TextInput(
                        label = "吃了什么",
                        value = food,
                        placeholder = "吃了什么？例如 南瓜泥",
                        onChange = { food = it },
                    )
                    ChipRow(
                        labels = EntryPresets.foods,
                        isSelected = { i -> food == EntryPresets.foods[i] },
                        onSelect = { i -> food = EntryPresets.foods[i] },
                    )
                    ToggleChip(text = "记克数", selected = trackGrams) { trackGrams = !trackGrams }
                    if (trackGrams) {
                        RulerPicker(
                            value = grams, onValueChange = { grams = it },
                            range = 0.0..300.0, step = 10.0, format = "%.0f", unit = "克",
                        )
                    }
                }

                "supplement" -> {
                    TextInput(
                        label = "补了什么",
                        value = food,
                        placeholder = "例如 维生素D3 一滴",
                        onChange = { food = it },
                    )
                    ChipRow(
                        labels = EntryPresets.supplements,
                        isSelected = { i -> food == EntryPresets.supplements[i] },
                        onSelect = { i -> food = EntryPresets.supplements[i] },
                    )
                }

                "temp" -> {
                    RulerPicker(
                        value = temp, onValueChange = { temp = it },
                        range = 34.0..42.0, step = 0.1, format = "%.1f", unit = "℃",
                    )
                    if (temp >= 38.5) {
                        TempHint("超过 38.5℃，建议尽快就医，并记录用药与体温变化。", Palette.bad, Palette.badBg)
                    } else if (temp >= 37.3) {
                        TempHint("超过 37.3℃，先物理降温、少量多次喂水，隔 1 小时复测。", Palette.warn, Palette.warnBg)
                    } else {
                        TempHint("体温正常，保持观察即可。", Palette.ok, Palette.okBg)
                    }
                }

                "weight" -> {
                    RulerPicker(
                        value = weight, onValueChange = { weight = it },
                        range = 0.5..60.0, step = 0.05, format = "%.2f", unit = "kg",
                    )
                    Label("建议晨起空腹、穿同样衣服、用同一台秤称量")
                }

                "height" -> {
                    RulerPicker(
                        value = height, onValueChange = { height = it },
                        range = 30.0..160.0, step = 0.1, format = "%.1f", unit = "cm",
                    )
                    Label("脱鞋、靠墙站直，头顶与墙面垂直读数")
                }

                "head" -> {
                    RulerPicker(
                        value = head, onValueChange = { head = it },
                        range = 25.0..60.0, step = 0.1, format = "%.1f", unit = "cm",
                    )
                    Label("绕眉弓上方与后脑最突出处一圈")
                }

                else -> {
                    TextInput(
                        label = entry.title,
                        value = note,
                        placeholder = "记点什么？例如 第一次翻身",
                        singleLine = false,
                        onChange = { note = it },
                    )
                }
            }
        }

        // 日期 + 时间
        Column(
            Modifier.fillMaxWidth().cardStyle(padding = 14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            DateField(label = if (isGrowth) "测量日期" else "日期", date = date, onDate = { date = it })
            if (!isGrowth) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    NumberInput("时", hour, unit = "点", modifier = Modifier.weight(1f)) { hour = it }
                    NumberInput("分", minute, unit = "分", modifier = Modifier.weight(1f)) { minute = it }
                }
            }
        }

        // 备注（喂药/记事本的正文已经在上面填过，不再重复一个备注框）
        if (entry.kind !in listOf("custom", "medicine", "notebook")) {
            Column(Modifier.fillMaxWidth().cardStyle(padding = 14.dp)) {
                TextInput(
                    label = "备注（可选）",
                    value = note,
                    placeholder = "想到什么记什么",
                    onChange = { note = it },
                )
            }
        }

        PrimaryButton(text = "保存") { save() }
    }
}

// MARK: - 小工具

private val classicBreastMinutes = listOf(5.0, 10.0, 15.0, 20.0, 30.0, 40.0)

private fun kindOf(entryKind: String): FeedLog.Kind = when (entryKind) {
    "bottle" -> FeedLog.Kind.BOTTLE
    "breast" -> FeedLog.Kind.BREAST
    "pumping" -> FeedLog.Kind.PUMPING
    "storage" -> FeedLog.Kind.STORAGE
    "sleep" -> FeedLog.Kind.SLEEP
    "diaper" -> FeedLog.Kind.DIAPER
    "solid" -> FeedLog.Kind.SOLID
    "supplement" -> FeedLog.Kind.SUPPLEMENT
    "medicine" -> FeedLog.Kind.MEDICINE
    "temp" -> FeedLog.Kind.TEMP
    "notebook" -> FeedLog.Kind.NOTEBOOK
    else -> FeedLog.Kind.CUSTOM
}

private fun kindHint(kind: String): String = when (kind) {
    "bottle" -> "记录这一顿的奶量与奶粉/人奶"
    "pumping" -> "记录吸出来的奶量"
    "storage" -> "记录存起来的奶量与方式"
    "breast" -> "记录亲喂的侧别与时长"
    "sleep" -> "记录这一觉的时长"
    "diaper" -> "记录这次尿布情况"
    "solid" -> "记录今天吃了什么"
    "supplement" -> "记录补剂与剂量"
    "medicine" -> "记录吃了什么药、多少、几点"
    "temp" -> "记录一次体温"
    "notebook" -> "记录异常情况和处理"
    "weight" -> "记录体重"
    "height" -> "记录身高"
    "head" -> "记录头围"
    else -> "随手记一笔"
}

@Composable
private fun ChipRow(labels: List<String>, isSelected: (Int) -> Boolean, onSelect: (Int) -> Unit) {
    Row(
        Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        labels.forEachIndexed { index, label ->
            val selected = isSelected(index)
            Box(
                Modifier.clip(CapsuleShape)
                    .background(if (selected) Palette.pinkDeep else Palette.purpleTint)
                    .clickable { onSelect(index) }
                    .padding(horizontal = 13.dp, vertical = 7.dp),
            ) {
                Text(
                    label, fontSize = 12.5.sp,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (selected) Color.White else Palette.ink2,
                )
            }
        }
    }
}

@Composable
private fun ToggleChip(text: String, selected: Boolean, onClick: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier.clip(CapsuleShape)
                .background(if (selected) Palette.pinkDeep else Palette.card)
                .clickable { onClick() }
                .padding(horizontal = 12.dp, vertical = 6.dp),
        ) {
            Text(
                if (selected) "✓ $text" else text,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (selected) Color.White else Palette.subtle,
            )
        }
    }
}

@Composable
private fun TempHint(text: String, color: Color, bg: Color) {
    Text(
        text, fontSize = 12.5.sp, color = color, lineHeight = 18.sp,
        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(bg).padding(12.dp),
    )
}
