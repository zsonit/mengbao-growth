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
import androidx.compose.foundation.text.BasicTextField
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
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import com.zsonit.mengbao.data.AppLog
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.data.TodoDraft
import com.zsonit.mengbao.data.TodoParser
import com.zsonit.mengbao.model.TodoItem
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.PrimaryButton
import com.zsonit.mengbao.ui.TextInput

/**
 * 语音加待办：打开即听，一口气说好几件事 → 自动拆成多条，日期也一起认出来。
 *
 * 例：「明天打疫苗，后天买维生素 D3，周五去体检」→ 3 条待办，截止日期分别是明天 / 后天 / 本周五。
 * 系统语音不可用时退回打字（同一套拆分逻辑）。
 */
@Composable
fun TodoVoiceDialog(onDismiss: () -> Unit, onSaved: (Int) -> Unit) {
    val context = LocalContext.current
    val supported = remember { SpeechRecognizer.isRecognitionAvailable(context) }

    var mode by remember { mutableStateOf(if (supported) "LISTEN" else "MANUAL") }
    var listening by remember { mutableStateOf(false) }
    var sessionActive by remember { mutableStateOf(true) }
    var partial by remember { mutableStateOf("") }
    var segments by remember { mutableStateOf(listOf<String>()) }
    var drafts by remember { mutableStateOf(listOf<TodoDraft>()) }
    var error by remember { mutableStateOf<String?>(null) }
    var typed by remember { mutableStateOf("") }
    var emptyStreak by remember { mutableIntStateOf(0) }

    val handler = remember { Handler(Looper.getMainLooper()) }
    val restartHolder = remember { arrayOfNulls<Runnable>(1) }
    val recognizer = remember {
        if (supported) runCatching { SpeechRecognizer.createSpeechRecognizer(context) }.getOrNull() else null
    }

    fun cancelRestart() {
        restartHolder[0]?.let { handler.removeCallbacks(it) }
        restartHolder[0] = null
    }

    fun startListening(clear: Boolean) {
        val engine = recognizer
        if (engine == null) {
            mode = "MANUAL"
            error = "这台设备没有语音识别服务，直接打字一样能加"
            return
        }
        if (clear) {
            segments = emptyList()
            drafts = emptyList()
        }
        partial = ""
        error = null
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        }
        runCatching { engine.startListening(intent) }
            .onSuccess { listening = true }
            .onFailure {
                listening = false
                AppLog.e("TodoVoice", "startListening 失败：${it.message}")
                error = "启动语音识别失败，可以直接打字"
                mode = "MANUAL"
            }
    }

    fun scheduleRestart(delayMs: Long) {
        cancelRestart()
        val r = Runnable { startListening(false) }
        restartHolder[0] = r
        handler.postDelayed(r, delayMs)
    }

    fun finalizeListening() {
        cancelRestart()
        listening = false
        sessionActive = false
        val all = segments.joinToString("").trim()
        if (all.isEmpty()) {
            mode = "MANUAL"
            error = "没听到内容，直接打字也可以"
            return
        }
        val parsed = TodoParser.parse(all)
        AppLog.i("TodoVoice", "结算：全文${all.length}字 → ${parsed.size}条待办")
        if (parsed.isEmpty()) {
            mode = "MANUAL"
            error = "这句话没听出待办：\n「$all」\n试试：明天打疫苗、周五去体检"
            return
        }
        drafts = parsed
        error = null
        mode = "REVIEW"
    }

    fun stopSession() {
        cancelRestart()
        sessionActive = false
        if (listening) runCatching { recognizer?.stopListening() } else finalizeListening()
    }

    val listener = remember {
        object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                listening = true
            }

            override fun onBeginningOfSpeech() = Unit
            override fun onRmsChanged(rmsdB: Float) = Unit
            override fun onBufferReceived(buffer: ByteArray?) = Unit

            override fun onEndOfSpeech() {
                listening = false
            }

            override fun onError(errorCode: Int) {
                listening = false
                AppLog.w("TodoVoice", "onError code=$errorCode session=$sessionActive 已收段数=${segments.size}")
                when (errorCode) {
                    SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT ->
                        if (sessionActive) {
                            emptyStreak++
                            if (emptyStreak >= 2) finalizeListening() else scheduleRestart(500)
                        } else if (segments.isEmpty()) {
                            error = "没听到声音"
                            mode = "MANUAL"
                        } else finalizeListening()

                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY ->
                        if (sessionActive) scheduleRestart(800) else finalizeListening()

                    else -> {
                        sessionActive = false
                        if (segments.isEmpty()) {
                            error = "语音识别没成功，可以直接打字"
                            mode = "MANUAL"
                        } else finalizeListening()
                    }
                }
            }

            override fun onResults(results: Bundle?) {
                listening = false
                partial = ""
                val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull().orEmpty().trim()
                if (text.isNotEmpty()) {
                    AppLog.i("TodoVoice", "识别到一段（${text.length}字）：${text.take(60)}")
                    segments = segments + text
                    emptyStreak = 0
                }
                if (sessionActive) {
                    if (text.isNotEmpty()) scheduleRestart(250) else {
                        emptyStreak++
                        if (emptyStreak >= 2) finalizeListening() else scheduleRestart(500)
                    }
                } else finalizeListening()
            }

            override fun onPartialResults(partialResults: Bundle?) {
                partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()?.let { partial = it }
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
            sessionActive = true
            startListening(true)
        } else {
            mode = "MANUAL"
            error = "没有麦克风权限，可以直接打字添加"
        }
    }

    LaunchedEffect(Unit) {
        if (mode != "LISTEN") return@LaunchedEffect
        val granted = ContextCompat.checkSelfPermission(
            context, Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) startListening(true) else permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
    }

    fun save() {
        val items = drafts
            .map { TodoItem(title = it.title.trim(), due = it.due) }
            .filter { it.title.isNotEmpty() }
        if (items.isEmpty()) return
        Store.addTodos(items)
        runCatching { recognizer?.cancel() }
        Toast.makeText(context, "已加入 ${items.size} 条待办", Toast.LENGTH_SHORT).show()
        onSaved(items.size)
        onDismiss()
    }

    fun parseTyped() {
        val text = typed.trim()
        if (text.isEmpty()) return
        val parsed = TodoParser.parse(text)
        if (parsed.isEmpty()) {
            error = "没认出待办内容，换个说法试试"
            return
        }
        drafts = drafts + parsed
        typed = ""
        error = null
        mode = "REVIEW"
    }

    val transition = rememberInfiniteTransition(label = "todoVoicePulse")
    val pulse by transition.animateFloat(
        initialValue = 1f,
        targetValue = 1.38f,
        animationSpec = infiniteRepeatable(tween(1000), RepeatMode.Reverse),
        label = "pulse",
    )

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
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
                        "LISTEN" -> "语音加待办"
                        "REVIEW" -> "确认待办 · ${drafts.size} 条"
                        else -> "语音加待办"
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
                        "「明天打疫苗，后天买维生素 D3，周五去体检」\n几件事连着说，日期会一起认出来",
                        fontSize = 11.5.sp, color = Palette.subtle, textAlign = TextAlign.Center,
                        lineHeight = 17.sp,
                    )

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

                    if (error != null) {
                        Spacer(Modifier.height(8.dp))
                        Text(error!!, fontSize = 12.sp, color = Palette.warn, textAlign = TextAlign.Center)
                    }

                    Spacer(Modifier.height(14.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        TextButton(
                            onClick = {
                                cancelRestart()
                                sessionActive = false
                                runCatching { recognizer?.cancel() }
                                mode = "MANUAL"
                            },
                        ) { Text("改打字", fontSize = 14.sp, color = Palette.subtle) }
                        Box(Modifier.weight(1f)) {
                            PrimaryButton(text = if (listening) "说完啦 ✓" else "完成") { stopSession() }
                        }
                    }
                }

                "REVIEW" -> {
                    if (drafts.isEmpty()) {
                        Text(
                            "没听出可以记的待办，点下面直接写，或者重说一遍",
                            fontSize = 13.sp, color = Palette.subtle, textAlign = TextAlign.Center,
                        )
                        Spacer(Modifier.height(10.dp))
                    }

                    drafts.forEachIndexed { index, draft ->
                        Row(
                            Modifier.fillMaxWidth()
                                .padding(vertical = 4.dp)
                                .clip(RoundedCornerShape(14.dp))
                                .background(Palette.purpleTint)
                                .padding(horizontal = 12.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(Modifier.weight(1f)) {
                                BasicTextField(
                                    value = draft.title,
                                    onValueChange = { newTitle ->
                                        drafts = drafts.toMutableList().also {
                                            it[index] = it[index].copy(title = newTitle)
                                        }
                                    },
                                    singleLine = false,
                                    textStyle = TextStyle(
                                        fontSize = 14.5.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = Palette.ink,
                                    ),
                                    modifier = Modifier.fillMaxWidth(),
                                )
                                draft.due?.let { d ->
                                    Spacer(Modifier.height(4.dp))
                                    Row(
                                        Modifier
                                            .clip(RoundedCornerShape(20.dp))
                                            .background(Palette.card)
                                            .clickable {
                                                drafts = drafts.toMutableList().also {
                                                    it[index] = it[index].copy(due = null)
                                                }
                                            }
                                            .padding(horizontal = 8.dp, vertical = 3.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        Text(
                                            "📅 " + TodoParser.dueText(d),
                                            fontSize = 11.5.sp, fontWeight = FontWeight.SemiBold,
                                            color = Palette.purple,
                                        )
                                        Spacer(Modifier.width(4.dp))
                                        Text("✕", fontSize = 9.sp, color = Palette.subtle)
                                    }
                                }
                            }
                            Text(
                                "✕", fontSize = 14.sp, color = Palette.subtle,
                                modifier = Modifier
                                    .clickable {
                                        drafts = drafts.filterIndexed { i, _ -> i != index }
                                    }
                                    .padding(8.dp),
                            )
                        }
                    }

                    Spacer(Modifier.height(12.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        TextButton(
                            onClick = {
                                drafts = emptyList()
                                typed = ""
                                error = null
                                sessionActive = true
                                mode = "LISTEN"
                                startListening(true)
                            },
                        ) { Text("重说", fontSize = 14.sp, color = Palette.subtle) }
                        Box(Modifier.weight(1f)) {
                            PrimaryButton(text = "加入待办清单（${drafts.size}）") { save() }
                        }
                    }
                }
            }

            // 打字兜底：两种模式都可用，说的和写的走同一套拆分
            Spacer(Modifier.height(14.dp))
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp))
                    .background(Palette.background).padding(12.dp),
            ) {
                Text(
                    if (mode == "REVIEW") "还有要加的？继续打字" else "不方便说话？直接打字，也一样能拆成多条",
                    fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink,
                )
                Spacer(Modifier.height(6.dp))
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextInput(
                        label = "待办",
                        value = typed,
                        placeholder = "明天打疫苗，后天买 D3",
                        modifier = Modifier.weight(1f),
                        onChange = { typed = it },
                    )
                    Text(
                        "拆开", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = androidx.compose.ui.graphics.Color.White,
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(Palette.purple)
                            .clickable { parseTyped() }
                            .padding(horizontal = 14.dp, vertical = 12.dp),
                    )
                }
                if (error != null && mode != "LISTEN") {
                    Spacer(Modifier.height(6.dp))
                    Text(error!!, fontSize = 11.5.sp, color = Palette.warn)
                }
            }
        }
    }
}
