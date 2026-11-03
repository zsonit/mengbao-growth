package com.zsonit.mengbao.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.widget.Toast
import com.zsonit.mengbao.data.GrowthMath
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.data.SyncManager
import com.zsonit.mengbao.model.Sex
import com.zsonit.mengbao.model.SizeRecord
import com.zsonit.mengbao.model.TodoItem
import com.zsonit.mengbao.ui.ChipLabel
import com.zsonit.mengbao.ui.DateField
import com.zsonit.mengbao.ui.EmptyHint
import com.zsonit.mengbao.ui.NumberInput
import com.zsonit.mengbao.ui.Palette
import com.zsonit.mengbao.ui.PrimaryButton
import com.zsonit.mengbao.ui.SectionHeader
import com.zsonit.mengbao.ui.TagTone
import com.zsonit.mengbao.ui.TagView
import com.zsonit.mengbao.ui.TextInput
import com.zsonit.mengbao.ui.TopBar
import com.zsonit.mengbao.ui.Avatar
import com.zsonit.mengbao.ui.avatarFile
import com.zsonit.mengbao.ui.cardStyle
import com.zsonit.mengbao.ui.saveAvatarPhoto
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.ui.platform.LocalContext
import java.io.File
import java.time.LocalDate

// MARK: - 宝宝列表

@Composable
fun KidsScreen(onBack: () -> Unit, onEdit: (String?) -> Unit) {
    val children = Store.state.children
    val currentId = Store.state.currentId

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = "管理宝宝", onBack = onBack)
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
            children.forEach { kid ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 10.dp)
                        .cardStyle(padding = 14.dp, radius = 16.dp)
                        .clickable { onEdit(kid.id) },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Avatar(child = kid, size = 44.dp, fontSize = 24.sp, bg = Palette.purpleSoft)
                    Spacer(Modifier.width(12.dp))
                    Column {
                        Text(kid.name, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
                        Text(
                            "${kid.sex.label} · ${GrowthMath.ageText(kid.birthDate)}",
                            fontSize = 12.sp, color = Palette.subtle,
                        )
                    }
                    Spacer(Modifier.weight(1f))
                    if (kid.id == currentId) {
                        TagView(text = "当前", tone = TagTone.OK)
                    } else {
                        Text(
                            "切换", fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple,
                            modifier = Modifier.clickable { Store.selectChild(kid.id); onBack() }.padding(4.dp),
                        )
                    }
                }
            }
            PrimaryButton(text = "＋ 添加宝宝", filled = false, onClick = { onEdit(null) })
        }
    }
}

// MARK: - 宝宝档案编辑

private val KidAvatars = listOf("👶", "👧", "👦", "🧒", "🐣", "🐰", "🐻", "🦊")

