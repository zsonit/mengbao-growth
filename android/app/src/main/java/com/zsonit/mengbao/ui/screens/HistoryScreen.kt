package com.zsonit.mengbao.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zsonit.mengbao.data.GrowthMath
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.FeedLog
import com.zsonit.mengbao.model.GrowthRecord
import com.zsonit.mengbao.model.SizeRecord
import com.zsonit.mengbao.ui.ChipLabel
import com.zsonit.mengbao.ui.EmptyHint
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.TagTone
import com.zsonit.mengbao.ui.TagView
import com.zsonit.mengbao.ui.TopBar
import com.zsonit.mengbao.ui.cardStyle
import java.time.LocalDate
import java.time.LocalTime
import java.util.Locale

// MARK: - 历史记录

private sealed interface HistoryItem {
    val date: LocalDate
    val time: LocalTime? get() = null
    val kind: String

    data class Record(val record: GrowthRecord) : HistoryItem {
        override val date: LocalDate get() = record.date
        override val kind: String get() = "生长"
    }

    data class Feed(val log: FeedLog) : HistoryItem {
        override val date: LocalDate get() = log.date
        override val time: LocalTime? get() = log.time
        override val kind: String get() = "喂养"
    }

    data class Size(val size: SizeRecord) : HistoryItem {
        override val date: LocalDate get() = size.date
        override val kind: String get() = "鞋服"
    }
}

private fun fmt1(v: Double): String = String.format(Locale.US, "%.1f", v)

@Composable
fun HistoryScreen(onBack: () -> Unit) {
    var filter by remember { mutableStateOf("全部") }
    val child = Store.current

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = "历史记录", onBack = onBack)
        if (child == null) {
            EmptyHint(text = "先添加宝宝档案")
        } else {
            HistoryContent(child, filter, onFilter = { filter = it })
        }
    }
}

@Composable
private fun HistoryContent(child: Child, filter: String, onFilter: (String) -> Unit) {
    val items = remember(child, Store.settings.showSize, Store.settings.showFeed) {
        buildList {
            addAll(child.records.map { HistoryItem.Record(it) })
            // 喂养模块隐藏后，喂养类历史（奶量/亲喂/吸奶/尿布/睡眠/辅食/补剂）一并隐藏；体温和自定义记录保留
            if (Store.settings.showFeed) {
                addAll(child.feeds.map { HistoryItem.Feed(it) })
            } else {
                addAll(child.feeds.filter { it.kind == com.zsonit.mengbao.model.FeedLog.Kind.TEMP || it.kind == com.zsonit.mengbao.model.FeedLog.Kind.CUSTOM }
                    .map { HistoryItem.Feed(it) })
            }
            if (Store.settings.showSize) addAll(child.sizes.map { HistoryItem.Size(it) })
        }.sortedWith(
            compareByDescending<HistoryItem> { it.date }
                .thenByDescending { it.time ?: LocalTime.MIN },
        )
    }
    val visible = if (filter == "全部") items else items.filter { it.kind == filter }
    val filters = if (Store.settings.showFeed) listOf("全部", "生长", "喂养", "鞋服") else listOf("全部", "生长", "鞋服")

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(child.name, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Palette.ink)
            Spacer(Modifier.weight(1f))
            Text("${visible.size} 条记录", fontSize = 12.sp, color = Palette.subtle)
        }

        Row(
            modifier = Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            filters.forEach { f ->
                ChipLabel(text = f, selected = filter == f, onClick = { onFilter(f) })
            }
        }
        Spacer(Modifier.height(10.dp))

        if (visible.isEmpty()) {
            EmptyHint(text = "该分类下还没有记录")
        } else {
            // 瓶喂/睡眠/尿布：显示已过去时间（最新一条实时计时），出现新的同类型记录后固定为间隔
            val tracked = setOf(FeedLog.Kind.BOTTLE, FeedLog.Kind.SLEEP, FeedLog.Kind.DIAPER)
            visible.forEach { item ->
                var gapNext: java.time.LocalDateTime? = null
                var showGap = false
                if (item is HistoryItem.Feed && item.log.kind in tracked) {
                    showGap = true
                    val start = item.log.date.atTime(item.log.time ?: LocalTime.MIN)
                    gapNext = child.feeds.filter { it.kind == item.log.kind && it.id != item.log.id }
                        .map { it.date.atTime(it.time ?: LocalTime.MIN) }
                        .filter { it > start }
                        .minOrNull()
                }
                HistoryItemView(item, child, gapNext, showGap, modifier = Modifier.padding(horizontal = 16.dp, vertical = 5.dp))
            }
        }
        Spacer(Modifier.height(28.dp))
    }
}

