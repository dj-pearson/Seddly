package com.pearsonmedia.seddly.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pearsonmedia.seddly.data.local.entity.CommitmentEntity
import com.pearsonmedia.seddly.data.local.entity.UrgencyLevel
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.runtime.remember
import androidx.compose.ui.draw.shadow
import com.pearsonmedia.seddly.ui.theme.SeddlyColors
import com.pearsonmedia.seddly.ui.theme.SeddlyPremium
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun CommitmentCard(
    commitment: CommitmentEntity,
    isSelected: Boolean,
    isSelectionMode: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    onFulfill: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    val statusColor = SeddlyColors.statusColor(commitment.status)
    val selectedColor by animateColorAsState(
        if (isSelected) MaterialTheme.colorScheme.primaryContainer
        else MaterialTheme.colorScheme.surface,
        label = "selection"
    )

    val dismissState = rememberSwipeToDismissBoxState()
    LaunchedEffect(dismissState.currentValue) {
        when (dismissState.currentValue) {
            SwipeToDismissBoxValue.StartToEnd -> {
                onFulfill()
                dismissState.snapTo(SwipeToDismissBoxValue.Settled)
            }
            SwipeToDismissBoxValue.EndToStart -> {
                onDismiss()
                dismissState.snapTo(SwipeToDismissBoxValue.Settled)
            }
            SwipeToDismissBoxValue.Settled -> { /* no-op */ }
        }
    }

    val accessibilityDesc = buildString {
        append("${commitment.entityName}: ${commitment.summary}")
        append(". Status: ${commitment.status}")
        commitment.deadline?.let {
            append(". Deadline: ${formatDate(it)}")
        }
        append(". Swipe right to fulfill, swipe left to dismiss")
    }

    SwipeToDismissBox(
        state = dismissState,
        backgroundContent = {
            val direction = dismissState.dismissDirection
            val color = when (direction) {
                SwipeToDismissBoxValue.StartToEnd -> SeddlyColors.Fulfilled
                SwipeToDismissBoxValue.EndToStart -> SeddlyColors.Dismissed
                else -> Color.Transparent
            }
            val icon = when (direction) {
                SwipeToDismissBoxValue.StartToEnd -> Icons.Default.CheckCircle
                SwipeToDismissBoxValue.EndToStart -> Icons.Default.Close
                else -> null
            }
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clip(RoundedCornerShape(12.dp))
                    .background(color)
                    .padding(horizontal = 20.dp),
                contentAlignment = if (direction == SwipeToDismissBoxValue.StartToEnd)
                    Alignment.CenterStart else Alignment.CenterEnd
            ) {
                icon?.let {
                    Icon(it, contentDescription = null, tint = Color.White)
                }
            }
        },
        enableDismissFromStartToEnd = !isSelectionMode,
        enableDismissFromEndToStart = !isSelectionMode,
        modifier = modifier.semantics { contentDescription = accessibilityDesc }
    ) {
        // Premium card: spring-animated press elevation + status gradient rail (US-137)
        val interactionSource = remember { MutableInteractionSource() }
        val isPressed by interactionSource.collectIsPressedAsState()
        val elevation by animateDpAsState(
            targetValue = if (isPressed) 8.dp else 3.dp,
            label = "cardElevation"
        )

        Card(
            colors = CardDefaults.cardColors(containerColor = selectedColor),
            shape = RoundedCornerShape(16.dp),
            elevation = CardDefaults.cardElevation(defaultElevation = elevation),
            modifier = Modifier
                .fillMaxWidth()
                .shadow(
                    elevation = elevation,
                    shape = RoundedCornerShape(16.dp),
                    ambientColor = Color.Black.copy(alpha = 0.06f),
                    spotColor = statusColor.copy(alpha = 0.15f)
                )
                .combinedClickable(
                    interactionSource = interactionSource,
                    indication = androidx.compose.foundation.LocalIndication.current,
                    onClick = onClick,
                    onLongClick = onLongClick
                )
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(SeddlyPremium.Gradients.status(statusColor))
                    .padding(14.dp),
                verticalAlignment = Alignment.Top
            ) {
                // Premium vertical status rail (US-137)
                Box(
                    modifier = Modifier
                        .width(4.dp)
                        .height(56.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(
                            androidx.compose.ui.graphics.Brush.verticalGradient(
                                colors = listOf(
                                    statusColor,
                                    statusColor.copy(alpha = 0.55f)
                                )
                            )
                        )
                )

                Spacer(modifier = Modifier.width(12.dp))

                Column(modifier = Modifier.weight(1f)) {
                    // Entity name
                    Text(
                        text = commitment.entityName,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )

                    Spacer(modifier = Modifier.height(2.dp))

                    // Summary
                    Text(
                        text = commitment.summary,
                        style = MaterialTheme.typography.bodyMedium,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(6.dp))

                    // Bottom row: deadline + confidence
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Deadline
                        commitment.deadline?.let { dl ->
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    Icons.Default.Schedule,
                                    contentDescription = null,
                                    modifier = Modifier.size(14.dp),
                                    tint = when (commitment.urgencyLevel) {
                                        UrgencyLevel.OVERDUE -> SeddlyColors.UrgencyOverdue
                                        UrgencyLevel.APPROACHING -> SeddlyColors.UrgencyApproaching
                                        UrgencyLevel.SAFE -> SeddlyColors.UrgencySafe
                                        UrgencyLevel.NONE -> MaterialTheme.colorScheme.onSurfaceVariant
                                    }
                                )
                                Spacer(Modifier.width(4.dp))
                                Text(
                                    text = formatDate(dl),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = when (commitment.urgencyLevel) {
                                        UrgencyLevel.OVERDUE -> SeddlyColors.UrgencyOverdue
                                        UrgencyLevel.APPROACHING -> SeddlyColors.UrgencyApproaching
                                        else -> MaterialTheme.colorScheme.onSurfaceVariant
                                    }
                                )
                            }
                        }

                        // Confidence badge
                        ConfidenceBadge(score = commitment.confidenceScore)

                        // Dollar amount
                        commitment.dollarAmount?.let { amount ->
                            Text(
                                text = "$${String.format("%.2f", amount)}",
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Medium,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ConfidenceBadge(score: Int, modifier: Modifier = Modifier) {
    val color = SeddlyColors.confidenceColor(score)
    Text(
        text = "${score}%",
        style = MaterialTheme.typography.labelSmall,
        color = color,
        fontWeight = FontWeight.Bold,
        modifier = modifier
            .clip(RoundedCornerShape(4.dp))
            .background(color.copy(alpha = 0.12f))
            .padding(horizontal = 6.dp, vertical = 2.dp)
    )
}

private fun formatDate(timestamp: Long): String {
    val sdf = SimpleDateFormat("MMM d, yyyy", Locale.getDefault())
    return sdf.format(Date(timestamp))
}