@Composable
fun KidEditorScreen(childId: String?, onBack: () -> Unit) {
    val child = childId?.let { id -> Store.state.children.firstOrNull { it.id == id } }

    var name by remember(childId) { mutableStateOf(child?.name ?: "") }
    var sex by remember(childId) { mutableStateOf(child?.sex ?: Sex.BOY) }
    var birthDate by remember(childId) { mutableStateOf(child?.birthDate ?: LocalDate.now()) }
    var avatar by remember(childId) { mutableStateOf(child?.displayAvatar ?: "👦") }
    var avatarPath by remember(childId) { mutableStateOf(child?.avatarPath) }
    var errorMessage by remember(childId) { mutableStateOf<String?>(null) }
    var showDeleteAlert by remember { mutableStateOf(false) }

    val context = LocalContext.current
    val photoPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia(),
    ) { uri ->
        val target = child ?: return@rememberLauncherForActivityResult
        if (uri != null) {
            val saved = saveAvatarPhoto(context, target.id, uri)
            if (saved != null) {
                avatarPath = "avatars/${target.id}.jpg"
                Store.updateChild(target.copy(avatarPath = avatarPath))
            }
        }
    }

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = if (child == null) "添加宝宝" else "编辑档案", onBack = onBack)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Column(
                Modifier.fillMaxWidth().cardStyle(),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                EditorField(label = "宝宝昵称") {
                    TextInput(
                        label = "宝宝昵称", value = name, placeholder = "如：小满",
                        onChange = { name = it },
                    )
                }
                EditorField(label = "出生日期") {
                    DateField(
                        label = "出生日期", date = birthDate,
                        onDate = { birthDate = it },
                    )
                }
                EditorField(label = "性别（决定使用哪套生长标准）") {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Sex.entries.forEach { s ->
                            ChipLabel(
                                text = s.label, selected = sex == s, icon = s.symbol,
                                onClick = {
                                    sex = s
                                    if (KidAvatars.contains(avatar)) avatar = s.symbol
                                },
                            )
                        }
                    }
                }
                EditorField(label = "头像") {
                    LazyVerticalGrid(
                        columns = GridCells.Fixed(8),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.height(88.dp),
                    ) {
                        items(KidAvatars.size) { i ->
                            val a = KidAvatars[i]
                            val selected = avatar == a && avatarPath == null
                            Text(
                                a, fontSize = 21.sp,
                                modifier = Modifier
                                    .size(40.dp)
                                    .clip(CircleShape)
                                    .background(if (selected) Palette.purpleSoft else Palette.purpleTint)
                                    .border(2.dp, if (selected) Palette.purple else Palette.hairline, CircleShape)
                                    .clickable { avatar = a; avatarPath = null }
                                    .wrapContentSize(Alignment.Center),
                            )
                        }
                    }
                }
                if (child != null) {
                    EditorField(label = "照片头像（选了照片则优先显示）") {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Avatar(
                                child = child.copy(avatarPath = avatarPath),
                                size = 56.dp, fontSize = 26.sp,
                            )
                            Spacer(Modifier.width(14.dp))
                            Text(
                                if (avatarPath == null) "📷 从相册选一张照片"
                                else "📷 更换照片",
                                fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple,
                                modifier = Modifier
                                    .clip(CircleShape)
                                    .background(Palette.purpleTint)
                                    .clickable {
                                        photoPicker.launch(
                                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                                        )
                                    }
                                    .padding(horizontal = 14.dp, vertical = 9.dp),
                            )
                            if (avatarPath != null) {
                                Spacer(Modifier.width(10.dp))
                                Text(
                                    "移除", fontSize = 13.sp, color = Palette.bad,
                                    modifier = Modifier
                                        .clip(CircleShape)
                                        .background(Palette.badBg)
                                        .clickable {
                                            avatarFile(context, child.id).delete()
                                            avatarPath = null
                                            Store.updateChild(child.copy(avatarPath = null))
                                        }
                                        .padding(horizontal = 12.dp, vertical = 9.dp),
                                )
                            }
                        }
                    }
                }
            }

            if (errorMessage != null) {
                Text(
                    errorMessage ?: "", fontSize = 13.sp, color = Palette.bad,
                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
                        .background(Palette.badBg).padding(12.dp),
                )
            }

            PrimaryButton(text = if (child == null) "创建档案" else "保存档案", onClick = {
                val trimmed = name.trim()
                if (trimmed.isEmpty()) {
                    errorMessage = "给宝宝起个名字吧"
                } else {
                    val existing = child
                    if (existing != null) {
                        Store.updateChild(existing.copy(name = trimmed, sex = sex, birthDate = birthDate, avatar = avatar, avatarPath = avatarPath))
                    } else {
                        Store.addChild(name = trimmed, sex = sex, birthDate = birthDate, avatar = avatar)
                    }
                    onBack()
                }
            })

            if (child != null) {
                PrimaryButton(text = "删除这个宝宝", filled = false, onClick = { showDeleteAlert = true })
            }

            Text(
                "出生日期决定月龄与百分位计算，请填写准确。早产宝宝的矫正月龄可写在备注里，评估时以医生意见为准。",
                fontSize = 12.sp, color = Palette.subtle,
            )
        }
    }

    if (showDeleteAlert && child != null) {
        AlertDialog(
            onDismissRequest = { showDeleteAlert = false },
            title = { Text("删除这个宝宝？") },
            text = { Text("将同时删除该宝宝的全部生长、喂养与接种记录，且无法撤销。") },
            confirmButton = {
                TextButton(onClick = {
                    Store.deleteChild(child.id)
                    showDeleteAlert = false
                    onBack()
                }) { Text("删除", color = Palette.bad) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteAlert = false }) { Text("取消", color = Palette.ink2) }
            },
        )
    }
}

