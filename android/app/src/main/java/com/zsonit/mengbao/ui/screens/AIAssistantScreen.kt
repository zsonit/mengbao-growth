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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.core.content.ContextCompat
import com.zsonit.mengbao.data.AIActionItem
import com.zsonit.mengbao.data.AIClient
import com.zsonit.mengbao.data.AIModel
import com.zsonit.mengbao.data.AIPlan
import com.zsonit.mengbao.data.AIAssistant
import com.zsonit.mengbao.data.AppLog
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.TopBar
import com.zsonit.mengbao.ui.cardStyle
import kotlinx.coroutines.launch
import java.util.UUID

// MARK: - AI 语音助手
//
// 说一句话 → 云端免费模型理解 → 直接记进 App（喂养/待办/身高体重/尺码），也能回答育儿问题。
// 不需要任何 API Key。

data class AITurn(
    val id: String = UUID.randomUUID().toString(),
    val ask: String,
    var reply: String = "",
    var streaming: Boolean = true,
    var items: List<AIActionItem> = emptyList(),
    var error: String? = null,
    var page: String? = null,
)

private val SUGGESTIONS = listOf(
    "宝宝刚喝了 120 的奶",
    "换了尿布，大便",
    "明天记得买纸尿裤",
    "今天睡了多久？",
)

