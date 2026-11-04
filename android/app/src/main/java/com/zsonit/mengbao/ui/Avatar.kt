package com.zsonit.mengbao.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.exifinterface.media.ExifInterface
import com.zsonit.mengbao.model.Child
import java.io.File
import java.io.FileOutputStream

/** 头像照片文件位置：filesDir/avatars/<childId>.jpg */
fun avatarFile(context: Context, childId: String): File =
    File(File(context.filesDir, "avatars"), "$childId.jpg")

/**
 * 把相册选中的照片按正方形居中裁剪、缩小到 sizePx 后存为 JPEG。
 * 返回保存后的文件，失败返回 null。
 */
fun saveAvatarPhoto(context: Context, childId: String, uri: Uri, sizePx: Int = 512): File? {
    return runCatching {
        val src = context.contentResolver.openInputStream(uri) ?: return null
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        src.use { BitmapFactory.decodeStream(it, null, opts) }
        val sample = maxOf(1, maxOf(opts.outWidth, opts.outHeight) / (sizePx * 2))
        val src2 = context.contentResolver.openInputStream(uri) ?: return null
        val opts2 = BitmapFactory.Options().apply { inSampleSize = sample }
        val bmp = src2.use { BitmapFactory.decodeStream(it, null, opts2) } ?: return null

        // 依据 EXIF 修正方向
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
        val rotated = if (rotation != 0) {
            Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height,
                Matrix().apply { postRotate(rotation.toFloat()) }, true)
        } else bmp

        // 居中裁正方形
        val side = minOf(rotated.width, rotated.height)
        val x = (rotated.width - side) / 2
        val y = (rotated.height - side) / 2
        val square = Bitmap.createBitmap(rotated, x, y, side, side)
        val scaled = Bitmap.createScaledBitmap(square, sizePx, sizePx, true)

        val out = avatarFile(context, childId)
        out.parentFile?.mkdirs()
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
                val f = avatarFile(context, child.id)
                if (f.exists()) BitmapFactory.decodeFile(f.absolutePath) else null
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