@Composable
private fun EditorField(label: String, content: @Composable () -> Unit) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(13.dp))
            .background(Palette.purpleTint).padding(horizontal = 13.dp, vertical = 10.dp),
    ) {
        Text(label, fontSize = 11.5.sp, color = Palette.subtle)
        Spacer(Modifier.height(6.dp))
        content()
    }
}

// MARK: - 尺码编辑

@Composable
fun SizeEditorScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    var foot by remember { mutableStateOf("") }
    var height by remember { mutableStateOf("") }
    var shoulder by remember { mutableStateOf("") }
    var waist by remember { mutableStateOf("") }
    var hip by remember { mutableStateOf("") }
    var thigh by remember { mutableStateOf("") }
    var calf by remember { mutableStateOf("") }
    var topLength by remember { mutableStateOf("") }
    var sleeve by remember { mutableStateOf("") }
    var pantsLength by remember { mutableStateOf("") }
    var shoeSize by remember { mutableStateOf("") }
    var shoeInner by remember { mutableStateOf("") }
    var note by remember { mutableStateOf("") }
    /** 用户动过任何一个输入框后就不再自动回填，避免覆盖他正在输入的内容 */
    var edited by remember { mutableStateOf(false) }

    val child = Store.current
    val s = GrowthMath.shoeSize(foot.toDoubleOrNull(), height.toDoubleOrNull())
    // 订阅同步状态：对端推来新数据后这里会变，页面自动跟上（不用退出重进）
    val syncTick = SyncManager.lastSyncAt

    // 和 iOS 一致：进页面就把「最近一次成长记录 + 最近一条尺码记录」回填到输入框。
    // 另外，同步拉回新数据时会再刷一次，保证两台手机看到同一份。
    LaunchedEffect(child?.id, child?.sizes?.size, child?.records?.size, syncTick) {
        val c = child ?: return@LaunchedEffect
        if (edited) return@LaunchedEffect
        // 只取「有内容」的最新一条；同一天有多条时取字段最全的那条（两端规则一致）
        val last = c.sizes.filter { it.hasContent }
            .maxWithOrNull(compareBy({ it.date }, { it.filledCount }))
        fun f(v: Double?) = v?.let { fmt1(it) } ?: ""
        foot = f(c.latestRecord?.footLength ?: last?.footLength)
        height = f(c.latestRecord?.height ?: last?.height)
        shoulder = f(last?.shoulder)
        waist = f(last?.waist)
        hip = f(last?.hip)
        thigh = f(last?.thigh)
        calf = f(last?.calf)
        topLength = f(last?.topLength)
        sleeve = f(last?.sleeve)
        pantsLength = f(last?.pantsLength)
        shoeInner = f(last?.shoeInner)
        shoeSize = last?.shoeSize?.toString() ?: ""
    }

    // 打开页面先跟云端对一次：另一端刚改的尺码不用等轮询就能看到
    LaunchedEffect(Unit) { SyncManager.requestSync() }

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = "鞋服尺码", onBack = onBack)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Column(Modifier.fillMaxWidth().cardStyle(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    NumberInput(
                        label = "脚长", value = foot, unit = "cm",
                        modifier = Modifier.weight(1f), onChange = { edited = true; foot = it },
                    )
                    NumberInput(
                        label = "身高", value = height, unit = "cm",
                        modifier = Modifier.weight(1f), onChange = { edited = true; height = it },
                    )
                }
                TextInput(label = "备注", value = note, placeholder = "如：换季运动鞋", onChange = { edited = true; note = it })
            }

            // 自动换算卡：进页面就能看到，填了脚长/身高立即出结果
            Column(Modifier.fillMaxWidth().cardStyle(padding = 14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("📏 自动换算", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple)
                Text(
                    "填上面的脚长 / 身高，这里自动算出该穿的鞋码和衣服码",
                    fontSize = 11.sp, color = Palette.subtle,
                )
                if (s.cn != null || s.top != null) {
                    Spacer(Modifier.height(2.dp))
                    s.cn?.let { cn -> s.eu?.let { eu -> RowText("中国码", "$cn 码") } }
                    s.cn?.let { cn -> s.eu?.let { eu -> RowText("欧码", "$eu 码") } }
                    s.inner?.let { RowText("建议内长", "$it cm") }
                    s.top?.let { RowText("上衣", it) }
                    s.pant?.let { RowText("裤子", it) }
                    s.hip?.let { RowText("裤长", it) }
                } else {
                    Text(
                        "中国码 ≈ 脚长 × 2 − 10 · 欧码 ≈ 脚长 × 1.5 + 2 · 内长 ≈ 脚长 + 0.8",
                        fontSize = 12.sp, color = Palette.ink2, lineHeight = 17.sp,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }

            Column(Modifier.fillMaxWidth().cardStyle(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("身体围度（选填 · cm）", fontSize = 11.5.sp, color = Palette.subtle)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    NumberInput(
                        label = "肩宽", value = shoulder, unit = "cm",
                        modifier = Modifier.weight(1f), onChange = { edited = true; shoulder = it },
                    )
                    NumberInput(
                        label = "腰围", value = waist, unit = "cm",
                        modifier = Modifier.weight(1f), onChange = { edited = true; waist = it },
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    NumberInput(
                        label = "臀围", value = hip, unit = "cm",
                        modifier = Modifier.weight(1f), onChange = { edited = true; hip = it },
                    )
                    NumberInput(
                        label = "大腿围", value = thigh, unit = "cm",
                        modifier = Modifier.weight(1f), onChange = { edited = true; thigh = it },
                    )
                }
                NumberInput(
                    label = "小腿围", value = calf, unit = "cm",
                    modifier = Modifier.fillMaxWidth(), onChange = { edited = true; calf = it },
                )

                Text("衣物尺寸（选填 · cm）", fontSize = 11.5.sp, color = Palette.subtle)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    NumberInput(
                        label = "衣长", value = topLength, unit = "cm",
                        modifier = Modifier.weight(1f), onChange = { edited = true; topLength = it },
                    )
                    NumberInput(
                        label = "袖长", value = sleeve, unit = "cm",
                        modifier = Modifier.weight(1f), onChange = { edited = true; sleeve = it },
                    )
                }
                NumberInput(
                    label = "裤长", value = pantsLength, unit = "cm",
                    modifier = Modifier.fillMaxWidth(), onChange = { edited = true; pantsLength = it },
                )

                Text("鞋（选填）", fontSize = 11.5.sp, color = Palette.subtle)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    NumberInput(
                        label = "穿鞋码数", value = shoeSize, unit = "码",
                        modifier = Modifier.weight(1f), onChange = { edited = true; shoeSize = it },
                    )
                    NumberInput(
                        label = "鞋内长", value = shoeInner, unit = "cm",
                        modifier = Modifier.weight(1f), onChange = { edited = true; shoeInner = it },
                    )
                }
            }

            PrimaryButton(text = "保存尺码", onClick = {
                val anyFilled = listOf(foot, height, shoulder, waist, hip, thigh, calf, topLength, sleeve, pantsLength, shoeSize, shoeInner)
                    .any { it.isNotBlank() }
                if (!anyFilled) {
                    Toast.makeText(context, "请先填写脚长或身高", Toast.LENGTH_SHORT).show()
                } else {
                    Store.addSize(
                        SizeRecord(
                            date = LocalDate.now(),
                            footLength = foot.toDoubleOrNull(),
                            height = height.toDoubleOrNull(),
                            shoulder = shoulder.toDoubleOrNull(),
                            waist = waist.toDoubleOrNull(),
                            hip = hip.toDoubleOrNull(),
                            thigh = thigh.toDoubleOrNull(),
                            calf = calf.toDoubleOrNull(),
                            topLength = topLength.toDoubleOrNull(),
                            sleeve = sleeve.toDoubleOrNull(),
                            pantsLength = pantsLength.toDoubleOrNull(),
                            shoeSize = shoeSize.toIntOrNull(),
                            shoeInner = shoeInner.toDoubleOrNull(),
                            note = note.trim(),
                        ),
                    )
                    Toast.makeText(context, "已保存尺码", Toast.LENGTH_SHORT).show()
                    foot = ""; height = ""; shoulder = ""; waist = ""; hip = ""; thigh = ""; calf = ""
                    topLength = ""; sleeve = ""; pantsLength = ""; shoeSize = ""; shoeInner = ""; note = ""
                }
            })

            SectionHeader(title = "历史尺码")
            val sizes = child?.sizes?.filter { it.hasContent }?.sortedByDescending { it.date } ?: emptyList()
            if (sizes.isEmpty()) {
                EmptyHint(text = "还没有尺码记录")
            } else {
                sizes.forEach { size ->
                    Column(Modifier.fillMaxWidth().cardStyle(padding = 14.dp, radius = 14.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(GrowthMath.dateString(size.date), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink2)
                            Spacer(Modifier.weight(1f))
                            IconButton(onClick = { Store.deleteSize(size.id) }, modifier = Modifier.size(28.dp)) {
                                Icon(Icons.Outlined.Delete, contentDescription = "删除", tint = Palette.bad, modifier = Modifier.size(14.dp))
                            }
                        }
                        // 和 iOS 一致：先展示由脚长/身高推算出来的码数，再列手填的围度
                        val calc = GrowthMath.shoeSize(size.footLength, size.height)
                        val cn = calc.cn
                        val eu = calc.eu
                        val top = calc.top
                        val pant = calc.pant
                        if (cn != null && eu != null) {
                            Text(
                                "脚长 ${fmt1(size.footLength ?: 0.0)}cm → 中国码 $cn / 欧码 $eu",
                                fontSize = 13.5.sp, color = Palette.ink,
                            )
                        }
                        if (top != null && pant != null) {
                            Text("上衣 $top · 裤子 $pant", fontSize = 13.5.sp, color = Palette.ink)
                        }
                        val parts = buildList {
                            if (cn == null) size.footLength?.let { add("脚长 ${fmt1(it)}cm") }
                            if (top == null) size.height?.let { add("身高 ${fmt1(it)}cm") }
                            size.shoeSize?.let { add("穿鞋 ${it} 码") }
                            size.shoeInner?.let { add("内长 ${fmt1(it)}cm") }
                            size.shoulder?.let { add("肩宽 ${fmt1(it)}") }
                            size.waist?.let { add("腰围 ${fmt1(it)}") }
                            size.hip?.let { add("臀围 ${fmt1(it)}") }
                            size.thigh?.let { add("大腿围 ${fmt1(it)}") }
                            size.calf?.let { add("小腿围 ${fmt1(it)}") }
                            size.topLength?.let { add("衣长 ${fmt1(it)}") }
                            size.sleeve?.let { add("袖长 ${fmt1(it)}") }
                            size.pantsLength?.let { add("裤长 ${fmt1(it)}") }
                        }
                        if (parts.isNotEmpty()) Text(parts.joinToString(" · "), fontSize = 13.5.sp, color = Palette.ink)
                        if (size.note.isNotEmpty()) Text(size.note, fontSize = 12.sp, color = Palette.subtle)
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}

@Composable
private fun RowText(key: String, value: String) {
    Row(Modifier.fillMaxWidth()) {
        Text(key, fontSize = 13.sp, color = Palette.subtle)
        Spacer(Modifier.weight(1f))
        Text(value, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
    }
}

private fun fmt1(v: Double): String = String.format(java.util.Locale.US, "%.1f", v)

// MARK: - 待办编辑

@Composable
fun TodoEditorScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    var text by remember { mutableStateOf("") }
    var showVoice by remember { mutableStateOf(false) }
    val todos = Store.current?.todos?.sortedWith(compareBy({ it.done }, { it.id })) ?: emptyList()

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = "待办清单", onBack = onBack)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                TextInput(
                    label = "新待办", value = text, placeholder = "如：预约疫苗接种",
                    modifier = Modifier.weight(1f), onChange = { text = it },
                )
                // 语音加待办：一次说好几件都行，日期也会一起认出来
                IconButton(
                    onClick = { showVoice = true },
                    modifier = Modifier.size(46.dp).clip(CircleShape).background(Palette.pinkGradient),
                ) {
                    Icon(
                        Icons.Outlined.Mic, contentDescription = "语音添加待办",
                        tint = Color.White, modifier = Modifier.size(20.dp),
                    )
                }
                IconButton(
                    onClick = {
                        val t = text.trim()
                        if (t.isEmpty()) {
                            Toast.makeText(context, "先写点内容", Toast.LENGTH_SHORT).show()
                        } else {
                            Store.addTodo(TodoItem(title = t))
                            text = ""
                        }
                    },
                    modifier = Modifier.size(44.dp).clip(CircleShape).background(Palette.purple),
                ) {
                    Icon(Icons.Outlined.Add, contentDescription = "添加", tint = Color.White)
                }
            }

            Text(
                "🎤 点麦克风说话添加：「明天打疫苗，后天买维生素 D3，周五去体检」会自动拆成 3 条，日期也一起记上",
                fontSize = 11.5.sp,
                color = Palette.purple,
            )

            if (todos.isEmpty()) {
                EmptyHint(text = "还没有待办事项")
            } else {
                todos.forEach { todo ->
                    Row(
                        modifier = Modifier.fillMaxWidth().cardStyle(padding = 10.dp, radius = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Checkbox(
                            checked = todo.done,
                            onCheckedChange = { Store.toggleTodo(todo.id) },
                            colors = CheckboxDefaults.colors(checkedColor = Palette.purple),
                        )
                        Text(
                            todo.title,
                            fontSize = 14.sp,
                            color = if (todo.done) Palette.subtle else Palette.ink,
                            textDecoration = if (todo.done) TextDecoration.LineThrough else null,
                            modifier = Modifier.weight(1f),
                        )
                        IconButton(onClick = { Store.deleteTodo(todo.id) }, modifier = Modifier.size(28.dp)) {
                            Icon(Icons.Outlined.Delete, contentDescription = "删除", tint = Palette.bad, modifier = Modifier.size(14.dp))
                        }
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }

    if (showVoice) {
        TodoVoiceDialog(onDismiss = { showVoice = false }) { count ->
            Toast.makeText(context, "已加入 $count 条待办", Toast.LENGTH_SHORT).show()
        }
    }
}

// MARK: - 阶段重点

@Composable
fun StageScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val child = Store.current
    val milestones = child?.let { GrowthMath.milestones(it) } ?: emptyList()

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = "阶段重点", onBack = onBack)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            if (child == null) {
                EmptyHint(text = "先添加宝宝档案")
            } else {
                Text(
                    "${child.name} · ${GrowthMath.ageText(child.birthDate)} 这个阶段的关注重点：",
                    fontSize = 13.sp, color = Palette.subtle,
                )
                milestones.forEach { milestone ->
                    // 实时读待办列表：已加入显示 ✓，避免重复添加
                    val added = Store.current?.todos?.any { it.title == milestone } == true
                    Column(Modifier.fillMaxWidth().cardStyle(padding = 14.dp, radius = 14.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(milestone, fontSize = 14.sp, color = Palette.ink, modifier = Modifier.weight(1f))
                            Text(
                                if (added) "✓ 已加入" else "＋ 加入待办",
                                fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold,
                                color = if (added) Palette.ok else Palette.purple,
                                modifier = Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .clickable(enabled = !added) {
                                        Store.addTodo(TodoItem(title = milestone))
                                        Toast.makeText(context, "已加入待办清单", Toast.LENGTH_SHORT).show()
                                    }
                                    .padding(horizontal = 6.dp, vertical = 8.dp),
                            )
                        }
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}
