package com.pearsonmedia.seddly.ui.theme

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Centralized design system matching iOS DesignSystem.swift.
 * Defines semantic tokens for consistent styling across all views.
 */
object SeddlyDesignSystem {

    // ── Spacing (matches iOS SeddlySpacing) ──
    object Spacing {
        val xxs: Dp = 2.dp
        val xs: Dp = 4.dp
        val sm: Dp = 6.dp
        val md: Dp = 8.dp
        val lg: Dp = 12.dp
        val xl: Dp = 16.dp
        val xxl: Dp = 24.dp
        val xxxl: Dp = 32.dp
    }

    // ── Corner Radii (matches iOS SeddlyRadius) ──
    object Radius {
        val small = RoundedCornerShape(8.dp)
        val medium = RoundedCornerShape(12.dp)
        val large = RoundedCornerShape(16.dp)
        val pill = RoundedCornerShape(50)
    }

    // ── Typography presets ──
    object Font {
        val cardTitle: TextStyle
            @Composable get() = MaterialTheme.typography.titleSmall.copy(
                fontWeight = FontWeight.SemiBold
            )

        val cardBody: TextStyle
            @Composable get() = MaterialTheme.typography.bodyMedium

        val supporting: TextStyle
            @Composable get() = MaterialTheme.typography.labelSmall.copy(
                color = Color.Gray
            )

        val badge: TextStyle
            @Composable get() = MaterialTheme.typography.labelSmall.copy(
                fontWeight = FontWeight.Bold,
                fontSize = 11.sp
            )

        val sectionHeader: TextStyle
            @Composable get() = MaterialTheme.typography.titleSmall.copy(
                fontWeight = FontWeight.SemiBold
            )

        val monospaced: TextStyle
            @Composable get() = MaterialTheme.typography.bodySmall.copy(
                fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace
            )
    }

    // ── Elevation ──
    object Elevation {
        val card: Dp = 1.dp
        val dialog: Dp = 6.dp
        val fab: Dp = 6.dp
    }

    // ── Content Padding ──
    object ContentPadding {
        val screen = PaddingValues(horizontal = 16.dp, vertical = 8.dp)
        val card = PaddingValues(12.dp)
        val section = PaddingValues(horizontal = 16.dp, vertical = 8.dp)
    }

    // ── Adaptive Colors (respond to dark mode) ──
    object AdaptiveColors {
        val cardBackground: Color
            @Composable get() = MaterialTheme.colorScheme.surface

        val primaryBackground: Color
            @Composable get() = MaterialTheme.colorScheme.background

        val groupedBackground: Color
            @Composable get() = MaterialTheme.colorScheme.surfaceVariant

        val separator: Color
            @Composable get() = MaterialTheme.colorScheme.outlineVariant

        @Composable
        fun statusBackground(status: String): Color =
            SeddlyColors.statusColor(status).copy(alpha = 0.12f)
    }
}

/**
 * Modifier extensions matching iOS button styles.
 */
object SeddlyModifiers {
    fun Modifier.seddlyCard(): Modifier = this
        .clip(SeddlyDesignSystem.Radius.medium)
        .padding(SeddlyDesignSystem.Spacing.md)

    fun Modifier.seddlyPill(): Modifier = this
        .clip(SeddlyDesignSystem.Radius.pill)
        .padding(horizontal = SeddlyDesignSystem.Spacing.md, vertical = SeddlyDesignSystem.Spacing.xs)
}
