package com.zsonit.mengbao.ui.screens

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.webkit.GeolocationPermissions
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.core.content.ContextCompat
import com.zsonit.mengbao.data.ClinicSync
import com.zsonit.mengbao.data.GrowthMath
import com.zsonit.mengbao.data.Standards
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.data.Clinic
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.TagTone
import com.zsonit.mengbao.ui.TagView
import com.zsonit.mengbao.ui.TopBar
import com.zsonit.mengbao.ui.cardStyle
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/** 广州天河，定位失败时的兜底中心 */
private const val FALLBACK_LAT = 23.135
private const val FALLBACK_LNG = 113.325

private fun distanceKm(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
    val r = 6371.0
    val dLat = Math.toRadians(lat2 - lat1)
    val dLng = Math.toRadians(lng2 - lng1)
    val a = sin(dLat / 2) * sin(dLat / 2) +
        cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLng / 2) * sin(dLng / 2)
    return r * 2 * atan2(sqrt(a), sqrt(1 - a))
}

private fun openAmapNav(context: Context, clinic: Clinic) {
    val name = Uri.encode(clinic.name)
    val amap = Intent(
        Intent.ACTION_VIEW,
        Uri.parse("androidamap://navi?sourceApplication=mengbao&lat=${clinic.lat}&lon=${clinic.lng}&dev=0&style=2"),
    )
    val installed = runCatching { amap.resolveActivity(context.packageManager) }.getOrNull() != null
    if (installed) {
        runCatching { context.startActivity(amap) }
        return
    }
    val web = Uri.parse(
        "https://uri.amap.com/navigation?to=${clinic.lng},${clinic.lat},$name&mode=car&policy=1&src=mengbao&coordinate=gaode&callnative=1",
    )
    runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, web)) }
}

private fun hasLocation(context: Context): Boolean =
    ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
        PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
        PackageManager.PERMISSION_GRANTED

@SuppressLint("MissingPermission")
private fun lastKnownLocation(context: Context): Pair<Double, Double>? {
    val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
    var best: Location? = null
    for (p in listOf(
        LocationManager.GPS_PROVIDER,
        LocationManager.NETWORK_PROVIDER,
        LocationManager.PASSIVE_PROVIDER,
    )) {
        val loc = runCatching { lm.getLastKnownLocation(p) }.getOrNull() ?: continue
        if (best == null || loc.time > best.time) best = loc
    }
    return best?.let { it.latitude to it.longitude }
}

/**
 * 门诊定位：一键同步广东省全省接种门诊（粤苗官方公开接口，免登录），
 * 与内置名录合并；高德 JS 地图打点 + 按距离排序列表，地图起不来自动降级纯列表。
 */
