package com.zsonit.mengbao.data

import com.zsonit.mengbao.model.AppSettings
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.GrowthRecord
import com.zsonit.mengbao.model.Sex
import java.time.LocalDate
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sqrt

// MARK: - 指标

enum class GrowthMetric(val label: String, val unit: String, val decimals: Int) {
    HEIGHT("身高", "cm", 0),
    WEIGHT("体重", "kg", 1),
    BMI("BMI", "", 1),
}

// MARK: - 评估等级

enum class LevelTone { OK, WARN, BAD }

data class GrowthLevel(val label: String, val tone: LevelTone, val desc: String)

data class Evaluation(
    val months: Int,
    var heightPercentile: Double? = null,
    var weightPercentile: Double? = null,
    var bmi: Double? = null,
    var bmiPercentile: Double? = null,
    var heightLevel: GrowthLevel? = null,
    var bmiLevel: GrowthLevel? = null,
    var source: String = "",
) {
    val isComplete: Boolean get() = heightPercentile != null && weightPercentile != null
}

// MARK: - 接种

data class Dose(
    val key: String,
    val months: Int,
    val ageLabel: String,
    val dueDate: LocalDate,
    val vaccine: Vaccine,
    val status: Status,
    val doneDate: LocalDate? = null,
) {
    enum class Status(val label: String) {
        DONE("已接种"), DUE("已到期"), SOON("近期接种"), PENDING("待接种"), LOCKED("已锁定")
    }
}

// MARK: - 尺码

data class ShoeSize(
    var cn: Int? = null,
    var eu: Int? = null,
    var inner: Double? = null,
    var top: String? = null,
    var pant: String? = null,
    var hip: String? = null,
)

// MARK: - 生长计算

object GrowthMath {

    val zValues = listOf(-1.8808, -1.0364, 0.0, 1.0364, 1.8808)
    val percentiles = listOf(3.0, 15.0, 50.0, 85.0, 97.0)

    // MARK: 日期与月龄

    fun ageMonths(birth: LocalDate, date: LocalDate = LocalDate.now()): Int =
        max(0, ChronoUnit.MONTHS.between(birth, date).toInt())

    fun ageText(birth: LocalDate, date: LocalDate = LocalDate.now()): String {
        if (date < birth) return "未出生"
        var years = ChronoUnit.YEARS.between(birth, date).toInt()
        var cursor = birth.plusYears(years.toLong())
        var months = ChronoUnit.MONTHS.between(cursor, date).toInt()
        cursor = cursor.plusMonths(months.toLong())
        val days = ChronoUnit.DAYS.between(cursor, date).toInt()
        if (years > 0) return if (months > 0) "$years 岁 $months 个月" else "$years 岁"
        if (months > 0) return if (days > 0) "$months 个月 $days 天" else "$months 个月"
        return "$days 天"
    }

    fun daysToBirthday(birth: LocalDate, today: LocalDate = LocalDate.now()): Int {
        var next = birth.withYear(today.year)
        if (next < today) next = birth.withYear(today.year + 1)
        return ChronoUnit.DAYS.between(today, next).toInt()
    }

    fun daysSince(date: LocalDate): Int = ChronoUnit.DAYS.between(date, LocalDate.now()).toInt()

    // MARK: 插值

    fun interp(rows: List<List<Double>>, x: Double, column: Int): Double {
        val first = rows.firstOrNull() ?: return 0.0
        val last = rows.lastOrNull() ?: return 0.0
        if (x <= first[0]) return first[column]
        if (x >= last[0]) return last[column]
        for (i in 0 until rows.size - 1) {
            val a = rows[i]
            val b = rows[i + 1]
            if (x >= a[0] && x <= b[0]) {
                val span = b[0] - a[0]
                val t = if (span == 0.0) 0.0 else (x - a[0]) / span
                return a[column] + t * (b[column] - a[column])
            }
        }
        return last[column]
    }

