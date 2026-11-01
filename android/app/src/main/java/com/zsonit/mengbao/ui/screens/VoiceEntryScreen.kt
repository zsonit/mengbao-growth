package com.zsonit.mengbao.ui.screens

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.data.VoiceParseResult
import com.zsonit.mengbao.data.VoiceParser
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.GrowthRecord
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.PrimaryButton
import com.zsonit.mengbao.ui.TextInput
import com.zsonit.mengbao.ui.cardStyle
import java.time.LocalDate

/**
 * 语音记一笔（一键长录音版）。
 *
 * 点开即听：悬浮球按下 → 直接开始识别，不需要再点麦克风；
 * 连续录音：一段说完自动续录下一段，想到什么说什么（喝奶、睡觉、尿布…混着说都行）；
 * 一键停：说完点「完成」，整段话自动拆成多条记录，逐条确认后一次性保存；
 * 同一类说几遍就记几条；没听懂的句子会单独列出，不乱记。
 *
 * 系统 SpeechRecognizer 在部分国产 ROM 上不可用，失败路径全部退回「打字 → 同一个解析器」。
 */
@Composable
fun VoiceEntryDialog(child: Child, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val supported = remember { SpeechRecognizer.isRecognitionAvailable(context) }

    // LISTEN = 连续聆听中；REVIEW = 识别完逐条确认；MANUAL = 打字兜底
    var mode by remember { mutableStateOf(if (supported) "LISTEN" else "MANUAL") }
    val listeningState = remember { mutableStateOf(false) }
    val sessionActive = remember { mutableStateOf(true) }   // 是否继续自动续录
    val partialState = remember { mutableStateOf("") }
    val segmentsState = remember { mutableStateOf(listOf<String>()) } // 已识别的每一段
    val emptyStreak = remember { mutableIntStateOf(0) }     // 连续几次没听到声音
    val parsedState = remember { mutableStateOf(listOf<VoiceParseResult>()) }
    val unknownState = remember { mutableStateOf(listOf<String>()) }
    val errorState = remember { mutableStateOf<String?>(null) }
    val manualTextState = remember { mutableStateOf("") }

    val listening by listeningState
    val partial by partialState
    val segments by segmentsState
    val parsed by parsedState
    val unknown by unknownState
    val error by errorState
    val manualText by manualTextState

    val handler = remember { Handler(Looper.getMainLooper()) }
    val restartHolder = remember { arrayOfNulls<Runnable>(1) }

    val recognizer = remember {
        if (supported) runCatching { SpeechRecognizer.createSpeechRecognizer(context) }.getOrNull() else null
    }

    fun startListening(clear: Boolean) {
        val engine = recognizer
        if (engine == null) {
            mode = "MANUAL"
            errorState.value = "这台设备没有语音识别服务，直接打字一样能记"
            return
        }
        if (clear) {
            segmentsState.value = emptyList()
            parsedState.value = emptyList()
            unknownState.value = emptyList()
        }
        partialState.value = ""
        errorState.value = null
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        }
        runCatching { engine.startListening(intent) }
            .onSuccess { listeningState.value = true }
            .onFailure {
                listeningState.value = false
                com.zsonit.mengbao.data.AppLog.e("Voice", "startListening 失败：${it.message}")
                errorState.value = "启动语音识别失败，可以直接打字"
                mode = "MANUAL"
            }
    }

    fun cancelRestart() {
        restartHolder[0]?.let { handler.removeCallbacks(it) }
        restartHolder[0] = null
    }

    fun scheduleRestart(delayMs: Long) {
        cancelRestart()
        val r = Runnable { startListening(false) }
        restartHolder[0] = r
        handler.postDelayed(r, delayMs)
    }

    /** 识别结束：整段拼起来 → parseAll → 确认页（或打字兜底） */
    fun finalizeListening() {
        cancelRestart()
        listeningState.value = false
        sessionActive.value = false
        val all = segmentsState.value.joinToString("").trim()
        if (all.isEmpty()) {
            mode = "MANUAL"
            errorState.value = "没听到内容，直接打字也可以"
            return
        }
        val (ok, unk) = VoiceParser.parseAll(all)
        com.zsonit.mengbao.data.AppLog.i(
            "Voice", "结算：全文${all.length}字 → ${ok.size}条可记录 / ${unk.size}句未识别",
        )
        if (ok.isEmpty()) {
            mode = "MANUAL"
            errorState.value = "这段话没认出能记录的内容：\n「$all」\n试试：喝了150毫升奶、睡了1小时20分钟、尿了、体温37.8"
            return
        }
        parsedState.value = ok
        unknownState.value = unk
        mode = "REVIEW"
    }

    /** 点「完成」/ 点麦克风：停止续录。正在听就先收尾这次识别，结果回来后自动结算 */
    fun stopSession() {
        cancelRestart()
        sessionActive.value = false
        if (listeningState.value) {
            runCatching { recognizer?.stopListening() }
        } else {
            finalizeListening()
        }
    }

    val listener = remember {
        object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                listeningState.value = true
            }

            override fun onBeginningOfSpeech() = Unit
            override fun onRmsChanged(rmsdB: Float) = Unit
            override fun onBufferReceived(buffer: ByteArray?) = Unit

            override fun onEndOfSpeech() {
                listeningState.value = false
            }

            override fun onError(error: Int) {
                listeningState.value = false
                com.zsonit.mengbao.data.AppLog.w(
                    "Voice",
                    "onError code=$error(${recognizeErrorText(error)}) session=${sessionActive.value} 已收段数=${segmentsState.value.size}",
                )
                when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT ->
                        // 静音超时：还在会话里就继续等（中间换尿布、走开一下很正常）
                        if (sessionActive.value) {
                            emptyStreak.intValue++
                            if (emptyStreak.intValue >= 2) finalizeListening() else scheduleRestart(500)
                        } else if (segmentsState.value.isEmpty()) {
                            errorState.value = "没听到声音"
                            mode = "MANUAL"
                        } else finalizeListening()

                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY ->
                        if (sessionActive.value) scheduleRestart(800) else finalizeListening()

                    else -> {
                        sessionActive.value = false
                        if (segmentsState.value.isEmpty()) {
                            errorState.value = "语音识别没成功（${recognizeErrorText(error)}），可以直接打字"
                            mode = "MANUAL"
                        } else finalizeListening()
                    }
                }
            }

            override fun onResults(results: Bundle?) {
                listeningState.value = false
                partialState.value = ""
                val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull().orEmpty().trim()
                if (text.isNotEmpty()) {
                    com.zsonit.mengbao.data.AppLog.i(
                        "Voice", "识别到一段（${text.length}字）：${text.take(60)}",
                    )
                    segmentsState.value = segmentsState.value + text
                    emptyStreak.intValue = 0
                }
                if (sessionActive.value) {
                    if (text.isNotEmpty()) scheduleRestart(250) else {
                        emptyStreak.intValue++
                        if (emptyStreak.intValue >= 2) finalizeListening() else scheduleRestart(500)
                    }
                } else finalizeListening()
            }

            override fun onPartialResults(partialResults: Bundle?) {
                partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()?.let { partialState.value = it }
            }

            override fun onEvent(eventType: Int, params: Bundle?) = Unit
        }
    }

    DisposableEffect(recognizer) {
        recognizer?.setRecognitionListener(listener)
        onDispose {
            cancelRestart()
            runCatching { recognizer?.cancel() }
            runCatching { recognizer?.destroy() }
        }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            sessionActive.value = true
            startListening(true)
        } else {
            mode = "MANUAL"
            errorState.value = "没有麦克风权限，可以直接打字记录"
        }
    }

    // 一键直达：弹层出现就立刻开始听
    LaunchedEffect(Unit) {
        if (mode != "LISTEN") return@LaunchedEffect
        com.zsonit.mengbao.data.AppLog.i(
            "Voice", "弹层打开：supported=$supported recognizer=${recognizer != null} 初始mode=$mode",
        )
        val granted = ContextCompat.checkSelfPermission(
            context, Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) startListening(true) else permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
    }

    fun saveAll(list: List<VoiceParseResult>) {
        val today = LocalDate.now()
        var saved = 0
        list.forEach { r ->
            if (r.kind == "growth") {
                val value = r.value ?: return@forEach
                val cur = Store.current ?: child
                val existing = cur.records.firstOrNull { it.date == today }
                val base = existing ?: GrowthRecord(date = today)
                val record = when (r.entryId) {
                    "height" -> base.copy(height = value)
                    "weight" -> base.copy(weight = value)
                    "head" -> base.copy(headCirc = value)
                    else -> base
                }
                if (existing != null) Store.updateRecord(record) else Store.addRecord(record)
                saved++
            } else {
                r.toFeedLog()?.let { Store.addFeed(it); saved++ }
            }
        }
        Toast.makeText(context, "已记录 $saved 条", Toast.LENGTH_SHORT).show()
        onDismiss()
    }

    val transition = rememberInfiniteTransition(label = "voicePulse")
    val pulse by transition.animateFloat(
        initialValue = 1f,
        targetValue = 1.38f,
        animationSpec = infiniteRepeatable(tween(1000), RepeatMode.Reverse),
        label = "pulse",
    )

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Column(
            Modifier
                .fillMaxWidth(0.92f)
                .clip(RoundedCornerShape(24.dp))
                .background(Palette.card)
                .verticalScroll(rememberScrollState())
                .padding(18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    when (mode) {
                        "LISTEN" -> "语音记一笔 · 长录音"
                        "REVIEW" -> "确认记录 · ${parsed.size} 条"
                        else -> "语音记一笔"
                    },
                    fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Palette.ink,
                )
                Spacer(Modifier.weight(1f))
                Text(
                    "✕", fontSize = 15.sp, color = Palette.subtle,
                    modifier = Modifier.clickable { onDismiss() }.padding(6.dp),
                )
            }

            Spacer(Modifier.height(10.dp))

            when (mode) {
                // ── 聆听中 ──────────────────────────────────────────────
                "LISTEN" -> {
                    Box(Modifier.size(150.dp), contentAlignment = Alignment.Center) {
                        if (listening) {
                            Box(
                                Modifier
                                    .size(110.dp)
                                    .graphicsLayer {
                                        scaleX = pulse
                                        scaleY = pulse
                                        alpha = 0.45f
                                    }
                                    .clip(CircleShape)
                                    .background(Palette.pink),
                            )
                        }
                        Box(
                            Modifier
                                .size(96.dp)
                                .clip(CircleShape)
                                .then(
                                    if (listening) Modifier.background(Palette.pinkGradient)
                                    else Modifier.background(Palette.pinkBg),
                                )
                                .clickable { stopSession() },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(if (listening) "🎙️" else "🎤", fontSize = 40.sp)
                        }
                    }

                    Text(
                        if (listening) "正在听…想到什么说什么" else "正在准备麦克风…",
                        fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "喝奶、睡觉、尿布、辅食、身高体重…\n一口气全说完，说完点一下麦克风结束",
                        fontSize = 11.5.sp, color = Palette.subtle, textAlign = TextAlign.Center,
                        lineHeight = 17.sp,
                    )

                    // 已识别内容（实时）
                    if (partial.isNotEmpty() || segments.isNotEmpty()) {
                        Spacer(Modifier.height(12.dp))
                        Column(
                            Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp))
                                .background(Palette.purpleTint).padding(12.dp),
                        ) {
                            segments.forEach {
                                Text("· $it", fontSize = 13.5.sp, color = Palette.ink, lineHeight = 19.sp)
                            }
                            if (partial.isNotEmpty()) {
                                Text(
                                    "· $partial …", fontSize = 13.5.sp, color = Palette.purple,
                                    lineHeight = 19.sp,
                                )
                            }
                        }
                    }

                    Spacer(Modifier.height(14.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        TextButton(
                            onClick = {
                                cancelRestart()
                                sessionActive.value = false
                                runCatching { recognizer?.cancel() }
                                mode = "MANUAL"
                            },
                        ) { Text("改打字", fontSize = 14.sp, color = Palette.subtle) }
                        Box(Modifier.weight(1f)) {
                            PrimaryButton(text = if (listening) "说完啦 ✓" else "完成") { stopSession() }
                        }
                    }
                }

                // ── 确认多条记录 ────────────────────────────────────────
                "REVIEW" -> {
                    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        parsed.forEachIndexed { index, r ->
                            Row(
                                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp))
                                    .background(Palette.pinkBg).padding(horizontal = 12.dp, vertical = 10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(kindEmoji(r.kind), fontSize = 24.sp)
                                Spacer(Modifier.width(10.dp))
                                Column(Modifier.weight(1f)) {
                                    Text(
                                        r.summary, fontSize = 14.5.sp,
                                        fontWeight = FontWeight.Bold, color = Palette.ink,
                                    )
                                    if (r.note.isNotEmpty() && r.kind != "solid" && r.kind != "supplement") {
                                        Text(r.note, fontSize = 11.sp, color = Palette.subtle)
                                    }
                                }
                                Text(
                                    "✕", fontSize = 14.sp, color = Palette.subtle,
                                    modifier = Modifier
                                        .clickable { parsedState.value = parsed.filterIndexed { i, _ -> i != index } }
                                        .padding(8.dp),
                                )
                            }
                        }
                    }

                    if (parsed.isEmpty()) {
                        Text("全部删掉了，点「重说」再来一遍", fontSize = 13.sp, color = Palette.subtle)
                    }

                    if (unknown.isNotEmpty()) {
                        Spacer(Modifier.height(10.dp))
                        Column(
                            Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
                                .background(Palette.warnBg).padding(11.dp),
                        ) {
                            Text("这几句没认出类型，没有记录：", fontSize = 11.5.sp, color = Palette.warn)
                            unknown.forEach {
                                Text("· $it", fontSize = 11.5.sp, color = Palette.warn, lineHeight = 17.sp)
                            }
                        }
                    }

                    Spacer(Modifier.height(14.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        TextButton(
                            onClick = {
                                sessionActive.value = true
                                emptyStreak.intValue = 0
                                mode = "LISTEN"
                                startListening(true)
                            },
                        ) { Text("重说", fontSize = 14.sp, color = Palette.subtle) }
                        Box(Modifier.weight(1f)) {
                            PrimaryButton(text = "保存 ${parsed.size} 条") { saveAll(parsed) }
                        }
                    }
                }

                // ── 打字兜底 ────────────────────────────────────────────
                else -> {
                    if (error != null) {
                        Text(
                            error.orEmpty(),
                            fontSize = 11.5.sp, color = Palette.warn, lineHeight = 17.sp,
                            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
                                .background(Palette.warnBg).padding(11.dp),
                        )
                        Spacer(Modifier.height(10.dp))
                    }
                    if (supported) {
                        // 语音永远给一个重试入口，不让用户以为功能没了
                        Box(
                            Modifier.size(72.dp).clip(CircleShape).background(Palette.pinkBg)
                                .clickable {
                                    com.zsonit.mengbao.data.AppLog.i("Voice", "从打字兜底重试语音")
                                    errorState.value = null
                                    sessionActive.value = true
                                    emptyStreak.intValue = 0
                                    mode = "LISTEN"
                                    startListening(true)
                                },
                            contentAlignment = Alignment.Center,
                        ) { Text("🎤", fontSize = 30.sp) }
                        Spacer(Modifier.height(4.dp))
                        Text("点一下再试语音", fontSize = 11.5.sp, color = Palette.subtle)
                        Spacer(Modifier.height(12.dp))
                    }
                    Column(Modifier.fillMaxWidth().cardStyle(padding = 12.dp)) {
                        Text(
                            "直接打字，可以说一大段：\n「喝了150毫升奶，换了尿布，睡了1个半小时」",
                            fontSize = 12.sp, color = Palette.subtle, lineHeight = 17.sp,
                        )
                        Spacer(Modifier.height(8.dp))
                        TextInput(
                            label = "想记什么就写什么",
                            value = manualText,
                            placeholder = "喝了150毫升奶，睡了1小时",
                            onChange = { manualTextState.value = it },
                        )
                        Spacer(Modifier.height(10.dp))
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            if (supported) {
                                TextButton(
                                    onClick = {
                                        errorState.value = null
                                        sessionActive.value = true
                                        emptyStreak.intValue = 0
                                        mode = "LISTEN"
                                        startListening(true)
                                    },
                                ) { Text("再用语音", fontSize = 14.sp, color = Palette.subtle) }
                            }
                            Box(Modifier.weight(1f)) {
                                PrimaryButton(text = "解析") {
                                    val all = manualText.trim()
                                    if (all.isNotEmpty()) {
                                        val (ok, unk) = VoiceParser.parseAll(all)
                                        if (ok.isEmpty()) {
                                            errorState.value =
                                                "没认出能记录的内容，试试：喝了150毫升奶、睡了1小时、尿了、体温37.8"
                                        } else {
                                            parsedState.value = ok
                                            unknownState.value = unk
                                            mode = "REVIEW"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Spacer(Modifier.height(14.dp))
            Text(
                "* 语音与文字都在本机解析，不会上传",
                fontSize = 10.5.sp, color = Palette.subtle,
            )
        }
    }
}

private fun kindEmoji(kind: String?): String = when (kind) {
    "bottle" -> "🍼"
    "breast" -> "🤱"
    "pumping" -> "🧴"
    "sleep" -> "😴"
    "diaper" -> "🧷"
    "solid" -> "🍚"
    "supplement" -> "💊"
    "temp" -> "🌡️"
    "growth" -> "📏"
    else -> "📝"
}

private fun recognizeErrorText(code: Int): String = when (code) {
    SpeechRecognizer.ERROR_AUDIO -> "录音出错"
    SpeechRecognizer.ERROR_CLIENT -> "客户端出错"
    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "没有麦克风权限"
    SpeechRecognizer.ERROR_NETWORK -> "网络问题"
    SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "网络超时"
    SpeechRecognizer.ERROR_NO_MATCH -> "没听懂"
    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "识别服务忙"
    SpeechRecognizer.ERROR_SERVER -> "服务端出错"
    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "没听到声音"
    else -> "未知错误"
}