@Composable
private fun HistoryItemView(item: HistoryItem, child: Child, gapNext: java.time.LocalDateTime?, showGap: Boolean, modifier: Modifier = Modifier) {
    when (item) {
        is HistoryItem.Record -> RecordItem(item.record, child, modifier)
        is HistoryItem.Feed -> FeedItem(item.log, gapNext, showGap, modifier)
        is HistoryItem.Size -> SizeItem(item.size, modifier)
    }
}

@Composable
private fun RecordItem(record: GrowthRecord, child: Child, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth().cardStyle(padding = 14.dp, radius = 14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TagView(text = "生长", tone = TagTone.PURPLE)
            Spacer(Modifier.width(8.dp))
            Text(GrowthMath.dateString(record.date), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink2)
            Spacer(Modifier.width(6.dp))
            Text(GrowthMath.ageText(child.birthDate, record.date), fontSize = 12.sp, color = Palette.subtle)
            Spacer(Modifier.weight(1f))
            DeleteButton { Store.deleteRecord(record.id) }
        }
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            record.height?.let { Metric("身高", fmt1(it), "cm") }
            record.weight?.let { Metric("体重", fmt1(it), "kg") }
            val e = GrowthMath.evaluate(child, record)
            e.bmi?.let { Metric("BMI", fmt1(it), "") }
            record.footLength?.let { Metric("脚长", fmt1(it), "cm") }
        }
        if (record.note.isNotEmpty()) {
            Spacer(Modifier.height(4.dp))
            Text(record.note, fontSize = 12.sp, color = Palette.subtle)
        }
    }
}

