package com.zsonit.mengbao.ui

/** 页面路由（与 iOS 的 NavigationStack 一一对应） */
object Routes {
    const val HOME = "home"
    const val FEED = "feed"
    const val VACCINE = "vaccine"
    const val PROFILE = "profile"

    const val GROWTH = "growth"
    const val HISTORY = "history"
    const val RECORD_EDITOR = "record"
    const val KIDS = "kids"
    const val KID_EDITOR = "kid"
    const val SIZE = "size"
    const val TEETH = "teeth"   // 换牙档案
    const val TODO = "todo"
    const val STAGE = "stage"
    const val QUICK_ENTRIES = "quick_entries"
    const val CLINICS = "clinics"
    const val CLINIC_DETAIL = "clinic"
    const val YAMIAO = "yamiao"   // 粤苗官方接种门诊查询（内嵌 H5）
    const val NEARBY = "nearby"   // 附近接种门诊（自带地图 + 距离排序）
    const val TRENDS = "trends"   // 成长趋势（9 项曲线）
    const val DAY_HISTORY = "day_history"   // 某天的明细（精确到几点几分）
    const val AI = "ai"   // AI 语音助手

    fun recordEditor(recordId: String? = null) = "$RECORD_EDITOR/${recordId ?: "new"}"
    fun kidEditor(childId: String? = null) = "$KID_EDITOR/${childId ?: "new"}"
    fun clinicDetail(clinicId: String) = "$CLINIC_DETAIL/${android.net.Uri.encode(clinicId)}"
    fun dayHistory(date: String, metric: String = "all") =
        "$DAY_HISTORY/${android.net.Uri.encode(date)}/${android.net.Uri.encode(metric)}"
}
