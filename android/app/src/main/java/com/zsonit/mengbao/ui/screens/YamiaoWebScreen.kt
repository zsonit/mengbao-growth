package com.zsonit.mengbao.ui.screens

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.webkit.GeolocationPermissions
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.content.ContextCompat
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.TopBar

/**
 * 粤苗官方「接种门诊」页面（广东省 CDC）。
 * 直接内嵌官方 H5：定位附近接种单位、门诊地图，不需要我们自己维护门诊数据。
 */
private const val YAMIAO_URL =
    "https://ymapp.cdcp.org.cn/nipisgd/parent-app/index.html#/pages/patient/listNoNav"

/** 外链 scheme 直接交给系统，避免在 WebView 里加载失败。 */
private val externalSchemes = setOf(
    "tel", "mailto", "sms", "androidamap", "amapuri", "iosamap",
    "baidumap", "qqmap", "weixin", "alipays", "alipay", "mqqapi",
)

@Composable
fun YamiaoWebScreen(onBack: () -> Unit, onOpenNearby: (() -> Unit)? = null) {
    val context = LocalContext.current
    var reloadTick by remember { mutableIntStateOf(0) }
    var canGoBack by remember { mutableStateOf(false) }
    var loading by remember { mutableStateOf(true) }
    var failed by remember { mutableStateOf(false) }
    var blankDetected by remember { mutableStateOf(false) }
    var webViewRef by remember { mutableStateOf<WebView?>(null) }

    // 系统 WebView 内核主版本号（老内核跑不动粤苗 H5 的现代语法）
    val webviewMajor = remember {
        runCatching {
            WebView.getCurrentWebViewPackage()?.versionName
                ?.substringBefore('.')?.toIntOrNull()
        }.getOrNull()
    }

    // 网页调 navigator.geolocation 时 WebView 会回调这里；
    // 若系统定位权限还没批下来，先把回调暂存，等授权结果出来再放行，
    // 否则页面第一次定位请求会被静默拒绝，之后点定位一直没反应。
    var pendingGeoOrigin by remember { mutableStateOf<String?>(null) }
    var pendingGeoCallback by remember { mutableStateOf<GeolocationPermissions.Callback?>(null) }

    fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { _ ->
        val granted = hasLocationPermission()
        val cb = pendingGeoCallback
        val origin = pendingGeoOrigin
        pendingGeoCallback = null
        pendingGeoOrigin = null
        // 授权完成后重载一次，让页面以已授权状态重新发起定位
        if (granted) webViewRef?.reload()
        if (cb != null && origin != null) {
            if (!granted) cb.invoke(origin, false, false)
        }
    }

    androidx.compose.runtime.LaunchedEffect(Unit) {
        if (!hasLocationPermission()) {
            permissionLauncher.launch(
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
            )
        }
    }

    BackHandler(enabled = canGoBack) { webViewRef?.goBack() }

    Column(Modifier.fillMaxSize().padding(top = 0.dp)) {
        TopBar(title = "粤苗 · 接种门诊", onBack = onBack)

        // 工具条：刷新 / 用浏览器打开
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "↻ 重新加载",
                fontSize = 12.sp, color = Palette.subtle, fontWeight = FontWeight.Medium,
                modifier = Modifier
                    .clickable {
                        loading = true
                        failed = false
                        reloadTick++
                    }
                    .padding(horizontal = 8.dp, vertical = 6.dp),
            )
            Text(
                "🌐 用浏览器打开",
                fontSize = 12.sp, color = Palette.subtle, fontWeight = FontWeight.Medium,
                modifier = Modifier
                    .clickable {
                        runCatching {
                            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(YAMIAO_URL)))
                        }
                    }
                    .padding(horizontal = 8.dp, vertical = 6.dp),
            )
        }

        androidx.compose.foundation.layout.Box(Modifier.fillMaxSize()) {
            AndroidView(
                modifier = Modifier.fillMaxSize(),
                factory = { ctx ->
                    WebView(ctx).apply {
                        settings.javaScriptEnabled = true
                        settings.domStorageEnabled = true
                        settings.databaseEnabled = true
                        settings.useWideViewPort = true
                        settings.loadWithOverviewMode = true
                        settings.javaScriptCanOpenWindowsAutomatically = true
                        settings.setSupportZoom(false)
                        settings.mediaPlaybackRequiresUserGesture = false
                        settings.mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
                        @Suppress("DEPRECATION")
                        settings.setGeolocationEnabled(true)

                        webViewClient = object : WebViewClient() {
                            override fun shouldOverrideUrlLoading(
                                view: WebView,
                                request: WebResourceRequest,
                            ): Boolean {
                                val url = request.url
                                val scheme = url.scheme?.lowercase() ?: ""
                                if (scheme in externalSchemes) {
                                    runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, url)) }
                                    return true
                                }
                                return false
                            }

                            override fun doUpdateVisitedHistory(view: WebView, url: String?, isReload: Boolean) {
                                canGoBack = view.canGoBack()
                            }

                            override fun onPageFinished(view: WebView, url: String?) {
                                loading = false
                                // 白屏检测：粤苗 H5 是现代 ES Module 构建，老内核 WebView 会静默白屏。
                                // 加载完再等 4 秒，若页面容器仍未渲染出内容则判定为不兼容。
                                view.postDelayed({
                                    runCatching {
                                        view.evaluateJavascript(
                                            "(function(){var a=document.querySelector('#app');return (a&&a.children.length>0)?'1':'0';})()",
                                        ) { r ->
                                            if (r?.contains("0") == true) {
                                                blankDetected = true
                                                com.zsonit.mengbao.data.AppLog.w(
                                                    "Yamiao", "白屏检测触发：WebView 内核=${webviewMajor ?: "未知"}，页面未渲染",
                                                )
                                            }
                                        }
                                    }
                                }, 4000)
                            }

                            override fun onReceivedError(
                                view: WebView,
                                request: WebResourceRequest?,
                                error: android.webkit.WebResourceError?,
                            ) {
                                if (request?.isForMainFrame == true) {
                                    loading = false
                                    failed = true
                                    com.zsonit.mengbao.data.AppLog.e(
                                        "Yamiao",
                                        "粤苗页加载失败：${error?.description ?: "未知错误"} code=${error?.errorCode}",
                                    )
                                }
                            }
                        }

                        webChromeClient = object : WebChromeClient() {
                            override fun onGeolocationPermissionsShowPrompt(
                                origin: String?,
                                callback: GeolocationPermissions.Callback?,
                            ) {
                                if (origin == null || callback == null) return
                                if (hasLocationPermission()) {
                                    // 已有系统定位权限，直接放行，由页面自己的「同意/拒绝」弹窗兜底
                                    callback.invoke(origin, true, false)
                                } else {
                                    // 权限没批：暂存回调，弹出系统授权，拿到结果后再放行
                                    pendingGeoOrigin = origin
                                    pendingGeoCallback = callback
                                    permissionLauncher.launch(
                                        arrayOf(
                                            Manifest.permission.ACCESS_FINE_LOCATION,
                                            Manifest.permission.ACCESS_COARSE_LOCATION,
                                        ),
                                    )
                                }
                            }
                        }

                        webViewRef = this
                        com.zsonit.mengbao.data.AppLog.i(
                            "Yamiao",
                            "开始加载粤苗页，WebView 内核=${webviewMajor ?: "未知"}",
                        )
                        loadUrl(YAMIAO_URL)
                    }
                },
                update = { view ->
                    // update 在每次重组都会调，用 tag 记录已应用的 reload 序号，避免重复刷新
                    val applied = (view.tag as? Int) ?: 0
                    if (reloadTick > applied) {
                        view.tag = reloadTick
                        view.reload()
                    }
                },
            )

            if (loading && !failed) {
                Row(
                    Modifier
                        .align(Alignment.Center)
                        .padding(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    CircularProgressIndicator(strokeWidth = 2.5.dp)
                    Text("正在加载粤苗门诊查询…", fontSize = 13.sp, color = Palette.subtle)
                }
            }

            if (failed) {
                Column(
                    Modifier
                        .align(Alignment.Center)
                        .padding(horizontal = 32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text("页面加载失败", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
                    Text(
                        "粤苗是广东省疾控中心的在线服务，需要网络。请检查网络后重试，或点右上角「用浏览器打开」。",
                        fontSize = 12.5.sp, color = Palette.subtle,
                        modifier = Modifier.padding(top = 8.dp),
                    )
                    Text(
                        "↻ 重试",
                        fontSize = 13.sp, color = Palette.purpleDeep, fontWeight = FontWeight.SemiBold,
                        modifier = Modifier
                            .clickable {
                                loading = true
                                failed = false
                                reloadTick++
                            }
                            .padding(top = 14.dp),
                    )
                }
            }

            if (blankDetected && !failed) {
                Column(
                    Modifier
                        .align(Alignment.Center)
                        .padding(horizontal = 28.dp)
                        .clip(RoundedCornerShape(18.dp))
                        .background(Palette.card)
                        .padding(horizontal = 22.dp, vertical = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text("😔 页面没能加载出来", fontSize = 15.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
                    Text(
                        if (webviewMajor != null && webviewMajor < 90) {
                            "手机系统 WebView 内核版本（$webviewMajor）过旧，跑不动粤苗官方页面。" +
                                "可以去应用商店更新「Android System WebView」，或者："
                        } else {
                            "粤苗官方页面在应用内没能正常渲染。可以用手机自带浏览器打开，也可以先用内置的离线门诊地图："
                        },
                        fontSize = 12.5.sp, color = Palette.subtle,
                        modifier = Modifier.padding(top = 10.dp),
                    )
                    Text(
                        "🌐 用系统浏览器打开",
                        fontSize = 14.5.sp, fontWeight = FontWeight.SemiBold,
                        color = androidx.compose.ui.graphics.Color.White,
                        modifier = Modifier
                            .padding(top = 18.dp)
                            .clip(CircleShape)
                            .background(Palette.purple)
                            .clickable {
                                runCatching {
                                    blankDetected = false
                                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(YAMIAO_URL)))
                                }
                            }
                            .padding(horizontal = 22.dp, vertical = 12.dp),
                    )
                    if (onOpenNearby != null) {
                        Text(
                            "🗺 用内置离线门诊地图",
                            fontSize = 13.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.purpleDeep,
                            modifier = Modifier
                                .padding(top = 10.dp)
                                .clip(CircleShape)
                                .background(Palette.purpleTint)
                                .clickable {
                                    blankDetected = false
                                    onOpenNearby()
                                }
                                .padding(horizontal = 20.dp, vertical = 10.dp),
                        )
                    }
                    Text(
                        "↻ 重试",
                        fontSize = 13.sp, color = Palette.purpleDeep,
                        modifier = Modifier
                            .clickable {
                                blankDetected = false
                                loading = true
                                failed = false
                                reloadTick++
                            }
                            .padding(top = 14.dp, bottom = 2.dp),
                    )
                }
            }
        }
    }
}