@Composable
private fun Metric(name: String, value: String, unit: String) {
    Row(verticalAlignment = Alignment.Bottom, modifier = Modifier.padding(end = 14.dp)) {
        Text(name, fontSize = 11.sp, color = Palette.subtle, modifier = Modifier.padding(bottom = 2.dp))
        Spacer(Modifier.width(3.dp))
        Text(value, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
        if (unit.isNotEmpty()) {
            Spacer(Modifier.width(2.dp))
            Text(unit, fontSize = 10.sp, color = Palette.subtle, modifier = Modifier.padding(bottom = 2.dp))
        }
    }
}

@Composable
private fun FeedItem(log: FeedLog, gapNext: java.time.LocalDateTime?, showGap: Boolean, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth().cardStyle(padding = 0.dp, radius = 14.dp)) {
        Row(
            Modifier.fillMaxWidth()
                .padding(start = 14.dp, end = 6.dp, top = 14.dp, bottom = if (showGap) 6.dp else 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(log.kind.icon, fontSize = 18.sp)
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text("${log.kind.title} · ${log.summary}", fontSize = 14.sp, color = Palette.ink)
                Text("${GrowthMath.dateString(log.date)} ${GrowthMath.timeText(log.time)}".trim(), fontSize = 11.5.sp, color = Palette.subtle)
            }
            DeleteButton { Store.deleteFeed(log.id) }
        }
        if (showGap) {
            val start = log.date.atTime(log.time ?: LocalTime.MIN)
            Row(Modifier.padding(start = 14.dp, bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                if (gapNext == null) {
                    // 最新一条：实时计时
                    var now by remember(log.id) { mutableStateOf(java.time.LocalDateTime.now()) }
                    LaunchedEffect(log.id) {
                        while (true) {
                            kotlinx.coroutines.delay(30_000)
                            now = java.time.LocalDateTime.now()
                        }
                    }
                    Text("⏱", fontSize = 10.sp)
                    Spacer(Modifier.width(4.dp))
                    Text(
                        "已过去 ${gapText(java.time.Duration.between(start, now).seconds)}",
                        fontSize = 11.sp, fontWeight = FontWeight.Medium, color = Palette.purple,
                    )
                } else {
                    Text("🕒", fontSize = 10.sp)
                    Spacer(Modifier.width(4.dp))
                    Text(
                        "间隔 ${gapText(java.time.Duration.between(start, gapNext).seconds)}",
                        fontSize = 11.sp, color = Palette.subtle,
                    )
                }
            }
        }
    }
}

/** 已过去时间的友好格式 */
private fun gapText(seconds: Long): String {
    val total = seconds.coerceAtLeast(0)
    if (total < 60) return "$total 秒"
    val m = total / 60
    if (m < 60) return "$m 分钟"
    val h = m / 60
    return if (h < 48) "$h 小时 ${m % 60} 分" else "${h / 24} 天 ${h % 24} 小时"
}

@Composable
private fun SizeItem(size: SizeRecord, modifier: Modifier = Modifier) {
    val s = GrowthMath.shoeSize(size.footLength, size.height)
    Column(modifier.fillMaxWidth().cardStyle(padding = 14.dp, radius = 14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TagView(text = "鞋服", tone = TagTone.GRAY)
            Spacer(Modifier.width(8.dp))
            Text(GrowthMath.dateString(size.date), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink2)
            Spacer(Modifier.weight(1f))
            DeleteButton { Store.deleteSize(size.id) }
        }
        Spacer(Modifier.height(6.dp))
        if (s.cn != null && s.eu != null) {
            Text(
                "脚长 ${fmt1(size.footLength ?: 0.0)}cm → 中国码 ${s.cn} / 欧码 ${s.eu}",
                fontSize = 13.5.sp, color = Palette.ink,
            )
        }
        if (s.top != null && s.pant != null) {
            Text("上衣 ${s.top} · 裤子 ${s.pant}", fontSize = 13.5.sp, color = Palette.ink)
        }
        val parts = buildList {
            size.shoeSize?.let { add("穿鞋 ${it} 码") }
            size.shoeInner?.let { add("内长 ${fmt1(it)}cm") }
            size.shoulder?.let { add("肩宽 ${fmt1(it)}") }
            size.waist?.let { add("腰围 ${fmt1(it)}") }
            size.hip?.let { add("臀围 ${fmt1(it)}") }
            size.thigh?.let { add("大腿围 ${fmt1(it)}") }
            size.calf?.let { add("小腿围 ${fmt1(it)}") }
            size.topLength?.let { add("衣长 ${fmt1(it)}") }
            size.sleeve?.let { add("袖长 ${fmt1(it)}") }
            size.pantsLength?.let { add("裤长 ${fmt1(it)}") }
        }
        if (parts.isNotEmpty()) {
            Spacer(Modifier.height(2.dp))
            Text(parts.joinToString(" · "), fontSize = 12.5.sp, color = Palette.ink2)
        }
        if (size.note.isNotEmpty()) {
            Text(size.note, fontSize = 12.sp, color = Palette.subtle)
        }
    }
}

@Composable
private fun DeleteButton(onClick: () -> Unit) {
    IconButton(onClick = onClick, modifier = Modifier.height(28.dp).width(28.dp)) {
        Icon(
            Icons.Outlined.Delete, contentDescription = "删除",
            tint = Palette.bad, modifier = Modifier.height(14.dp).width(14.dp),
        )
    }
}
