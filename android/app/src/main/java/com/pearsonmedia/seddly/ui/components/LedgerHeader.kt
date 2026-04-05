package com.pearsonmedia.seddly.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import com.pearsonmedia.seddly.ui.theme.SeddlyPremium

/**
 * Hero accountability header for the ledger (US-136). Mirrors iOS
 * LedgerHeaderView — gradient surface, momentum ring, streak + pending chips,
 * and an expandable weekly sparkline.
 */
@Composable
fun LedgerHeader(
    pendingCount: Int,
    fulfilledThisWeek: Int,
    totalThisWeek: Int,
    streakDays: Int,
    weekly: List<Int>,
    modifier: Modifier = Modifier
) {
    var expanded by remember { mutableStateOf(false) }
    val targetMomentum = if (totalThisWeek == 0) 0f else fulfilledThisWeek.toFloat() / totalThisWeek
    val animatedMomentum by animateFloatAsState(
        targetValue = targetMomentum,
        animationSpec = SeddlyPremium.Motion.celebratory,
        label = "momentum"
    )
    val percent = (targetMomentum * 100).toInt()

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .shadow(
                elevation = 8.dp,
                shape = RoundedCornerShape(20.dp),
                ambientColor = Color.Black.copy(alpha = 0.08f),
                spotColor = Color(0xFF1A73E8).copy(alpha = 0.25f)
            )
            .clip(RoundedCornerShape(20.dp))
            .background(SeddlyPremium.Gradients.hero)
            .pointerInput(Unit) {
                detectTapGestures(onTap = { expanded = !expanded })
            }
            .padding(16.dp)
            .semantics {
                contentDescription =
                    "$percent percent momentum. $pendingCount pending. $streakDays day streak."
            }
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            MomentumRing(progress = animatedMomentum)

            Spacer(modifier = Modifier.width(16.dp))

            Column {
                Text(
                    text = "WEEKLY MOMENTUM",
                    color = Color.White.copy(alpha = 0.85f),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 0.8.sp
                )
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        text = "$percent",
                        color = Color.White,
                        fontSize = 48.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "%",
                        color = Color.White.copy(alpha = 0.85f),
                        fontSize = 20.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(start = 4.dp, bottom = 10.dp)
                    )
                }
                Text(
                    text = "$fulfilledThisWeek of $totalThisWeek fulfilled this week",
                    color = Color.White.copy(alpha = 0.8f),
                    fontSize = 12.sp
                )
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            StatChip(
                icon = Icons.Default.LocalFireDepartment,
                value = streakDays.toString(),
                label = "day streak"
            )
            StatChip(
                icon = Icons.Default.Schedule,
                value = pendingCount.toString(),
                label = "pending"
            )
            Spacer(modifier = Modifier.weight(1f))
            Icon(
                imageVector = if (expanded) Icons.Default.KeyboardArrowUp
                else Icons.Default.KeyboardArrowDown,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.7f)
            )
        }

        AnimatedVisibility(visible = expanded) {
            Box(modifier = Modifier.padding(top = 12.dp)) {
                WeeklySparkline(values = weekly, modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp))
            }
        }
    }
}

@Composable
private fun MomentumRing(progress: Float, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier.size(72.dp),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.size(72.dp)) {
            val stroke = 8.dp.toPx()
            drawArc(
                color = Color.White.copy(alpha = 0.22f),
                startAngle = 0f,
                sweepAngle = 360f,
                useCenter = false,
                style = Stroke(width = stroke, cap = StrokeCap.Round),
                topLeft = Offset(stroke / 2, stroke / 2),
                size = androidx.compose.ui.geometry.Size(size.width - stroke, size.height - stroke)
            )
            drawArc(
                brush = Brush.linearGradient(
                    colors = listOf(Color.White, Color.White.copy(alpha = 0.7f))
                ),
                startAngle = -90f,
                sweepAngle = (progress.coerceIn(0f, 1f)) * 360f,
                useCenter = false,
                style = Stroke(width = stroke, cap = StrokeCap.Round),
                topLeft = Offset(stroke / 2, stroke / 2),
                size = androidx.compose.ui.geometry.Size(size.width - stroke, size.height - stroke)
            )
        }
        Icon(
            imageVector = Icons.Default.Bolt,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(24.dp)
        )
    }
}

@Composable
private fun StatChip(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    value: String,
    label: String
) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(Color.White.copy(alpha = 0.18f))
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(14.dp)
        )
        Text(
            text = value,
            color = Color.White,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = label,
            color = Color.White.copy(alpha = 0.85f),
            fontSize = 12.sp
        )
    }
}

@Composable
private fun WeeklySparkline(values: List<Int>, modifier: Modifier = Modifier) {
    val maxValue = (values.maxOrNull() ?: 0).coerceAtLeast(1)
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        values.forEach { v ->
            val ratio = v.toFloat() / maxValue
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height((56 * ratio).coerceAtLeast(4f).dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(Color.White.copy(alpha = 0.85f))
            )
        }
    }
}
