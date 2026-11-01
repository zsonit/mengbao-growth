package com.zsonit.mengbao.data

import com.zsonit.mengbao.model.AppSettings
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.FeedLog
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * 首页顶部「AI 分析」卡（本地规则引擎，不联网）。与 iOS `AISuggest.swift` 规则一致。
 */
data class AISuggestion(
    val title: String,
    val body: String,
    val tone: Tone = Tone.INFO,
    val action: Action = Action.None,
    val actionTitle: String = "去记录 →",
) {
    enum class Tone(val emoji: String) {
        INFO("🤖"), OK("😊"), WARN("⚠️"), BAD("🚨"),
    }

    sealed interface Action {
        /** 打开某个快捷入口：weight / bottle / temp ... */
        data class Entry(val id: String) : Action
        data object Vaccine : Action
        data object Growth : Action
        data object None : Action
    }
}

object AISuggest {

    fun card(child: Child, settings: AppSettings, today: LocalDate = LocalDate.now()): AISuggestion {
        val feedOn = settings.showFeed

        // 1) 体温异常优先
        val recentTemp = child.feeds
            .filter { it.kind == FeedLog.Kind.TEMP && it.value != null }
            .filter { !it.date.isBefore(today.minusDays(1)) }
            .maxByOrNull { it.time ?: java.time.LocalTime.MIN }
        val temp = recentTemp?.value
        if (temp != null) {
            if (temp >= 38.5) {
                return AISuggestion(
                    title = String.format("体温 %.1f℃，建议就医", temp),
                    body = "宝宝体温已经超过 38.5℃，如果持续不退或精神差，请尽快去医院，并把这次体温记下来便于医生判断。",
                    tone = AISuggestion.Tone.BAD,
                    action = AISuggestion.Action.Entry("temp"),
                    actionTitle = "再测一次 →",
                )
            }
            if (temp >= 37.3) {
                return AISuggestion(
                    title = String.format("体温偏高 %.1f℃", temp),
                    body = "先别急着用药，多喝水、少穿一点、隔 1 小时复测。如果继续升高或伴随哭闹嗜睡，及时就医。",
                    tone = AISuggestion.Tone.WARN,
                    action = AISuggestion.Action.Entry("temp"),
                    actionTitle = "复测 →",
                )
            }
        }

        // 2) 没有生长记录
        if (child.records.isEmpty()) {
            return AISuggestion(
                title = "缺少身高体重哦",
                body = "补上身高体重，AI 才能依据国家标准动态评估宝宝的生长情况。量一次只要两分钟。",
                tone = AISuggestion.Tone.INFO,
                action = AISuggestion.Action.Entry("weight"),
            )
        }

        // 3) 从没记过体重
        if (child.records.all { it.weight == null }) {
            return AISuggestion(
                title = "缺少体重数据",
                body = "有了体重才能算出身高体重比和百分位，AI 也才能判断长得好不好。",
                tone = AISuggestion.Tone.INFO,
                action = AISuggestion.Action.Entry("weight"),
            )
        }

        // 4) 距上次测量太久
        child.latestRecord?.let { last ->
            val days = ChronoUnit.DAYS.between(last.date, today).toInt()
            if (days >= 30) {
                return AISuggestion(
                    title = "已经 $days 天没量了",
                    body = "0-3 岁建议每月量一次身高体重。今天量一次，就能看到这段时间长了多少。",
                    tone = AISuggestion.Tone.WARN,
                    action = AISuggestion.Action.Entry("weight"),
                    actionTitle = "今天量一次 →",
                )
            }
        }

        // 5) 疫苗到期
        if (settings.showShot) {
            val due = GrowthMath.schedule(child).filter { it.status == Dose.Status.DUE }
            val first = due.firstOrNull()
            if (first != null) {
                return AISuggestion(
                    title = "${due.size} 剂疫苗已到期",
                    body = "最早一针是 ${first.ageLabel} 的 ${first.vaccine.name}，已经超过建议接种时间，尽快去补种。",
                    tone = AISuggestion.Tone.WARN,
                    action = AISuggestion.Action.Vaccine,
                    actionTitle = "看疫苗 →",
                )
            }
        }

        // 6) 今天还没有喂养记录
        if (feedOn) {
            val todayFeeds = child.feeds.filter { it.date == today && it.kind != FeedLog.Kind.TEMP }
            val months = ChronoUnit.MONTHS.between(child.birthDate, today)
            if (todayFeeds.isEmpty() && months < 24) {
                return AISuggestion(
                    title = "今天还没有记录",
                    body = "点右下角麦克风说一句「喝了 150 毫升奶」，或者直接点下面的 + 号，比打字快。",
                    tone = AISuggestion.Tone.INFO,
                    action = AISuggestion.Action.Entry("bottle"),
                    actionTitle = "记一条 →",
                )
            }
        }

        // 7) 默认：发育评估
        child.latestRecord?.let { last ->
            val e = GrowthMath.evaluate(child, last)
            val pieces = mutableListOf<String>()
            e.heightPercentile?.let { pieces.add("身高" + GrowthMath.percentileLabel(it)) }
            e.weightPercentile?.let { pieces.add("体重" + GrowthMath.percentileLabel(it)) }
            e.bmi?.let { pieces.add(String.format("BMI %.1f", it)) }
            val level = e.heightLevel?.label ?: "正常范围"
            return AISuggestion(
                title = "发育评估：$level",
                body = (if (pieces.isEmpty()) "最近一次测量" else pieces.joinToString(" · ")) +
                    "，整体在正常范围内。保持规律记录，趋势比单次数字更重要。",
                tone = if (e.heightLevel?.tone == LevelTone.BAD) AISuggestion.Tone.WARN else AISuggestion.Tone.OK,
                action = AISuggestion.Action.Growth,
                actionTitle = "看曲线 →",
            )
        }

        return AISuggestion(
            title = "开始记录吧",
            body = "每天记一条喂养，每月量一次身高体重，数据积累起来才看得出成长曲线。",
            tone = AISuggestion.Tone.INFO,
            action = AISuggestion.Action.Entry("bottle"),
        )
    }
}