@Composable
fun AIAssistantScreen(
    onBack: () -> Unit,
    onOpenPage: (String) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val turns = remember { mutableStateListOf<AITurn>() }
    val listState = rememberLazyListState()

    var typed by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var listening by remember { mutableStateOf(false) }
    var partial by remember { mutableStateOf("") }
    var micError by remember { mutableStateOf<String?>(null) }
    var showModels by remember { mutableStateOf(false) }
    var models by remember { mutableStateOf(listOf<AIModel>()) }
    var modelError by remember { mutableStateOf<String?>(null) }
    var model by remember { mutableStateOf("glm-5.3-flash") }

    val supported = remember { SpeechRecognizer.isRecognitionAvailable(context) }
    val recognizer = remember {
        if (supported) runCatching { SpeechRecognizer.createSpeechRecognizer(context) }.getOrNull() else null
    }

    fun send(text: String) {
        val content = text.trim()
        if (content.isEmpty() || busy) return
        busy = true
        val turn = AITurn(ask = content)
        turns.add(turn)
        scope.launch {
            try {
                val plan: AIPlan = AIAssistant.interpret(content, model)
                turns[turns.indexOfFirst { it.id == turn.id }] = turn.copy(
                    reply = plan.reply, items = plan.items, page = plan.openPage, streaming = false,
                )
            } catch (e: Exception) {
                AppLog.e("AI", "interpret 失败：${e.message}")
                turns[turns.indexOfFirst { it.id == turn.id }] = turn.copy(
                    error = e.message ?: "出了点问题，再说一次", streaming = false,
                )
            } finally {
                busy = false
            }
        }
    }

    fun stopListen() {
        listening = false
        runCatching { recognizer?.stopListening() }
        runCatching { recognizer?.cancel() }
        partial = ""
    }

    fun startListen() {
        val engine = recognizer
        if (engine == null) {
            micError = "这台设备没有语音识别服务，用下面的输入框打字也一样"
            return
        }
        micError = null
        partial = ""
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
                micError = "启动语音识别失败，可以直接打字"
            }
    }

    val listener = remember {
        object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) { listening = true }
            override fun onBeginningOfSpeech() = Unit
            override fun onRmsChanged(rmsdB: Float) = Unit
            override fun onBufferReceived(buffer: ByteArray?) = Unit
            override fun onEndOfSpeech() = Unit

            override fun onError(errorCode: Int) {
                listening = false
                partial = ""
                when (errorCode) {
                    SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT ->
                        micError = "没听到内容，点一下麦克风再说一次，或直接打字"
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                        micError = "没有麦克风权限，可以在系统设置里开一下"
                    else -> micError = "语音识别没成功，可以直接打字"
                }
            }

            override fun onResults(results: Bundle?) {
                listening = false
                val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull().orEmpty().trim()
                partial = ""
                if (text.isEmpty()) {
                    micError = "没听清，再说一次？"
                } else {
                    send(text)
                }
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
            runCatching { recognizer?.destroy() }
        }
    }

    val micPerm = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) startListen() else micError = "没有麦克风权限，用下面的输入框打字也一样"
    }

    LaunchedEffect(turns.size, busy) {
        if (turns.isNotEmpty()) listState.animateScrollToItem(turns.size - 1)
    }

    Column(Modifier.fillMaxSize().background(Palette.background).imePadding()) {
        TopBar(title = "AI 语音助手", onBack = onBack)

        // 模型选择
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "✨ ${models.firstOrNull { it.id == model }?.label ?: if (model == "auto") "自动" else model} ▾",
                fontSize = 12.sp, fontWeight = FontWeight.Medium, color = Palette.purple,
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(Palette.purpleTint)
                    .clickable { showModels = true }
                    .padding(horizontal = 11.dp, vertical = 6.dp),
            )
            Spacer(Modifier.weight(1f))
            Text("免费模型 · 无需配置", fontSize = 11.sp, color = Palette.subtle)
        }

        // 对话
        Box(Modifier.weight(1f)) {
            if (turns.isEmpty()) {
                EmptyIntro(onPick = { send(it) })
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(
                        start = 16.dp, end = 16.dp, top = 6.dp, bottom = 12.dp,
                    ),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    items(turns, key = { it.id }) { t ->
                        TurnCard(
                            turn = t,
                            onUndo = {
                                t.items.forEach { it.undo() }
                                val idx = turns.indexOfFirst { it.id == t.id }
                                if (idx >= 0) {
                                    turns[idx] = t.copy(items = emptyList(), reply = "已经撤销刚才的记录了。")
                                }
                            },
                            onOpenPage = onOpenPage,
                        )
                    }
                    if (busy) {
                        item {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                CircularProgressIndicator(Modifier.size(13.dp), strokeWidth = 1.6.dp)
                                Spacer(Modifier.width(7.dp))
                                Text("正在理解…", fontSize = 12.5.sp, color = Palette.subtle)
                            }
                        }
                    }
                }
            }
        }

        // 底部输入
        Column(Modifier.fillMaxWidth().background(Palette.background)) {
            if (listening || partial.isNotEmpty()) {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(Modifier.size(7.dp).clip(CircleShape).background(Palette.bad))
                    Spacer(Modifier.width(7.dp))
                    Text(
                        partial.ifEmpty { "我在听…" },
                        fontSize = 13.sp, color = Palette.ink2, maxLines = 2,
                    )
                }
            }
            micError?.let {
                Text(
                    it, fontSize = 11.5.sp, color = Palette.subtle,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 3.dp),
                )
            }

            Row(
                Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    Modifier
                        .size(50.dp)
                        .clip(CircleShape)
                        .background(if (listening) Palette.bad else Palette.purple)
                        .clickable(enabled = !busy) {
                            if (listening) {
                                stopListen()
                            } else if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
                                == PackageManager.PERMISSION_GRANTED
                            ) {
                                startListen()
                            } else {
                                micPerm.launch(Manifest.permission.RECORD_AUDIO)
                            }
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        if (listening) Icons.Filled.Stop else Icons.Filled.Mic,
                        contentDescription = "语音",
                        tint = Color.White,
                        modifier = Modifier.size(20.dp),
                    )
                }
                Spacer(Modifier.width(10.dp))
                TextField(
                    value = typed,
                    onValueChange = { typed = it },
                    placeholder = {
                        Text("也可以打字，比如：晚上八点体温 38 度", fontSize = 13.sp, color = Palette.subtle)
                    },
                    textStyle = androidx.compose.ui.text.TextStyle(fontSize = 13.5.sp, color = Palette.ink),
                    singleLine = false,
                    maxLines = 3,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                    keyboardActions = KeyboardActions(onSend = {
                        send(typed); typed = ""
                    }),
                    trailingIcon = {
                        if (typed.isNotBlank()) {
                            Icon(
                                Icons.Filled.ArrowUpward,
                                contentDescription = "发送",
                                tint = Palette.purple,
                                modifier = Modifier
                                    .size(30.dp)
                                    .clip(CircleShape)
                                    .clickable { send(typed); typed = "" }
                                    .padding(6.dp),
                            )
                        }
                    },
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = Palette.card,
                        unfocusedContainerColor = Palette.card,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                    ),
                    shape = RoundedCornerShape(22.dp),
                    modifier = Modifier.weight(1f),
                )
            }
            Text(
                "由云端免费模型理解，仅供记录辅助；医疗问题请及时就医",
                fontSize = 10.sp, color = Palette.subtle.copy(alpha = 0.8f),
                modifier = Modifier.fillMaxWidth().padding(bottom = 6.dp),
                textAlign = TextAlign.Center,
            )
        }
    }

    if (showModels) {
        ModelDialog(
            models = models,
            error = modelError,
            current = model,
            onLoad = {
                if (models.isEmpty()) {
                    scope.launch {
                        runCatching { AIClient.models() }
                            .onSuccess { models = it; modelError = null }
                            .onFailure { modelError = it.message }
                    }
                }
            },
            onPick = { model = it; showModels = false },
            onDismiss = { showModels = false },
        )
    }
}

