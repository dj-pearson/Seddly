package com.pearsonmedia.seddly.ui.theme

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Premium design tokens (US-135) for Android — gradients, shadows, motion, and
 * expressive typography. Mirrors iOS PremiumDesignSystem.swift so both platforms
 * feel identical in the hand.
 */
object SeddlyPremium {

    // ── Gradients ──
    object Gradients {
        val hero: Brush = Brush.linearGradient(
            colors = listOf(
                Color(0xFF1A73E8),
                Color(0xFF5A3BD8),
                Color(0xFF7A2FC9)
            )
        )

        val proShimmer: Brush = Brush.horizontalGradient(
            colors = listOf(
                Color(0xFFF2C640),
                Color(0xFFFFE28C),
                Color(0xFFD89E28)
            )
        )

        fun status(color: Color): Brush = Brush.linearGradient(
            colors = listOf(
                color.copy(alpha = 0.20f),
                color.copy(alpha = 0.04f)
            )
        )

        @Composable
        fun cardSurface(): Brush = Brush.verticalGradient(
            colors = listOf(
                MaterialTheme.colorScheme.surface,
                MaterialTheme.colorScheme.surface.copy(alpha = 0.92f)
            )
        )
    }

    // ── Motion (spring presets matching iOS SeddlyMotion) ──
    object Motion {
        val snappy: SpringSpec<Float> = spring(
            stiffness = Spring.StiffnessHigh,
            dampingRatio = 0.72f
        )
        val smooth: SpringSpec<Float> = spring(
            stiffness = Spring.StiffnessMediumLow,
            dampingRatio = 0.82f
        )
        val celebratory: SpringSpec<Float> = spring(
            stiffness = Spring.StiffnessLow,
            dampingRatio = 0.55f
        )
        val easeSoft = tween<Float>(durationMillis = 280)
    }

    // ── Expressive Typography ──
    object DisplayFont {
        val hero = TextStyle(
            fontSize = 48.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Default
        )
        val display = TextStyle(
            fontSize = 34.sp,
            fontWeight = FontWeight.Bold
        )
        val accent = TextStyle(
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold
        )
    }

    // ── Premium shapes ──
    object Shapes {
        val hero = RoundedCornerShape(20.dp)
        val sheet = RoundedCornerShape(28.dp)
    }
}

/** Applies a premium card treatment: continuous corners, soft shadow, hairline border. */
fun Modifier.premiumCard(): Modifier = this
    .shadow(
        elevation = 4.dp,
        shape = RoundedCornerShape(16.dp),
        ambientColor = Color.Black.copy(alpha = 0.05f),
        spotColor = Color.Black.copy(alpha = 0.12f)
    )
    .clip(RoundedCornerShape(16.dp))
    .padding(16.dp)