@Composable
fun NearbyMapScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val builtIn = remember { Standards.clinics }
    var synced by remember { mutableStateOf(ClinicSync.loadSynced(context)) }
    val clinics: List<Clinic> = remember(synced) {
        val seen = HashSet<String>()
        (synced + builtIn).filter { seen.add(it.name + "@" + it.address) }
    }
    var syncProgress by remember { mutableStateOf<ClinicSync.Progress?>(null) }
    var syncError by remember { mutableStateOf<String?>(null) }
    var searchText by remember { mutableStateOf("") }
    var myLat by remember { mutableStateOf<Double?>(null) }
    var myLng by remember { mutableStateOf<Double?>(null) }
    var located by remember { mutableStateOf(false) }
    var denied by remember { mutableStateOf(false) }
    var mapFailed by remember { mutableStateOf(false) }
    var webView by remember { mutableStateOf<WebView?>(null) }
    var ready by remember { mutableStateOf(false) }
    var picked by remember { mutableStateOf<Clinic?>(null) }
    val mainHandler = remember { Handler(Looper.getMainLooper()) }

    // 一键同步（子线程请求，回调切主线程）
    fun startSync() {
        if (syncProgress != null) return
        syncError = null
        syncProgress = ClinicSync.Progress("正在连接粤苗官方接口…", 0, 0)
        Thread {
            ClinicSync.syncAll(context) { p ->
                mainHandler.post { syncProgress = p }
            }.fold(
                onSuccess = { n ->
                    mainHandler.post {
                        synced = ClinicSync.loadSynced(context)
                        syncProgress = null
                        Toast.makeText(context, "已同步全省 $n 家门诊", Toast.LENGTH_LONG).show()
                        com.zsonit.mengbao.data.AppLog.i("ClinicSync", "同步成功：$n 家门诊")
                    }
                },
                onFailure = { e ->
                    mainHandler.post {
                        syncProgress = null
                        syncError = e.message ?: "网络异常，请稍后重试"
                        com.zsonit.mengbao.data.AppLog.e("ClinicSync", "同步全省门诊失败：${e.message}")
                    }
                },
            )
        }.start()
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { result ->
        val granted = result[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            result[Manifest.permission.ACCESS_COARSE_LOCATION] == true || hasLocation(context)
        denied = !granted
        if (granted) {
            lastKnownLocation(context)?.let { (lat, lng) ->
                myLat = lat; myLng = lng; located = true
            }
        }
    }

    LaunchedEffect(Unit) {
        if (hasLocation(context)) {
            lastKnownLocation(context)?.let { (lat, lng) -> myLat = lat; myLng = lng; located = true }
        } else {
            permissionLauncher.launch(
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
            )
        }
        // 从未同步过则自动同步一次
        if (ClinicSync.lastSyncedAt(context) == 0L) startSync()
    }

    // 计算距离并排序（无坐标的排最后，搜索词过滤）
    val centerLat = myLat ?: FALLBACK_LAT
    val centerLng = myLng ?: FALLBACK_LNG
    val sorted = remember(clinics, centerLat, centerLng, searchText) {
        val kw = searchText.trim()
        clinics.asSequence()
            .filter { kw.isEmpty() || it.name.contains(kw) || it.district.contains(kw) || it.address.contains(kw) || it.city.contains(kw) }
            .map { c ->
                val d = if (c.lat != 0.0 || c.lng != 0.0) distanceKm(centerLat, centerLng, c.lat, c.lng) else Double.MAX_VALUE
                c to d
            }
            .sortedBy { it.second }
            .toList()
    }

    // 地图就绪后把门诊点推给网页
    fun pushClinics() {
        val wv: WebView = webView ?: return
        if (!ready) return
        val json: String = sorted.take(30)
            .joinToString(",", "[", "]") { (c, d) ->
                """{"name":"${c.name.replace("\"", "'")}","lat":${c.lat},"lng":${c.lng},"distance":"${"%.1f".format(d)}"}"""
            }
        val lat = myLat ?: FALLBACK_LAT
        val lng = myLng ?: FALLBACK_LNG
        runCatching {
            wv.evaluateJavascript("renderClinics(${json.replace("$", "\\$")}, $lat, $lng);", null)
        }
    }

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = "附近接种门诊 · 离线备用", onBack = onBack)

        // 定位状态
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                when {
                    located -> "📍 已定位，按直线距离排序"
                    denied -> "📍 未获得定位权限，暂以广州天河为参照"
                    else -> "📍 正在定位…"
                },
                fontSize = 12.5.sp,
                color = if (denied) Palette.warn else Palette.subtle,
                fontWeight = FontWeight.Medium,
            )
            Spacer(Modifier.width(10.dp))
            Text(
                "重新定位",
                fontSize = 12.5.sp, color = Palette.purple, fontWeight = FontWeight.SemiBold,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(Palette.purpleTint)
                    .clickable {
                        denied = false
                        if (hasLocation(context)) {
                            lastKnownLocation(context)?.let { (lat, lng) ->
                                myLat = lat; myLng = lng; located = true
                                pushClinics()
                            }
                        } else {
                            permissionLauncher.launch(
                                arrayOf(
                                    Manifest.permission.ACCESS_FINE_LOCATION,
                                    Manifest.permission.ACCESS_COARSE_LOCATION,
                                ),
                            )
                        }
                    }
                    .padding(horizontal = 10.dp, vertical = 5.dp),
            )
        }

        if (!mapFailed) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(Palette.card)
                    .padding(2.dp),
            ) {
                AndroidView(
                    modifier = Modifier.fillMaxWidth().height(220.dp),
                    factory = { ctx ->
                        WebView(ctx).apply {
                            settings.javaScriptEnabled = true
                            settings.domStorageEnabled = true
                            settings.mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
                            @Suppress("DEPRECATION")
                            settings.setGeolocationEnabled(true)
                            webViewClient = WebViewClient()
                            webChromeClient = object : WebChromeClient() {
                                override fun onGeolocationPermissionsShowPrompt(
                                    origin: String?,
                                    callback: GeolocationPermissions.Callback?,
                                ) {
                                    if (origin != null && callback != null) {
                                        callback.invoke(origin, hasLocation(ctx), false)
                                    }
                                }
                            }
                            addJavascriptInterface(MapBridge(
                                readyCb = {
                                    mainHandler.post {
                                        ready = true
                                        pushClinics()
                                    }
                                },
                                locatedCb = { lat, lng ->
                                    mainHandler.post {
                                        myLat = lat; myLng = lng; located = true
                                        pushClinics()
                                    }
                                },
                                failCb = { mainHandler.post { denied = false; mapFailed = true; com.zsonit.mengbao.data.AppLog.w("Map", "地图加载失败，降级为列表模式") } },
                                pickCb = { lat, lng, name ->
                                    mainHandler.post {
                                        val c = clinics.firstOrNull { it.name == name }
                                        if (c != null) picked = c else {
                                            openAmapNav(ctx, Clinic(
                                                name = name, city = "", district = "", address = "",
                                                phone = "", hours = "", vaccines = "", note = "", tag = "",
                                                scope = "", lat = lat, lng = lng, star = false,
                                            ))
                                        }
                                    }
                                },
                            ), "android")
                            val html = ctx.assets.open("map.html").bufferedReader().use { it.readText() }
                            loadDataWithBaseURL("https://mengbao.local/", html, "text/html", "utf-8", null)
                            webView = this
                        }
                    },
                )
            }
        } else {
            Box(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(Palette.purpleTint)
                    .padding(14.dp),
            ) {
                Text(
                    "地图暂时无法加载，已切换为列表模式：下方按距离列出附近接种门诊，点「导航」可直接跳高德。",
                    fontSize = 12.5.sp, color = Palette.ink2,
                )
            }
        }

        Text(
            "共 ${sorted.size} 家匹配 · 已同步全省 ${synced.size} 家" +
                (if (ClinicSync.lastSyncedAt(context) > 0) {
                    "（" + SimpleDateFormat("MM-dd HH:mm", Locale.CHINA).format(Date(ClinicSync.lastSyncedAt(context))) + "）"
                } else "（未同步，点右上「🔄 一键同步」拉取全省）") +
                " · 列表显示最近 30 家",
            fontSize = 11.5.sp, color = Palette.subtle,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
        )

        LazyColumn(Modifier.fillMaxSize()) {
            items(sorted.take(30)) { (clinic, dist) ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                        .padding(bottom = 8.dp)
                        .cardStyle(padding = 13.dp)
                        .clickable { openAmapNav(context, clinic) },
                ) {
                    Column(Modifier.weight(1f)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                clinic.name, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                                color = Palette.ink, modifier = Modifier.weight(1f, fill = false),
                            )
                            Spacer(Modifier.width(8.dp))
                            TagView(text = "%.1f km".format(dist), tone = TagTone.PURPLE)
                        }
                        Text(
                            "${clinic.district} · ${clinic.address}",
                            fontSize = 12.sp, color = Palette.subtle,
                            modifier = Modifier.padding(top = 3.dp),
                        )
                        if (clinic.phone.isNotBlank()) {
                            Text(
                                clinic.phone, fontSize = 12.sp, color = Palette.purpleDeep,
                                modifier = Modifier.padding(top = 4.dp).clickable {
                                    runCatching {
                                        context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:${clinic.phone}")))
                                    }
                                },
                            )
                        }
                    }
                    Spacer(Modifier.width(8.dp))
                    Text(
                        "导航",
                        fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple,
                        modifier = Modifier
                            .clip(CircleShape)
                            .background(Palette.purpleTint)
                            .clickable { openAmapNav(context, clinic) }
                            .padding(horizontal = 12.dp, vertical = 7.dp),
                    )
                }
            }
            item {
                Text(
                    "数据来自粤苗官方公开接口同步 + 内置名录兜底；导航使用高德，未安装会打开网页版。",
                    fontSize = 11.5.sp, color = Palette.subtle,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
                )
            }
        }
    }

    // 同步中进度弹窗
    syncProgress?.let { p ->
        AlertDialog(
            onDismissRequest = { },
            title = { Text("一键同步全省门诊", fontWeight = FontWeight.SemiBold) },
            text = {
                Column {
                    Text(p.phase, fontSize = 14.sp, color = Palette.ink)
                    Text(
                        "已完成 ${p.done} 个区域，首次同步约需 2~3 分钟，请保持网络畅通…",
                        fontSize = 12.sp, color = Palette.subtle,
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }
            },
            confirmButton = {},
        )
    }

    // 同步失败提示
    syncError?.let { err ->
        AlertDialog(
            onDismissRequest = { syncError = null },
            title = { Text("同步失败", fontWeight = FontWeight.SemiBold) },
            text = { Text("$err\n\n内置门诊名录仍可正常使用。", fontSize = 13.sp) },
            confirmButton = {
                TextButton(onClick = { syncError = null; startSync() }) { Text("重试", color = Palette.purple) }
            },
            dismissButton = {
                TextButton(onClick = { syncError = null }) { Text("取消", color = Palette.subtle) }
            },
        )
    }

    // 地图上点了某个门诊 → 直接唤起导航
    val pickedClinic: Clinic? = picked
    if (pickedClinic != null) {
        LaunchedEffect(pickedClinic.name) {
            openAmapNav(context, pickedClinic)
            picked = null
        }
    }
}

/** 网页 → 原生 的桥 */
private class MapBridge(
    private val readyCb: () -> Unit,
    private val locatedCb: (Double, Double) -> Unit,
    private val failCb: () -> Unit,
    private val pickCb: (Double, Double, String) -> Unit,
) {
    @JavascriptInterface
    fun mapReady() = readyCb()

    @JavascriptInterface
    fun onLocated(lat: Double, lng: Double) = locatedCb(lat, lng)

    @JavascriptInterface
    fun onLocateFailed() = Unit

    @JavascriptInterface
    fun mapFallback() = failCb()

    @JavascriptInterface
    fun pickClinic(name: String, lat: Double, lng: Double) = pickCb(lat, lng, name)
}