    fun lmsRow(rows: List<LMSRow>, months: Double): LMSRow {
        val first = rows.firstOrNull() ?: return LMSRow(months, 0.0, 1.0, 0.1)
        val last = rows.lastOrNull() ?: return LMSRow(months, 0.0, 1.0, 0.1)
        if (months <= first.months) return first
        if (months >= last.months) return last
        for (i in 0 until rows.size - 1) {
            val a = rows[i]
            val b = rows[i + 1]
            if (months >= a.months && months <= b.months) {
                val t = (months - a.months) / (b.months - a.months)
                return LMSRow(
                    months,
                    a.l + t * (b.l - a.l),
                    a.m + t * (b.m - a.m),
                    a.s + t * (b.s - a.s),
                )
            }
        }
        return last
    }

    fun valueAtZ(z: Double, row: LMSRow): Double {
        if (abs(row.l) < 0.000001) return row.m * exp(row.s * z)
        val base = 1 + row.l * row.s * z
        if (base <= 0) return row.m
        return row.m * base.pow(1 / row.l)
    }

    // MARK: 误差函数（正态分布换算）

    private fun erf(x: Double): Double {
        val sign = if (x < 0) -1.0 else 1.0
        val ax = abs(x)
        val p = 0.3275911
        val a1 = 0.254829592
        val a2 = -0.284496736
        val a3 = 1.421413741
        val a4 = -1.453152027
        val a5 = 1.061405429
        val t = 1 / (1 + p * ax)
        val y = 1 - (((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t * exp(-ax * ax))
        return sign * y
    }

    fun percentileFromZ(z: Double): Double {
        val p = 0.5 * (1 + erf(z / sqrt(2.0))) * 100
        return min(99.9, max(0.1, p))
    }

    // MARK: 参考带

    fun bmiMedian(sex: Sex, months: Double): Double {
        val m = min(max(months, 0.0), 60.0)
        val h = lmsRow(if (sex == Sex.BOY) Standards.boyLMSHeight else Standards.girlLMSHeight, m).m
        val w = lmsRow(if (sex == Sex.BOY) Standards.boyLMSWeight else Standards.girlLMSWeight, m).m
        return w / (h / 100).pow(2)
    }

    fun refBands(sex: Sex, metric: GrowthMetric, months: Int): List<Double> {
        val m = months.toDouble()

        if (metric == GrowthMetric.BMI) {
            if (months <= 60) {
                val median = bmiMedian(sex, m)
                val cv = 0.085 + 0.015 * min(1.0, m / 60)
                return zValues.map { median * (1 + cv * it) }
            }
            if (months <= 84) {
                val median = bmiMedian(sex, 60.0)
                return zValues.map { median * (1 + 0.10 * it) }
            }
            val years = min(18.0, max(7.0, m / 12))
            val rows = if (sex == Sex.BOY) Standards.boyBMI7to18 else Standards.girlBMI7to18
            val median = interp(rows, years, 1)
            val cv = 0.11 + 0.02 * min(1.0, max(0.0, (m - 84) / 132))
            return zValues.map { max(9.0, median * (1 + cv * it)) }
        }

        // 身高 / 体重：首都儿科研究所《0~18岁儿童青少年身高、体重百分位数值表》（李辉），
        // 半年/年点线性插值到月；女孩 10岁6月~11岁9月 用参考 App 精确值覆盖
        if (sex == Sex.GIRL && metric == GrowthMetric.HEIGHT) {
            Standards.liGirlHeightOverride[months]?.let { return it }
        }
        if (sex == Sex.GIRL && metric == GrowthMetric.WEIGHT) {
            Standards.liGirlWeightOverride[months]?.let { return it }
        }

        val table = if (metric == GrowthMetric.HEIGHT) Standards.liHeightStd else Standards.liWeightStd
        val row = liRow(table, months)
        val p3 = row[0]
        val p50 = row[3]
        val p97 = row[6]
        val sigma = (p97 - p3) / 3.757
        return listOf(p3, p50 - 1.036 * sigma, p50, p50 + 1.036 * sigma, p97)
    }

    /**
     * 曲线与评估用的百分位带（恢复 v2.10.29 的经典算法：0-5 岁 WHO LMS、5-7 岁中位数×CV、7-18 岁等级表）。
     * 数据表格仍用 refBands（首都儿科研究所 0~18 岁标准），两者互不影响。
     */
    fun chartBands(sex: Sex, metric: GrowthMetric, months: Int): List<Double> {
        val m = months.toDouble()

        if (months <= 60) {
            if (metric == GrowthMetric.BMI) {
                val median = bmiMedian(sex, m)
                val cv = 0.085 + 0.015 * min(1.0, m / 60)
                return zValues.map { median * (1 + cv * it) }
            }
            val rows = when (metric) {
                GrowthMetric.HEIGHT -> if (sex == Sex.BOY) Standards.boyLMSHeight else Standards.girlLMSHeight
                else -> if (sex == Sex.BOY) Standards.boyLMSWeight else Standards.girlLMSWeight
            }
            val row = lmsRow(rows, m)
            return zValues.map { valueAtZ(it, row) }
        }

        if (months <= 84) {
            when (metric) {
                GrowthMetric.HEIGHT -> {
                    val median = interp(
                        if (sex == Sex.BOY) Standards.boyMedianHeight36to84 else Standards.girlMedianHeight36to84, m, 1,
                    )
                    return zValues.map { median * (1 + 0.042 * it) }
                }
                GrowthMetric.WEIGHT -> {
                    val median = interp(
                        if (sex == Sex.BOY) Standards.boyMedianWeight36to84 else Standards.girlMedianWeight36to84, m, 1,
                    )
                    return zValues.map { median * (1 + 0.155 * it) }
                }
                GrowthMetric.BMI -> {
                    val median = bmiMedian(sex, 60.0)
                    return zValues.map { median * (1 + 0.10 * it) }
                }
            }
        }

        val years = min(18.0, max(7.0, m / 12))
        return when (metric) {
            GrowthMetric.HEIGHT -> {
                val rows = if (sex == Sex.BOY) Standards.boyHeight7to18 else Standards.girlHeight7to18
                (1..5).map { interp(rows, years, it) }
            }
            GrowthMetric.WEIGHT -> {
                val rows = if (sex == Sex.BOY) Standards.boyWeight7to18 else Standards.girlWeight7to18
                val median = interp(rows, years, 1)
                val cv = 0.16 + 0.06 * min(1.0, max(0.0, (m - 84) / 132))
                zValues.map { median * (1 + cv * it) }
            }
            GrowthMetric.BMI -> {
                val rows = if (sex == Sex.BOY) Standards.boyBMI7to18 else Standards.girlBMI7to18
                val median = interp(rows, years, 1)
                val cv = 0.11 + 0.02 * min(1.0, max(0.0, (m - 84) / 132))
                zValues.map { max(9.0, median * (1 + cv * it)) }
            }
        }
    }

    /// 李辉表按月龄线性插值，返回 7 列 [P3, P10, P25, P50, P75, P90, P97/95]
    fun liRow(table: List<List<Double>>, months: Int): List<Double> {
        var prev = table.first()
        var next = table.last()
        for (r in table) {
            if (r[0] <= months) prev = r
            if (r[0] > months) { next = r; break }
        }
        val m = months.toDouble()
        if (next[0] <= prev[0] || m <= prev[0]) return prev.drop(1)
        val t = min(1.0, (m - prev[0]) / (next[0] - prev[0]))
        return (1..7).map { i -> prev[i] + (next[i] - prev[i]) * t }
    }

    fun percentile(sex: Sex, metric: GrowthMetric, months: Int, value: Double): Double {
        val bands = chartBands(sex, metric, months)
        if (value <= bands[0]) return min(3.0, max(0.1, value / bands[0] * 3))
        if (value >= bands[4]) return min(99.9, 97 + (value - bands[4]) / bands[4] * 30)
        for (i in 0 until 4) {
            if (value >= bands[i] && value <= bands[i + 1]) {
                val span = bands[i + 1] - bands[i]
                val t = if (span == 0.0) 0.0 else (value - bands[i]) / span
                return percentiles[i] + t * (percentiles[i + 1] - percentiles[i])
            }
        }
        return 50.0
    }

    fun level(percentile: Double): GrowthLevel = when {
        percentile <= 3 -> GrowthLevel("偏低", LevelTone.BAD, "处于同龄参考范围低位，建议到儿童保健科评估生长速度与营养状况。")
        percentile <= 15 -> GrowthLevel("中下", LevelTone.WARN, "略低于同龄中位水平，属正常偏低区间，重点看生长速度是否稳定。")
        percentile <= 85 -> GrowthLevel("中等", LevelTone.OK, "处于同龄中位水平，属通常正常区间。")
        percentile <= 97 -> GrowthLevel("中上", LevelTone.OK, "高于同龄中位水平，属通常正常区间。")
        else -> GrowthLevel("偏高", LevelTone.WARN, "处于同龄参考范围高位，若伴随早发育迹象可咨询儿科。")
    }

    fun percentileLabel(p: Double): String =
        if (p < 1) String.format(Locale.US, "P%.1f", p) else "P${p.roundToInt()}"

    fun bmiValue(height: Double, weight: Double): Double {
        if (height <= 0) return 0.0
        return (weight / (height / 100).pow(2) * 10).roundToInt() / 10.0
    }

    // MARK: 单次评估

    fun evaluate(child: Child, record: GrowthRecord): Evaluation {
        val months = ageMonths(child.birthDate, record.date)
        val source = when {
            months <= 60 -> "WHO 儿童生长标准（简化 LMS）"
            months <= 84 -> "中国 7 岁以下儿童生长发育参照标准"
            else -> "WS/T 423 身高发育等级评价"
        }
        val e = Evaluation(months = months, source = source)

        record.height?.takeIf { it > 0 }?.let { h ->
            val p = percentile(child.sex, GrowthMetric.HEIGHT, months, h)
            e.heightPercentile = p
            e.heightLevel = level(p)
        }
        record.weight?.takeIf { it > 0 }?.let { w ->
            e.weightPercentile = percentile(child.sex, GrowthMetric.WEIGHT, months, w)
        }
        val h = record.height
        val w = record.weight
        if (h != null && w != null && h > 0 && w > 0) {
            val bmi = bmiValue(h, w)
            val p = percentile(child.sex, GrowthMetric.BMI, months, bmi)
            e.bmi = bmi
            e.bmiPercentile = p
            e.bmiLevel = level(p)
        }
        return e
    }

    // MARK: 生长速度

    data class Velocity(val delta: Double, val days: Int, val perYear: Double)

    fun velocity(child: Child): Velocity? {
        val recs = child.sortedRecords.filter { it.height != null }
        if (recs.size < 2) return null
        val last = recs[recs.size - 1]
        val prev = recs[recs.size - 2]
        val h1 = last.height ?: return null
        val h2 = prev.height ?: return null
        val days = ChronoUnit.DAYS.between(prev.date, last.date).toInt()
        if (days < 20) return null
        return Velocity(h1 - h2, days, (h1 - h2) / days * 365)
    }

    fun velocityComment(child: Child, perYear: Double): String {
        val months = ageMonths(child.birthDate)
        val baseline = when {
            months < 12 -> 12.0
            months < 36 -> 7.0
            months < 60 -> 5.0
            months < 120 -> 4.0
            else -> 3.0
        }
        if (perYear < baseline * 0.6) return "偏慢，建议关注"
        if (perYear > baseline * 2.2) return "偏快，注意记录"
        return "正常范围"
    }

    // MARK: 身高预测

    data class HeightPrediction(val value: Double, val low: Double, val high: Double, val method: String)

    fun predictedHeight(child: Child, record: GrowthRecord, settings: AppSettings): HeightPrediction? {
        val h = record.height?.takeIf { it > 0 } ?: return null
        val f = settings.fatherHeight
        val m = settings.motherHeight
        if (f != null && m != null && f > 0 && m > 0) {
            val target = if (child.sex == Sex.GIRL) (f + m - 13) / 2 else (f + m + 13) / 2
            return HeightPrediction(target, target - 5, target + 5, "靶身高法（父母身高）")
        }
        val months = ageMonths(child.birthDate, record.date)
        val p = percentile(child.sex, GrowthMetric.HEIGHT, months, h)
        val adult = refBands(child.sex, GrowthMetric.HEIGHT, 216)
        val base = when {
            p < 15 -> adult[0] + (adult[1] - adult[0]) * (p - 3) / 12
            p < 50 -> adult[1] + (adult[2] - adult[1]) * (p - 15) / 35
            p < 85 -> adult[2] + (adult[3] - adult[2]) * (p - 50) / 35
            else -> adult[3] + (adult[4] - adult[3]) * (p - 85) / 12
        }
        return HeightPrediction(base, base - 5, base + 5, "当前百分位外推（未填父母身高）")
    }

    // MARK: 接种计划

    val totalDoses: Int get() = Standards.vaccineByAge.values.sumOf { it.size }

    fun schedule(child: Child): List<Dose> {
        val currentMonths = ageMonths(child.birthDate)
        val list = mutableListOf<Dose>()
        // 程序表剂次调整后的旧记录兼容：老 key 打过勾的自动迁移到新 key
        val legacyKeys = mapOf(
            "6|DTaP|第 3 剂" to listOf("6|DTaP|第 4 剂", "5|DTaP|第 3 剂"),
            "72|DT|第 5 剂" to listOf("72|DTaP|第 5 剂"),
        )
        for ((label, months) in Standards.vaccineAges) {
            val dueDate = child.birthDate.plusMonths(months.toLong())
            for (v in Standards.vaccineByAge[months] ?: emptyList()) {
                val key = "$months|${v.code}|${v.dose}"
                val done = child.shots[key] ?: legacyKeys[key].orEmpty().firstNotNullOfOrNull { child.shots[it] }
                val status = when {
                    done != null -> Dose.Status.DONE
                    months <= currentMonths -> Dose.Status.DUE
                    months - currentMonths <= 2 -> Dose.Status.SOON
                    else -> Dose.Status.PENDING
                }
                list.add(Dose(key, months, label, dueDate, v, status, done?.date))
            }
        }

        // 13 岁女生免费 HPV（双价，两剂间隔 6 个月；男生不排）
        if (child.sex == Sex.GIRL) {
            listOf(156, 162).forEachIndexed { idx, months ->
                val dueDate = child.birthDate.plusMonths(months.toLong())
                val key = "$months|HPV2|第 ${idx + 1} 剂"
                val done = child.shots[key]
                val status = when {
                    done != null -> Dose.Status.DONE
                    months <= currentMonths -> Dose.Status.DUE
                    months - currentMonths <= 2 -> Dose.Status.SOON
                    else -> Dose.Status.PENDING
                }
                val vaccine = Vaccine(
                    code = "HPV2",
                    name = "双价人乳头瘤病毒疫苗",
                    dose = "第 ${idx + 1} 剂",
                    route = "肌内注射",
                    site = "上臂外侧三角肌",
                    note = if (idx == 0)
                        "适龄女生免费接种（以当地政策为准）；两剂间隔 6 个月，既往已完成 HPV 全程接种者无需重复接种。"
                    else
                        "第 2 剂与第 1 剂间隔 6 个月。",
                )
                list.add(Dose(key, months, ageTextForMonths(months), dueDate, vaccine, status, done?.date))
            }
        }

        // 自选（自费）疫苗：勾选后并入同一份日程，key 以 "opt|" 开头便于区分
        for (oid in child.optVaccines ?: emptyList()) {
            val opt = Standards.optionalById[oid] ?: continue
            opt.months.forEachIndexed { idx, months ->
                val key = "opt|$oid|$idx|$months"
                val done = child.shots[key]
                val status = when {
                    done != null -> Dose.Status.DONE
                    months <= currentMonths -> Dose.Status.DUE
                    months - currentMonths <= 2 -> Dose.Status.SOON
                    else -> Dose.Status.PENDING
                }
                val oral = opt.name.contains("口服")
                val vaccine = Vaccine(
                    code = "OPT-${oid.uppercase()}",
                    name = opt.name,
                    dose = "第 ${idx + 1} 剂 / 共 ${opt.months.size} 剂",
                    route = if (oral) "口服" else "肌内注射",
                    site = if (oral) "口服（接种前 30 分钟避免喂奶）" else "上臂外侧三角肌 / 大腿前外侧",
                    note = "${opt.desc}。自费疫苗，参考价 ${opt.price}。是否接种请与接种医生沟通。",
                )
                list.add(Dose(key, months, ageTextForMonths(months), child.birthDate.plusMonths(months.toLong()), vaccine, status, done?.date))
            }
        }

        // 减毒活 / 灭活「二选一」：接种其一后，组内另一种自动锁定（红字提示，不能再打勾）
        val doneCodes = child.shots.keys.mapNotNull { key -> key.split("|").getOrNull(1) }.toSet()
        val locked = list.map { dose ->
            if (dose.status == Dose.Status.DONE) return@map dose
            val group = Standards.altGroupOf(dose.vaccine.code) ?: return@map dose
            val rivals = (Standards.altGroups[group] ?: emptyList()).filter { it != dose.vaccine.code }
            if (rivals.any { doneCodes.contains(it) }) {
                dose.copy(status = Dose.Status.LOCKED, doneDate = null)
            } else {
                dose
            }
        }
        return locked
    }

    /** 月龄 -> 中文年龄提示（自选疫苗的月龄不一定在标准表里） */
    fun ageTextForMonths(months: Int): String {
        Standards.vaccineAges.firstOrNull { it.second == months }?.let { return it.first }
        if (months < 12) return "$months 月龄"
        val y = months / 12
        val m = months % 12
        return if (m == 0) "$y 岁" else "$y 岁 $m 个月"
    }

    /** BMI 判定标签：<18 岁按同龄同性别百分位（偏瘦<P15 · 正常P15~P85 · 超重P85~P95 · 肥胖≥P95）；≥18 岁按中国成人标准（18.5/24/28）。返回 null 表示无法判定 */
    fun bmiJudgeLabel(ageYears: Int, bmi: Double?, percentile: Double?): String? {
        if (bmi == null || bmi <= 0) return null
        if (ageYears >= 18) {
            return when {
                bmi < 18.5 -> "偏瘦"
                bmi < 24 -> "正常"
                bmi < 28 -> "超重"
                else -> "肥胖"
            }
        }
        val p = percentile ?: return null
        return when {
            p < 15 -> "偏瘦"
            p < 85 -> "正常"
            p < 95 -> "超重"
            else -> "肥胖"
        }
    }

    fun doneCount(child: Child): Int = schedule(child).count { it.status == Dose.Status.DONE }

    // MARK: 尺码

    fun shoeSize(foot: Double?, height: Double?): ShoeSize {
        val s = ShoeSize()
        if (foot != null && foot > 0) {
            s.cn = (foot * 2 - 10).roundToInt()
            s.eu = (foot * 1.5 + 2).roundToInt()
            s.inner = ((foot + 0.8) * 10).roundToInt() / 10.0
        }
        if (height != null && height > 0) {
            val size = (height / 10).roundToInt() * 10
            s.top = "$size 码"
            s.pant = "$size 码"
            s.hip = "${(height * 0.62).roundToInt()} cm 裤长"
        }
        return s
    }

    // MARK: 阶段重点

    fun milestones(child: Child): List<String> {
        val months = ageMonths(child.birthDate)
        return Standards.milestones.firstOrNull { months <= it.first }?.second
            ?: Standards.milestones.last().second
    }

    fun dateString(date: LocalDate): String = date.format(DateTimeFormatter.ofPattern("yyyy-MM-dd"))

    fun shortDate(date: LocalDate): String = date.format(DateTimeFormatter.ofPattern("M 月 d 日"))

    /** 与 iOS `date.formatted(date: .omitted, time: .shortened)` 一致的时:分显示。 */
    fun timeText(time: LocalTime?): String =
        time?.format(DateTimeFormatter.ofPattern("HH:mm")) ?: ""

    /** 有具体时刻时只显示时:分（当天的明细），否则回落到日期。 */
    fun momentText(date: LocalDate, time: LocalTime?): String =
        if (time == null) shortDate(date) else timeText(time)

    fun isSameDay(a: LocalDate, b: LocalDate): Boolean = a == b
}
