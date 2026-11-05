package com.zsonit.mengbao.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTransformGestures
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.unit.dp
import androidx.exifinterface.media.ExifInterface
import com.zsonit.mengbao.model.Child
import java.io.File
import java.io.FileOutputStream

/** 头像照片文件位置：filesDir/avatars/<childId>.jpg（旧版固定名，读取兼容用） */
fun avatarFile(context: Context, childId: String): File =
    File(File(context.filesDir, "avatars"), "$childId.jpg")

/** 按相对路径取文件（如 avatars/<id>-<stamp>.jpg） */
fun avatarFileByRel(context: Context, rel: String?): File? {
    if (rel.isNullOrBlank()) return null
    return File(context.filesDir, rel)
}

/**
 * 从相册 Uri 解码并按 EXIF 修正方向、降采样，返回用于裁剪的位图。失败返回 null。
 */
fun loadOrientedBitmap(context: Context, uri: Uri, sizePx: Int = 1280): Bitmap? {
    return runCatching {
        val src = context.contentResolver.openInputStream(uri) ?: return null
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        src.use { BitmapFactory.decodeStream(it, null, opts) }
        val sample = maxOf(1, maxOf(opts.outWidth, opts.outHeight) / (sizePx * 2))
        val src2 = context.contentResolver.openInputStream(uri) ?: return null
        val opts2 = BitmapFactory.Options().apply { inSampleSize = sample }
        val bmp = src2.use { BitmapFactory.decodeStream(it, null, opts2) } ?: return null

        val rotation = runCatching {
            context.contentResolver.openInputStream(uri)?.use {
                when (ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)) {
                    ExifInterface.ORIENTATION_ROTATE_90 -> 90
                    ExifInterface.ORIENTATION_ROTATE_180 -> 180
                    ExifInterface.ORIENTATION_ROTATE_270 -> 270
                    else -> 0
                }
            } ?: 0
        }.getOrDefault(0)
        if (rotation != 0) {
            Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height,
                Matrix().apply { postRotate(rotation.toFloat()) }, true)
        } else bmp
    }.getOrNull()
}

/**
 * 把裁剪好的方形头像位图缩到 sizePx 存为 JPEG。
 * 文件名带时间戳（唯一），并删除旧文件：避免固定路径下解码缓存导致「更换照片后界面不刷新」。
 * 返回保存后的文件，失败返回 null。
 */
fun saveAvatarPhoto(context: Context, childId: String, bitmap: Bitmap, oldRelPath: String? = null, sizePx: Int = 512): File? {
    return runCatching {
        val scaled = Bitmap.createScaledBitmap(bitmap, sizePx, sizePx, true)
        val dir = File(context.filesDir, "avatars")
        dir.mkdirs()
        // 删除旧照片文件
        avatarFileByRel(context, oldRelPath)?.delete()
        val out = File(dir, "$childId-${System.currentTimeMillis()}.jpg")
        FileOutputStream(out).use { scaled.compress(Bitmap.CompressFormat.JPEG, 88, it) }
        out
    }.getOrNull()
}

/** 有自定义照片则显示照片，否则显示 emoji 头像（样式与旧版一致）。 */
@Composable
fun Avatar(
    child: Child,
    size: Dp,
    fontSize: TextUnit,
    bg: Color = Palette.pinkBg,
    shape: Shape = CircleShape,
) {
    val context = LocalContext.current
    var reloadTick by remember(child.avatarPath) { mutableStateOf(0) }
    val bitmap by produceState<Bitmap?>(initialValue = null, child.avatarPath, reloadTick) {
        value = child.avatarPath?.let {
            runCatching {
                // 新版按 avatarPath 相对路径读取；兼容旧版固定名文件
                val f = avatarFileByRel(context, it) ?: avatarFile(context, child.id)
                if (f != null && f.exists()) BitmapFactory.decodeFile(f.absolutePath) else null
            }.getOrNull()
        }
    }
    Box(
        Modifier.size(size).clip(shape).background(bg),
        contentAlignment = Alignment.Center,
    ) {
        if (bitmap != null) {
            Image(
                bitmap = bitmap!!.asImageBitmap(),
                contentDescription = "头像",
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(size).clip(shape),
            )
        } else {
            Text(child.displayAvatar, fontSize = fontSize)
        }
    }
}

