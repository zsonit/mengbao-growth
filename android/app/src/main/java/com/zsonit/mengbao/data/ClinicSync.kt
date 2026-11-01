package com.zsonit.mengbao.data

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * 一键同步广东省全省接种门诊。
 *
 * 数据源：广东省疾控「粤苗」官方 H5 的公开接口 getAllLocation.action（免登录）：
 *  - 不带 opType：返回下一级行政区（省→21 地市→县区）
 *  - opType=6&type=2&areaId=<县区码>：返回该区全部接种门诊（名称/地址/电话/经纬度）
 * 结果合并去重后存 SharedPreferences，重启后仍在。
 */
object ClinicSync {

    private const val API = "https://ymapp.cdcp.org.cn/nipisgd/parent-app/getAllLocation.action"
    private const val PREFS = "clinic_sync"
    private const val KEY_LIST = "clinics_json"
    private const val KEY_TIME = "synced_at"
    private const val KEY_PROVINCE = "广东省"

    /** 一次同步的进度 */
    data class Progress(val phase: String, val done: Int, val total: Int)

    fun lastSyncedAt(context: Context): Long =
        prefs(context).getLong(KEY_TIME, 0L)

    fun syncedCount(context: Context): Int =
        prefs(context).getInt("count", 0)

    /** 读取已同步的门诊（与内置名录合并前调用） */
    fun loadSynced(context: Context): List<Clinic> {
        val json = prefs(context).getString(KEY_LIST, null) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(json)
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.optJSONObject(i) ?: return@mapNotNull null
                Clinic(
                    name = o.optString("name"),
                    city = o.optString("city"),
                    district = o.optString("district"),
                    address = o.optString("address"),
                    phone = o.optString("phone"),
                    hours = "",
                    vaccines = "",
                    note = "粤苗官方名单",
                    tag = "官方同步",
                    scope = "",
                    lat = o.optDouble("lat", 0.0),
                    lng = o.optDouble("lng", 0.0),
                    star = false,
                )
            }
        }.getOrDefault(emptyList())
    }

    /**
     * 同步全省：省→市→（必要时下钻到镇街）→门诊。在 IO 线程调用，
     * 通过 onProgress 回报进度。策略：先查本节点门诊，结果太少（如东莞只有市 CDC）再递归下级。
     * @return 同步到的门诊总数
     */
    fun syncAll(
        context: Context,
        onProgress: (Progress) -> Unit,
    ): Result<Int> = runCatching {
        var done = 0
        fun progress(phase: String) {
            done++
            onProgress(Progress(phase, done, 0))
        }

        val cities = fetchAreas(null).filter { it.areaId.startsWith("44") }   // 广东省 21 地市
        val merged = LinkedHashMap<String, Clinic>()

        fun walk(areaId: String, city: String, district: String): List<Clinic> {
            progress(if (district.isEmpty()) "正在同步 $city" else "$city $district")
            val list = fetchClinics(areaId, city, district)
            if (list.size >= 3) return list
            // 结果太少：可能是有下辖镇街的地市（如东莞），递归下级
            val children = fetchAreas(areaId)
            if (children.isEmpty()) return list
            val all = mutableListOf<Clinic>()
            for (child in children) {
                all += walk(child.areaId, city, child.name)
            }
            return all
        }

        for (city in cities) {
            for (c in walk(city.areaId, city.name, "")) {
                merged.putIfAbsent(c.name + "@" + c.address, c)
            }
        }

        val arr = JSONArray()
        merged.values.forEach { c ->
            arr.put(
                JSONObject()
                    .put("name", c.name)
                    .put("city", c.city)
                    .put("district", c.district)
                    .put("address", c.address)
                    .put("phone", c.phone)
                    .put("lat", c.lat)
                    .put("lng", c.lng),
            )
        }
        prefs(context).edit()
            .putString(KEY_LIST, arr.toString())
            .putInt("count", merged.size)
            .putLong(KEY_TIME, System.currentTimeMillis())
            .apply()
        merged.size
    }

    // ---- 数据结构 ----

    private data class Area(val name: String, val areaId: String, val parentId: String? = null)

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // ---- 网络层 ----

    private fun post(form: String): JSONObject {
        var lastError: Exception? = null
        repeat(2) { attempt ->
            try {
                val conn = URL(API).openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.connectTimeout = 15000
                conn.readTimeout = 20000
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                conn.setRequestProperty("X-Requested-With", "XMLHttpRequest")
                conn.outputStream.use { it.write(form.toByteArray()) }
                val body = conn.inputStream.bufferedReader().use { it.readText() }
                conn.disconnect()
                val obj = JSONObject(body)
                if (obj.optString("statusCode") == "300" && attempt == 0) {
                    // 偶发限流，稍等重试一次
                    Thread.sleep(400)
                } else {
                    return obj
                }
            } catch (e: Exception) {
                lastError = e
                if (attempt == 1) throw e
                Thread.sleep(600)
            }
        }
        throw lastError ?: IllegalStateException("请求失败")
    }

    /** 不带 opType：拿下级行政区。areaId 为 null 时拿全省地市。 */
    private fun fetchAreas(areaId: String?): List<Area> {
        val form = buildString {
            append("appType=2")
            if (areaId != null) append("&areaId=").append(URLEncoder.encode(areaId, "UTF-8"))
        }
        val obj = post(form)
        val arr = obj.optJSONArray("message") ?: return emptyList()
        return (0 until arr.length()).mapNotNull { i ->
            val o = arr.optJSONObject(i) ?: return@mapNotNull null
            val name = o.optString("AreaName").replace(Regex("\\s+"), "")
            if (name.isEmpty()) null else Area(name, o.optString("areaId"))
        }
    }

    /** opType=6：拿某区的接种门诊（含经纬度） */
    private fun fetchClinics(areaId: String, city: String, district: String): List<Clinic> {
        val form = "appType=2&opType=6&type=2&areaId=" + URLEncoder.encode(areaId, "UTF-8") + "&organname="
        val obj = post(form)
        val arr = obj.optJSONArray("message") ?: return emptyList()
        return (0 until arr.length()).mapNotNull { i ->
            val o = arr.optJSONObject(i) ?: return@mapNotNull null
            val name = o.optString("organName").trim()
            if (name.isEmpty()) return@mapNotNull null
            val lat = o.optDouble("mapy", 0.0).let { if (it.isNaN()) 0.0 else it }
            val lng = o.optDouble("mapx", 0.0).let { if (it.isNaN()) 0.0 else it }
            Clinic(
                name = name,
                city = city.ifEmpty { KEY_PROVINCE },
                district = district,
                address = o.optString("address").trim(),
                phone = o.optString("phone").trim(),
                hours = "",
                vaccines = "",
                note = "粤苗官方名单",
                tag = "官方同步",
                scope = "",
                lat = lat,
                lng = lng,
                star = false,
            )
        }
    }
}
