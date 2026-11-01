package com.zsonit.mengbao.ui.screens

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.zsonit.mengbao.data.AIAssistant
import com.zsonit.mengbao.data.AIPlan
import com.zsonit.mengbao.data.OfflineAsr
import com.zsonit.mengbao.ui.Palette
import kotlinx.coroutines.launch

// MARK: - 按住说话（Hold-to-Talk）
//
// 录屏同款交互：首页悬浮麦克风 → 按住不动原地录音（不跳页）→ 松手结束
// → 大模型理解并执行 → 底部弹出结果面板（可撤销、可跳页）。
// 语音识别用内置离线引擎 OfflineAsr（sherpa-onnx），不依赖系统语音服务，
// 国产手机没有谷歌语音服务也能用，没网也能识别。

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HoldToTalkFab(onOpenPage: (String) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var pressing by remember { mutableStateOf(false) }      // 按住录音中
    var waiting by remember { mutableStateOf(false) }       // 松手，等识别收尾
    var partial by remember { mutableStateOf("") }          // 实时转写
    var processing by remember { mutableStateOf(false) }    // AI 理解中
    var result by remember { mutableStateOf<AIPlan?>(null) }
    var showResult by remember { mutableStateOf(false) }
    var holdPendingPerm by remember { mutableStateOf(false) }

    fun finishWithError(msg: String) {
        waiting = false
        pressing = false
        partial = ""
        result = AIPlan(reply = msg, items = emptyList(), openPage = null)
        showResult = true
    }

    fun send(text: String) {
        waiting = false
        partial = ""
        processing = true
        showResult = true // 先弹面板，里面显示「正在理解…」
        scope.launch {
            try {
                result = AIAssistant.interpret(text, model = "glm-5.3-flash")
            } catch (e: Exception) {
                result = AIPlan(
                    reply = e.message ?: "没连上模型，稍后再试一次",
                    items = emptyList(),
                    openPage = null,
                )
            }
            processing = false
        }
    }

    fun startListening() {
        val err = OfflineAsr.ensure(context)
        if (err != null) {
            finishWithError(err)
            return
        }
        partial = ""
        OfflineAsr.start(object : OfflineAsr.Callbacks {
            override fun onPartial(text: String) { partial = text }
            override fun onFinal(text: String) {
                waiting = false
                if (text.isBlank()) {
                    finishWithError("没听清说什么，按住再说一次")
                } else {
                    send(text)
                }
            }
            override fun onError(msg: String) = finishWithError(msg)
        })
    }

    val micPerm = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted && holdPendingPerm) {
            holdPendingPerm = false
            startListening()
        } else if (!granted) {
            holdPendingPerm = false
            finishWithError("没有麦克风权限，去系统设置里开一下")
        }
    }

    fun onHoldStart() {
        pressing = true
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            holdPendingPerm = true
            micPerm.launch(Manifest.permission.RECORD_AUDIO)
            return
        }
        startListening()
    }

    fun onHoldRelease() {
        // 还在等权限回调时松手：直接收场
        if (holdPendingPerm) {
            holdPendingPerm = false
            pressing = false
            return
        }
        pressing = false
        waiting = true
        OfflineAsr.stop()
    }

    Box(Modifier.fillMaxSize()) {
        // 悬浮麦克风按钮（底部居中，玻璃导航栏上方）
        Box(
            Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 12.dp)
                .size(58.dp)
                .graphicsLayer {
                    shadowElevation = 12f
                    shape = CircleShape
                    clip = false
                }
                .clip(CircleShape)
                .background(
                    Brush.linearGradient(listOf(Color(0xFFFF8FB1), Color(0xFFA97BFF))),
                )
                .pointerInput(Unit) {
                    detectTapGestures(
                        onPress = {
                            pressing = true
                            onHoldStart()
                            try {
                                awaitRelease()
                            } catch (_: Exception) {
                            }
                            if (pressing) onHoldRelease()
                        },
                    )
                },
            contentAlignment = Alignment.Center,
        ) {
            Text("🎙️", fontSize = 22.sp)
        }

        // 按住时的全屏面板
        if (pressing || waiting) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.30f))
                    .pointerInput(Unit) {}, // 挡住底下点击
            ) {
                Column(
                    Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        if (!waiting) RippleDots()
                        Box(
                            Modifier
                                .size(92.dp)
                                .clip(CircleShape)
                                .background(Brush.linearGradient(listOf(Color(0xFFFF8FB1), Color(0xFFA97BFF)))),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(if (waiting) "…" else "🎙️", fontSize = 34.sp)
                        }
                    }
                    Spacer(Modifier.height(22.dp))
                    val tip = when {
                        waiting -> "正在收尾识别…"
                        partial.isBlank() -> "我在听…"
                        else -> partial
                    }
                    Text(
                        tip,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color.White,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 36.dp),
                    )
                    Spacer(Modifier.height(18.dp))
                    Text("松手结束", fontSize = 12.sp, color = Color.White.copy(alpha = 0.75f))
                }
            }
        }

        // 结果面板
        if (showResult) {
            val r = result
            ModalBottomSheet(
                onDismissRequest = {
                    showResult = false
                    partial = ""
                },
                containerColor = Palette.card,
            ) {
                HoldResultContent(
                    plan = r,
                    processing = processing,
                    onUndo = {
                        r?.items?.forEach { it.undo() }
                        showResult = false
                    },
                    onOpenPage = { page ->
                        showResult = false
                        onOpenPage(page)
                    },
                    onClose = { showResult = false },
                )
            }
        }
    }
}