// MARK: - 头像方形裁剪（双指缩放 + 拖动调整角度）

/**
 * 选照片后弹出：方框内双指缩放、拖动平移，确认后按方框可视区域裁剪出正方形头像。
 */
@Composable
fun AvatarCropDialog(
    source: Bitmap,
    onConfirm: (Bitmap) -> Unit,
    onDismiss: () -> Unit,
) {
    var scale by remember { mutableStateOf(1f) }
    var offset by remember { mutableStateOf(Offset.Zero) }
    var boxSize by remember { mutableStateOf(IntSize.Zero) }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .background(Color(0xE6101010))
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                "双指缩放、拖动图片，调整好角度后保存",
                fontSize = 12.5.sp, color = Color.White.copy(alpha = 0.7f),
                modifier = Modifier.padding(bottom = 14.dp),
            )

            Box(
                Modifier
                    .fillMaxWidth()
                    .height(320.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color.Black)
                    .onSizeChanged { boxSize = it }
                    .pointerInput(Unit) {
                        detectTransformGestures { _, pan, zoom, _ ->
                            val newScale = (scale * zoom).coerceIn(1f, 8f)
                            scale = newScale
                            offset += pan
                            clampCropOffset(offset, scale, boxSize, source) { offset = it }
                        }
                    },
                contentAlignment = Alignment.Center,
            ) {
                Image(
                    bitmap = source.asImageBitmap(),
                    contentDescription = "裁剪原图",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .fillMaxSize()
                        .graphicsLayer(
                            scaleX = scale, scaleY = scale,
                            translationX = offset.x, translationY = offset.y,
                        ),
                )
            }

            Spacer(Modifier.height(18.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Text(
                    "取消", fontSize = 14.sp, color = Color.White,
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color.White.copy(alpha = 0.16f))
                        .clickable { onDismiss() }
                        .padding(horizontal = 26.dp, vertical = 12.dp),
                )
                Text(
                    "✂️ 就选这样", fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                    color = Color.White,
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(Palette.purple)
                        .clickable {
                            val cropped = cropBitmap(source, scale, offset, boxSize)
                            if (cropped != null) onConfirm(cropped) else onDismiss()
                        }
                        .padding(horizontal = 26.dp, vertical = 12.dp),
                )
            }
        }
    }
}

/** 限制拖动范围：保证图片始终铺满方框，不露黑边 */
private fun clampCropOffset(
    current: Offset,
    scale: Float,
    boxSize: IntSize,
    source: Bitmap,
    apply: (Offset) -> Unit,
) {
    if (boxSize == IntSize.Zero) return
    val k = maxOf(
        boxSize.width.toFloat() / source.width,
        boxSize.height.toFloat() / source.height,
    )
    val w = source.width * k * scale
    val h = source.height * k * scale
    val maxX = maxOf(0f, (w - boxSize.width) / 2f)
    val maxY = maxOf(0f, (h - boxSize.height) / 2f)
    apply(
        Offset(
            current.x.coerceIn(-maxX, maxX),
            current.y.coerceIn(-maxY, maxY),
        ),
    )
}

/** 按方框可视区域裁剪源图，再缩放为 512×512 */
private fun cropBitmap(source: Bitmap, scale: Float, offset: Offset, boxSize: IntSize): Bitmap? {
    if (boxSize == IntSize.Zero) return null
    return runCatching {
        val k = maxOf(
            boxSize.width.toFloat() / source.width,
            boxSize.height.toFloat() / source.height,
        )
        val total = k * scale
        val w = source.width * total
        val h = source.height * total
        val tlX = boxSize.width / 2f - w / 2f + offset.x
        val tlY = boxSize.height / 2f - h / 2f + offset.y
        val cropX = (-tlX / total).toInt().coerceIn(0, source.width - 1)
        val cropY = (-tlY / total).toInt().coerceIn(0, source.height - 1)
        val cropW = minOf((boxSize.width / total).toInt(), source.width - cropX)
        val cropH = minOf((boxSize.height / total).toInt(), source.height - cropY)
        if (cropW <= 0 || cropH <= 0) return null
        val square = Bitmap.createBitmap(source, cropX, cropY, cropW, cropH)
        Bitmap.createScaledBitmap(square, 512, 512, true)
    }.getOrNull()
}
