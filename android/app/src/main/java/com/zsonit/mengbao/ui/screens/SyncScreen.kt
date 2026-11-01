package com.zsonit.mengbao.ui.screens

import android.widget.Toast
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
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.zsonit.mengbao.data.SyncManager
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.PrimaryButton
import com.zsonit.mengbao.ui.TextInput
import com.zsonit.mengbao.ui.TopBar
import com.zsonit.mengbao.ui.cardStyle
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.concurrent.thread

/**
 * 配对同步：一台手机创建配对码，另一台输入同一个码，之后双方联网就自动双向同步全部资料。
 */
@Composable
fun SyncScreen(onClose: () -> Unit) {
    val context = LocalContext.current
    var busyLocal by remember { mutableStateOf(false) }
    var joinText by remember { mutableStateOf("") }
    var errorText by remember { mutableStateOf<String?>(null) }

    fun runBlock(toast: Boolean, block: () -> com.zsonit.mengbao.data.SyncResult) {
        busyLocal = true
        thread {
            val r = block()
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                busyLocal = false
                if (toast || !r.ok) {
                    Toast.makeText(context, r.message, Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    Dialog(onDismissRequest = onClose, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(
            Modifier
                .fillMaxWidth(0.94f)
                .clip(RoundedCornerShape(22.dp))
                .background(Palette.background)
                .padding(0.dp),
        ) {
            TopBar(title = "☁️ 配对同步", onBack = onClose)

            Column(
                Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                val showCode = SyncManager.pairedCode
                if (showCode == null) {
                    // ── 未配对 ──
                    Column(Modifier.fillMaxWidth().cardStyle(padding = 14.dp)) {
                        Text("怎么用", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Palette.ink)
                        Spacer(Modifier.height(6.dp))
                        Text(
                            "① 这台手机点「创建配对码」\n② 家人手机输入同一个码\n③ 之后所有手机联网就自动同步全部资料\n（爷爷奶奶、外公外婆的手机都可以加，数量不限）",
                            fontSize = 12.5.sp, color = Palette.ink2, lineHeight = 20.sp,
                        )
                        Spacer(Modifier.height(12.dp))
                        PrimaryButton(text = if (busyLocal) "正在创建…" else "创建配对码", enabled = !busyLocal) {
                            runBlock(false) { SyncManager.createPairing() }
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                    Column(Modifier.fillMaxWidth().cardStyle(padding = 14.dp)) {
                        Text("已有配对码？", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Palette.ink)
                        Spacer(Modifier.height(8.dp))
                        TextInput(
                            label = "输入对方的 6 位配对码",
                            value = joinText,
                            placeholder = "如 520131",
                            onChange = { joinText = it.filter { c -> c.isDigit() }.take(6) },
                        )
                        Spacer(Modifier.height(10.dp))
                        PrimaryButton(
                            text = if (busyLocal) "正在配对…" else "加入配对",
                            enabled = !busyLocal && joinText.isNotBlank(),
                        ) {
                            errorText = null
                            runBlock(false) { SyncManager.joinPairing(joinText) }
                        }
                        if (errorText != null) {
                            Spacer(Modifier.height(8.dp))
                            Text(errorText.orEmpty(), fontSize = 11.5.sp, color = Palette.warn)
                        }
                    }
                } else {
                    // ── 已配对 ──
                    Column(Modifier.fillMaxWidth().cardStyle(padding = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("配对码", fontSize = 12.sp, color = Palette.subtle)
                        Spacer(Modifier.height(4.dp))
                        Text(
                            showCode.chunked(3).joinToString(" "),
                            fontSize = 34.sp, fontWeight = FontWeight.Bold,
                            color = Palette.purpleDeep, letterSpacing = 2.sp,
                        )
                        Spacer(Modifier.height(6.dp))
                        Text(
                            "把这个码告诉家人，任何一台手机装好萌宝成长后在「我的 → 配对同步」输入即可加入，数量不限",
                            fontSize = 11.5.sp, color = Palette.subtle, textAlign = TextAlign.Center,
                            lineHeight = 17.sp,
                        )
                    }
                    Spacer(Modifier.height(12.dp))
                    Column(Modifier.fillMaxWidth().cardStyle(padding = 14.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text("上次同步", fontSize = 12.5.sp, color = Palette.ink2)
                                Text(
                                    if (SyncManager.lastSyncAt == 0L) "还没同步过"
                                    else SimpleDateFormat("MM-dd HH:mm", Locale.getDefault()).format(Date(SyncManager.lastSyncAt)),
                                    fontSize = 11.5.sp, color = Palette.subtle,
                                )
                            }
                            if (SyncManager.busy || busyLocal) {
                                CircularProgressIndicator(strokeWidth = 2.dp, modifier = Modifier.size(18.dp), color = Palette.purple)
                            }
                        }
                        if (SyncManager.lastMessage != null) {
                            Spacer(Modifier.height(6.dp))
                            Text(SyncManager.lastMessage.orEmpty(), fontSize = 11.5.sp, color = Palette.subtle)
                        }
                        Spacer(Modifier.height(12.dp))
                        PrimaryButton(
                            text = if (SyncManager.busy || busyLocal) "同步中…" else "立即同步",
                            enabled = !SyncManager.busy && !busyLocal,
                        ) {
                            runBlock(true) { SyncManager.syncNow(manual = true) }
                        }
                        Spacer(Modifier.height(8.dp))
                        Text(
                            "解除配对",
                            fontSize = 12.5.sp, color = Palette.warn, fontWeight = FontWeight.SemiBold,
                            modifier = Modifier
                                .clip(CircleShape)
                                .clickable(enabled = !busyLocal) {
                                    runBlock(true) { SyncManager.unlink() }
                                }
                                .padding(horizontal = 14.dp, vertical = 8.dp),
                        )
                        Text(
                            "解除后：本机和云端的资料都不会消失，只是不再同步；重新输入配对码可再次加入",
                            fontSize = 10.5.sp, color = Palette.subtle, textAlign = TextAlign.Center,
                            lineHeight = 15.sp,
                        )
                    }
                }

                Spacer(Modifier.height(14.dp))
                Column(Modifier.fillMaxWidth().cardStyle(padding = 12.dp)) {
                    Text(
                        "* 一个配对码可以加到多部手机（爸爸妈妈、爷爷奶奶都能加），大家看到的是同一份资料\n* 一台手机改了数据：2~3 秒内自动上传；其他手机开着 App 时约 12 秒内自动拉取，切回 App 会立刻同步\n* 同步内容：宝宝档案、喂养、生长、换牙、接种、尺码、待办\n* 各自新增的记录都会保留；同一处改动，后改的生效\n* 显示设置以本机为准\n* 解除配对只会停止同步：本机与云端的资料都保留\n* 端到端加密：资料在手机上用配对码加密后才上传，云端只存密文，服务器也读不到内容\n* 配对码就是唯一的钥匙，请只告诉家人",
                        fontSize = 11.sp, color = Palette.subtle, lineHeight = 17.sp,
                    )
                }
            }
        }
    }
}
