package com.pearsonmedia.seddly.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

// Seddly Brand Colors
object SeddlyColors {
    val Primary = Color(0xFF1A73E8)
    val PrimaryDark = Color(0xFF4DA3FF)
    val Secondary = Color(0xFF34A853)
    val SecondaryDark = Color(0xFF81C995)
    val Error = Color(0xFFEA4335)
    val ErrorDark = Color(0xFFFF6E6E)

    // Status colors
    val Pending = Color(0xFFFFA726)
    val Fulfilled = Color(0xFF66BB6A)
    val Overdue = Color(0xFFEF5350)
    val Disputed = Color(0xFFAB47BC)
    val Dismissed = Color(0xFF78909C)

    // Confidence
    val ConfidenceHigh = Color(0xFF43A047)
    val ConfidenceMedium = Color(0xFFFFA000)
    val ConfidenceLow = Color(0xFFE53935)

    // Urgency
    val UrgencyOverdue = Color(0xFFD32F2F)
    val UrgencyApproaching = Color(0xFFF57C00)
    val UrgencySafe = Color(0xFF388E3C)

    fun statusColor(status: String): Color = when (status) {
        "pending" -> Pending
        "fulfilled" -> Fulfilled
        "overdue" -> Overdue
        "disputed" -> Disputed
        "dismissed" -> Dismissed
        else -> Pending
    }

    fun confidenceColor(score: Int): Color = when {
        score >= 70 -> ConfidenceHigh
        score >= 40 -> ConfidenceMedium
        else -> ConfidenceLow
    }

    fun urgencyColor(level: String): Color = when (level) {
        "OVERDUE" -> UrgencyOverdue
        "APPROACHING" -> UrgencyApproaching
        "SAFE" -> UrgencySafe
        else -> Color.Transparent
    }
}

// Spacing constants matching iOS design system
object SeddlySpacing {
    val XXS = 2
    val XS = 4
    val SM = 6
    val MD = 8
    val LG = 12
    val XL = 16
    val XXL = 24
}

private val LightColorScheme = lightColorScheme(
    primary = SeddlyColors.Primary,
    secondary = SeddlyColors.Secondary,
    error = SeddlyColors.Error,
    background = Color(0xFFFAFAFA),
    surface = Color.White,
    onPrimary = Color.White,
    onSecondary = Color.White,
    onBackground = Color(0xFF1C1B1F),
    onSurface = Color(0xFF1C1B1F),
    surfaceVariant = Color(0xFFF5F5F5)
)

private val DarkColorScheme = darkColorScheme(
    primary = SeddlyColors.PrimaryDark,
    secondary = SeddlyColors.SecondaryDark,
    error = SeddlyColors.ErrorDark,
    background = Color(0xFF121212),
    surface = Color(0xFF1E1E1E),
    onPrimary = Color(0xFF003A75),
    onSecondary = Color(0xFF003A20),
    onBackground = Color(0xFFE6E1E5),
    onSurface = Color(0xFFE6E1E5),
    surfaceVariant = Color(0xFF2C2C2C)
)

@Composable
fun SeddlyTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        content = content
    )
}
