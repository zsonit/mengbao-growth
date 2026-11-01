package com.zsonit.mengbao.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

// MARK: - 调色板（与 iOS 版本逐一对应）

@Immutable
data class PaletteColors(
    val purple: Color,
    val purpleDeep: Color,
    val purpleSoft: Color,
    val purpleTint: Color,
    val background: Color,
    val card: Color,
    val ink: Color,
    val ink2: Color,
    val subtle: Color,
    val hairline: Color,
    val hairlineSoft: Color,
    val ok: Color,
    val okBg: Color,
    val warn: Color,
    val warnBg: Color,
    val bad: Color,
    val badBg: Color,
    val pinkBg: Color,
    val blueBg: Color,
    /** 主粉色（标尺、语音、快捷入口等强调色） */
    val pink: Color,
    val pinkDeep: Color,
    val isDark: Boolean,
)

val LightPalette = PaletteColors(
    purple = Color(0xFF7C5CFF),
    purpleDeep = Color(0xFF6A48F5),
    purpleSoft = Color(0xFFEFEAFF),
    purpleTint = Color(0xFFF7F4FF),
    background = Color(0xFFF5F3FB),
    card = Color(0xFFFFFFFF),
    ink = Color(0xFF1C1A2B),
    ink2 = Color(0xFF4A4560),
    subtle = Color(0xFF8B86A4),
    hairline = Color(0xFFECE8F5),
    hairlineSoft = Color(0xFFF4F1FB),
    ok = Color(0xFF1F9D6B),
    okBg = Color(0xFFE7F7EF),
    warn = Color(0xFFD97706),
    warnBg = Color(0xFFFFF7ED),
    bad = Color(0xFFE0513A),
    badBg = Color(0xFFFDEEEB),
    pinkBg = Color(0xFFFFF0F5),
    blueBg = Color(0xFFEAF4FF),
    pink = Color(0xFFFF8FA8),
    pinkDeep = Color(0xFFFF6F91),
    isDark = false,
)

val DarkPalette = PaletteColors(
    purple = Color(0xFF9B82FF),
    purpleDeep = Color(0xFF8B70FF),
    purpleSoft = Color(0xFF2B2440),
    purpleTint = Color(0xFF221D31),
    background = Color(0xFF14121C),
    card = Color(0xFF1E1B29),
    ink = Color(0xFFF2F0FA),
    ink2 = Color(0xFFCDC7E0),
    subtle = Color(0xFF918BA8),
    hairline = Color(0xFF2E2940),
    hairlineSoft = Color(0xFF262231),
    ok = Color(0xFF3EC48D),
    okBg = Color(0xFF16342A),
    warn = Color(0xFFE9A23B),
    warnBg = Color(0xFF33260F),
    bad = Color(0xFFF2715C),
    badBg = Color(0xFF38201C),
    pinkBg = Color(0xFF35222C),
    blueBg = Color(0xFF17263C),
    pink = Color(0xFFFF9DB3),
    pinkDeep = Color(0xFFFF7E9C),
    isDark = true,
)

val LocalPalette = staticCompositionLocalOf { LightPalette }

object Palette {
    val purple: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.purple
    val purpleDeep: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.purpleDeep
    val purpleSoft: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.purpleSoft
    val purpleTint: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.purpleTint
    val background: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.background
    val card: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.card
    val ink: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.ink
    val ink2: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.ink2
    val subtle: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.subtle
    val hairline: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.hairline
    val hairlineSoft: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.hairlineSoft
    val ok: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.ok
    val okBg: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.okBg
    val warn: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.warn
    val warnBg: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.warnBg
    val bad: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.bad
    val badBg: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.badBg
    val pinkBg: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.pinkBg
    val blueBg: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.blueBg
    val pink: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.pink
    val pinkDeep: Color @Composable @ReadOnlyComposable get() = LocalPalette.current.pinkDeep

    val heroGradient: Brush
        @Composable get() = Brush.linearGradient(
            listOf(Color(0xFF7C5CFF), Color(0xFF9F82FF), Color(0xFFC3A8FF)),
            start = Offset.Zero,
            end = Offset(900f, 700f),
        )

    /** 粉色渐变：语音悬浮球、粉色强调块 */
    val pinkGradient: Brush
        @Composable get() = Brush.linearGradient(
            listOf(Color(0xFFFF8FA8), Color(0xFFFFB3C6), Color(0xFFFFD3E0)),
            start = Offset.Zero,
            end = Offset(600f, 600f),
        )

    val warmGradient: Brush
        @Composable get() = Brush.linearGradient(
            listOf(Color(0xFFFF7A59), Color(0xFFFF9F45), Color(0xFFFFC06B)),
            start = Offset.Zero,
            end = Offset(900f, 700f),
        )
}

// MARK: - 应用主题

@Composable
fun MengBaoTheme(darkOverride: Boolean? = null, content: @Composable () -> Unit) {
    val dark = darkOverride ?: isSystemInDarkTheme()
    val palette = if (dark) DarkPalette else LightPalette
    val scheme = (if (dark) darkColorScheme() else lightColorScheme()).copy(
        primary = palette.purple,
        background = palette.background,
        surface = palette.card,
        onPrimary = Color.White,
        onBackground = palette.ink,
        onSurface = palette.ink,
    )
    CompositionLocalProvider(LocalPalette provides palette) {
        MaterialTheme(colorScheme = scheme, typography = Typography(), content = content)
    }
}