@Composable
private fun RippleDots() {
    val transition = rememberInfiniteTransition(label = "ripple")
    val p1 by transition.animateFloat(
        initialValue = 0f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(1800)), label = "p1",
    )
    val p2 by transition.animateFloat(
        initialValue = 0f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(1800, delayMillis = 600)), label = "p2",
    )
    val p3 by transition.animateFloat(
        initialValue = 0f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(1800, delayMillis = 1200)), label = "p3",
    )
    listOf(p1, p2, p3).forEach { p ->
        Box(
            Modifier
                .size(92.dp)
                .scale(1f + p * 1.3f)
                .graphicsLayer { alpha = (1f - p) * 0.55f }
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.35f)),
        )
    }
}

@Composable
private fun HoldResultContent(
    plan: AIPlan?,
    processing: Boolean,
    onUndo: () -> Unit,
    onOpenPage: (String) -> Unit,
    onClose: () -> Unit,
) {
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 18.dp),
    ) {
        // 标题把手
        Box(
            Modifier
                .align(Alignment.CenterHorizontally)
                .width(36.dp).height(5.dp)
                .clip(RoundedCornerShape(50))
                .background(Palette.hairline),
        )
        Spacer(Modifier.height(16.dp))

        when {
            plan == null || processing -> Row(verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(Modifier.size(14.dp), strokeWidth = 1.6.dp, color = Palette.purple)
                Spacer(Modifier.width(8.dp))
                Text("正在理解…", fontSize = 14.sp, color = Palette.ink)
            }

            else -> {
                Text(plan.reply, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
                if (plan.items.isNotEmpty()) {
                    Spacer(Modifier.height(10.dp))
                    Column(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
                            .background(Palette.purpleTint).padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        plan.items.forEach { item ->
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("✓", fontSize = 12.sp, color = Palette.ok)
                                Spacer(Modifier.width(7.dp))
                                Text(item.label, fontSize = 12.5.sp, color = Palette.ink2)
                            }
                        }
                    }
                }
                plan.openPage?.let { p ->
                    Spacer(Modifier.height(10.dp))
                    Text(
                        "去 ${AIAssistant.pages.firstOrNull { it.first == p }?.second ?: "页面"} ›",
                        fontSize = 13.sp, fontWeight = FontWeight.Medium, color = Palette.purple,
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(Palette.purpleTint)
                            .clickable { onOpenPage(p) }
                            .padding(horizontal = 12.dp, vertical = 9.dp),
                    )
                }
            }
        }

        Spacer(Modifier.height(18.dp))
        Row {
            if (plan != null && plan.items.isNotEmpty() && !processing) {
                Text(
                    "↩ 撤销",
                    fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink2,
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(50))
                        .background(Palette.hairlineSoft)
                        .clickable { onUndo() }
                        .padding(vertical = 12.dp),
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.width(10.dp))
            }
            Text(
                if (plan != null && plan.items.isNotEmpty() && !processing) "完成" else "知道了",
                fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Color.White,
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(50))
                    .background(Palette.purple)
                    .clickable { onClose() }
                    .padding(vertical = 12.dp),
                textAlign = TextAlign.Center,
            )
        }
    }
}