@Composable
private fun EmptyIntro(onPick: (String) -> Unit) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 22.dp, vertical = 18.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(Modifier.size(86.dp).clip(CircleShape).background(Palette.purpleTint), contentAlignment = Alignment.Center) {
            Text("🎙️", fontSize = 34.sp)
        }
        Spacer(Modifier.height(16.dp))
        Text("说一句话就能记下来", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
        Spacer(Modifier.height(6.dp))
        Text(
            "比如「宝宝十点喝了 120 的奶」「明天买纸尿裤」\n也可以直接问「今天睡了多久」",
            fontSize = 12.5.sp, color = Palette.subtle, textAlign = TextAlign.Center, lineHeight = 19.sp,
        )
        Spacer(Modifier.height(18.dp))
        SUGGESTIONS.forEach { s ->
            Row(
                Modifier.fillMaxWidth().padding(vertical = 4.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Palette.card)
                    .clickable { onPick(s) }
                    .padding(horizontal = 14.dp, vertical = 11.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("“", fontSize = 13.sp, color = Palette.subtle)
                Text(s, fontSize = 13.sp, color = Palette.ink2)
                Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun TurnCard(turn: AITurn, onUndo: () -> Unit, onOpenPage: (String) -> Unit) {
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.End) {
        // 家长说的
        Box(
            Modifier
                .clip(RoundedCornerShape(14.dp))
                .background(Palette.purple)
                .padding(horizontal = 13.dp, vertical = 9.dp),
        ) {
            Text(turn.ask, fontSize = 14.sp, color = Color.White)
        }
        Spacer(Modifier.height(8.dp))

        // 助手回的
        Column(
            Modifier.fillMaxWidth().cardStyle(padding = 13.dp),
            horizontalAlignment = Alignment.Start,
        ) {
            when {
                turn.streaming -> Row(verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(Modifier.size(12.dp), strokeWidth = 1.5.dp)
                    Spacer(Modifier.width(7.dp))
                    Text("正在理解…", fontSize = 13.sp, color = Palette.subtle)
                }
                turn.error != null -> Text("⚠️ ${turn.error}", fontSize = 13.sp, color = Palette.ink2)
                else -> Text(turn.reply, fontSize = 14.sp, color = Palette.ink, lineHeight = 21.sp)
            }

            if (turn.items.isNotEmpty()) {
                Spacer(Modifier.height(9.dp))
                turn.items.forEach { item ->
                    Row(Modifier.fillMaxWidth().padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("✓", fontSize = 12.sp, color = Palette.ok)
                        Spacer(Modifier.width(6.dp))
                        Text(item.label, fontSize = 12.5.sp, color = Palette.ink2)
                    }
                }
                Spacer(Modifier.height(4.dp))
                Text(
                    "↩ 撤销", fontSize = 12.sp, color = Palette.bad,
                    modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickable { onUndo() }.padding(vertical = 4.dp),
                )
            }

            turn.page?.let { p ->
                Spacer(Modifier.height(8.dp))
                Text(
                    "打开${AIAssistant.pages.firstOrNull { it.first == p }?.second ?: "页面"} ›",
                    fontSize = 12.5.sp, fontWeight = FontWeight.Medium, color = Palette.purple,
                    modifier = Modifier
                        .clip(RoundedCornerShape(10.dp))
                        .background(Palette.purpleTint)
                        .clickable { onOpenPage(p) }
                        .padding(horizontal = 11.dp, vertical = 8.dp),
                )
            }
        }
    }
}

@Composable
private fun ModelDialog(
    models: List<AIModel>,
    error: String?,
    current: String,
    onLoad: () -> Unit,
    onPick: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    LaunchedEffect(Unit) { onLoad() }
    Dialog(onDismissRequest = onDismiss) {
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Palette.card)
                .padding(vertical = 16.dp),
        ) {
            Text(
                "选择模型", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Palette.ink,
                modifier = Modifier.padding(horizontal = 18.dp),
            )
            Text(
                "语音记录用「推荐」的快速模型就够；问复杂问题可以切「自动」",
                fontSize = 11.sp, color = Palette.subtle,
                modifier = Modifier.padding(horizontal = 18.dp, vertical = 6.dp),
            )
            Spacer(Modifier.height(4.dp))
            ModelRow("自动", "按任务自动挑模型，问答更聪明但慢一些", current == "auto") { onPick("auto") }
            if (error != null) {
                Text(error, fontSize = 12.sp, color = Palette.subtle, modifier = Modifier.padding(horizontal = 18.dp, vertical = 6.dp))
            } else if (models.isEmpty()) {
                Row(Modifier.padding(horizontal = 18.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(Modifier.size(12.dp), strokeWidth = 1.5.dp)
                    Spacer(Modifier.width(7.dp))
                    Text("正在获取…", fontSize = 12.5.sp, color = Palette.subtle)
                }
            }
            AIModel.quick(models).forEachIndexed { idx, m ->
                ModelRow(
                    if (idx == 0) m.label + "（推荐）" else m.label,
                    if (idx == 0) "速度快，2～3 秒出结果" else m.id,
                    current == m.id,
                ) { onPick(m.id) }
            }
        }
    }
}

@Composable
private fun ModelRow(title: String, sub: String, on: Boolean, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable { onClick() }.padding(horizontal = 18.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, fontSize = 14.sp, fontWeight = if (on) FontWeight.SemiBold else FontWeight.Normal, color = Palette.ink)
            Text(sub, fontSize = 11.sp, color = Palette.subtle)
        }
        if (on) Text("✓", fontSize = 13.sp, color = Palette.purple)
    }
}
