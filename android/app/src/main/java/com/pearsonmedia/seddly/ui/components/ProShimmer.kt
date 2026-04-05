package com.pearsonmedia.seddly.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pearsonmedia.seddly.ui.theme.SeddlyPremium

/**
 * Looping gold shimmer overlay that signals premium / locked features (US-141).
 * Mirrors iOS ProShimmer modifier.
 */
fun Modifier.proShimmer(durationMillis: Int = 2400): Modifier = this.then(
    Modifier.drawWithContent {
        drawContent()
        // The actual animated shimmer is composed via ProShimmerBox wrapper below;
        // this stub preserves the call-site shape so callers can chain it.
    }
)

@Composable
fun ProShimmerBox(
    modifier: Modifier = Modifier,
    durationMillis: Int = 2400,
    content: @Composable () -> Unit
) {
    val phase = remember { Animatable(-1f) }
    LaunchedEffect(Unit) {
        phase.animateTo(
            targetValue = 1f,
            animationSpec = infiniteRepeatable(
                animation = tween(durationMillis, easing = LinearEasing),
                repeatMode = RepeatMode.Restart
            )
        )
    }

    val shimmerBrush = Brush.linearGradient(
        colors = listOf(
            Color.White.copy(alpha = 0f),
            Color.White.copy(alpha = 0.55f),
            Color.White.copy(alpha = 0f)
        ),
        start = androidx.compose.ui.geometry.Offset(phase.value * 1000f, 0f),
        end = androidx.compose.ui.geometry.Offset(phase.value * 1000f + 400f, 0f)
    )

    androidx.compose.foundation.layout.Box(modifier = modifier) {
        content()
        androidx.compose.foundation.layout.Box(
            modifier = Modifier
                .matchParentSize()
                .background(shimmerBrush)
        )
    }
}

/** Small gold PRO badge mirroring iOS ProBadge. */
@Composable
fun ProBadge(
    modifier: Modifier = Modifier,
    compact: Boolean = false
) {
    Row(
        modifier = modifier
            .clip(androidx.compose.foundation.shape.RoundedCornerShape(50))
            .background(SeddlyPremium.Gradients.proShimmer)
            .padding(horizontal = if (compact) 6.dp else 8.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Icon(
            imageVector = Icons.Default.Star,
            contentDescription = "Pro feature",
            tint = Color.White,
            modifier = Modifier.padding(1.dp)
        )
        if (!compact) {
            Text(
                text = "PRO",
                color = Color.White,
                fontSize = 10.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 0.8.sp
            )
        }
    }
}
