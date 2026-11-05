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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.zsonit.mengbao.data.Store
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

/** 定向同步可选的类别（与 iOS SyncView.scopeOptions 保持一致） */
private val SyncScreenScopes = listOf(
    "profile" to "宝宝档案（姓名/生日/头像/生日提醒）",
    "growth" to "生长记录（身高体重头围等）",
    "feed" to "喂养记录",
    "vaccine" to "疫苗接种（含自选/计划/其他接种）",
    "todo" to "待办事项",
    "size" to "尺码鞋服记录",
    "teeth" to "换牙记录",
    "settings" to "应用设置（家长身高/提醒等）",
)

/**
 * 配对同步：一台手机创建配对码，另一台输入同一个码，之后双方联网就自动双向同步全部资料。
 * 创建配对码的设备是「管理员」，可以在下面管理加入的设备（强制解绑 / 清除对方数据 / 定向同步指定类别）。
 */
@Composable
fun SyncScreen(onClose: () -> Unit) {
    val context = LocalContext.current
    var busyLocal by remember { mutableStateOf(false) }
    var joinText by remember { mutableStateOf("") }
    var errorText by remember { mutableStateOf<String?>(null) }
    var confirmPeer by remember { mutableStateOf<SyncManager.PeerDevice?>(null) }
    var confirmType by remember { mutableStateOf("unbind") }
    var scopePeer by remember { mutableStateOf<SyncManager.PeerDevice?>(null) }
    var scopeSel by remember { mutableStateOf(emptySet<String>()) }

    // 老版本升级：还没有管理员的配对，本机接任（建码方会在创建时自动登记为管理员）
    LaunchedEffect(Unit) { SyncManager.claimAdminIfVacant() }

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

                    // ── 设备管理（仅管理员可见）──
                    if (SyncManager.isAdmin(Store.state)) {
                        val peers = SyncManager.peers(Store.state)
                        Column(Modifier.fillMaxWidth().cardStyle(padding = 14.dp)) {
                            Text("设备管理", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Palette.ink)
                            Spacer(Modifier.height(6.dp))
                            if (peers.isEmpty()) {
                                Text(
                                    "还没有其他设备加入。家人手机输入这个配对码后，会出现在这里。",
                                    fontSize = 11.5.sp, color = Palette.subtle, lineHeight = 17.sp,
                                )
                            } else {
                                peers.forEach { peer ->
                                    Column(Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
                                        Text(peer.name, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
                                        Text("加入于 ${peer.joinedAt}", fontSize = 10.5.sp, color = Palette.subtle)
                                        Spacer(Modifier.height(6.dp))
                                        Row {
                                            Text(
                                                "同步数据",
                                                fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple,
                                                modifier = Modifier
                                                    .clip(CircleShape)
                                                    .clickable { scopeSel = emptySet(); scopePeer = peer }
                                                    .padding(horizontal = 4.dp, vertical = 4.dp),
                                            )
                                            Spacer(Modifier.width(16.dp))
                                            Text(
                                                "强制解绑",
                                                fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.warn,
                                                modifier = Modifier
                                                    .clip(CircleShape)
                                                    .clickable { confirmType = "unbind"; confirmPeer = peer }
                                                    .padding(horizontal = 4.dp, vertical = 4.dp),
                                            )
                                            Spacer(Modifier.width(16.dp))
                                            Text(
                                                "清除数据",
                                                fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.warn,
                                                modifier = Modifier
                                                    .clip(CircleShape)
                                                    .clickable { confirmType = "wipe"; confirmPeer = peer }
                                                    .padding(horizontal = 4.dp, vertical = 4.dp),
                                            )
                                        }
                                    }
                                }
                                Spacer(Modifier.height(6.dp))
                                Text(
                                    "· 同步数据：把选中的内容推送给对方覆盖（对方其他内容不动）\n· 强制解绑：对方立刻停止同步，资料保留\n· 清除数据：对方解除配对并删除全部资料，不可恢复\n· 指令在对方打开 App 后自动执行（3 天内有效）",
                                    fontSize = 10.5.sp, color = Palette.subtle, lineHeight = 15.sp,
                                )
                            }
                        }
                        Spacer(Modifier.height(12.dp))
                    }

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

    // ── 强制解绑 / 清除数据 的确认弹窗 ──
    confirmPeer?.let { peer ->
        AlertDialog(
            onDismissRequest = { confirmPeer = null },
            title = {
                Text(if (confirmType == "wipe") "清除「${peer.name}」的数据？" else "强制解绑「${peer.name}」？")
            },
            text = {
                Text(
                    if (confirmType == "wipe")
                        "对方手机将解除配对，并删除本机全部资料（宝宝、喂养、生长、接种等），无法恢复。"
                    else
                        "对方手机会立即停止同步（资料保留）；重新输入配对码可再次加入。",
                    lineHeight = 19.sp,
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    val type = confirmType
                    val target = peer
                    confirmPeer = null
                    thread {
                        val r = if (type == "wipe") SyncManager.wipeDevice(target.id) else SyncManager.forceUnbind(target.id)
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            Toast.makeText(context, r.message, Toast.LENGTH_SHORT).show()
                        }
                    }
                }) { Text(if (confirmType == "wipe") "清除数据" else "解绑", color = Palette.warn) }
            },
            dismissButton = {
                TextButton(onClick = { confirmPeer = null }) { Text("取消") }
            },
        )
    }

    // ── 定向同步内容选择弹窗 ──
    scopePeer?.let { peer ->
        AlertDialog(
            onDismissRequest = { scopePeer = null },
            title = { Text("同步数据给「${peer.name}」") },
            text = {
                Column {
                    Text(
                        "选中的内容会覆盖对方手机上的对应数据；没选的类别保持不变。",
                        fontSize = 12.sp, lineHeight = 17.sp,
                    )
                    Spacer(Modifier.height(8.dp))
                    SyncScreenScopes.forEach { opt ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    scopeSel = if (opt.first in scopeSel) scopeSel - opt.first else scopeSel + opt.first
                                },
                        ) {
                            Checkbox(checked = opt.first in scopeSel, onCheckedChange = null)
                            Text(opt.second, fontSize = 13.sp)
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(
                    enabled = scopeSel.isNotEmpty(),
                    onClick = {
                        val target = peer
                        val scopes = scopeSel.toList()
                        scopePeer = null
                        thread {
                            val r = SyncManager.pushScope(target.id, scopes)
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                Toast.makeText(context, r.message, Toast.LENGTH_SHORT).show()
                            }
                        }
                    },
                ) { Text("确认推送") }
            },
            dismissButton = {
                TextButton(onClick = { scopePeer = null }) { Text("取消") }
            },
        )
    }
}
