package com.pearsonmedia.seddly.ui.screens.onboarding

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
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
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.clickable
import com.pearsonmedia.seddly.ui.theme.SeddlyPremium
import kotlinx.coroutines.launch

/**
 * Cinematic onboarding flow (US-142). Four pages with unique gradient
 * backdrops, hero icons, staggered bullet animations, and a floating CTA.
 * Mirrors iOS OnboardingView.CinematicPage treatment.
 */
@Composable
fun OnboardingScreen(onFinished: () -> Unit) {
    val pages = remember {
        listOf(
            OnboardingPage(
                gradient = SeddlyPremium.Gradients.hero,
                icon = Icons.Default.Shield,
                title = "Seddly",
                subtitle = "Hold everyone to their word.",
                bullets = emptyList()
            ),
            OnboardingPage(
                gradient = Brush.linearGradient(
                    listOf(Color(0xFF2E5BD8), Color(0xFF854BE0))
                ),
                icon = Icons.Default.CameraAlt,
                title = "How It Works",
                subtitle = "Three steps to accountability.",
                bullets = listOf(
                    Bullet(Icons.Default.CameraAlt, "Screenshot", "Take a screenshot of any promise or agreement."),
                    Bullet(Icons.Default.CheckCircle, "Extract", "AI detects who promised what — automatically."),
                    Bullet(Icons.Default.Notifications, "Remind", "Get nudged when deadlines approach or pass.")
                )
            ),
            OnboardingPage(
                gradient = Brush.linearGradient(
                    listOf(Color(0xFF178C6B), Color(0xFF0A5985))
                ),
                icon = Icons.Default.Lock,
                title = "Privacy, First",
                subtitle = "Your screenshots never leave your device.",
                bullets = listOf(
                    Bullet(Icons.Default.Check, "On-device", "All text extraction happens on your phone."),
                    Bullet(Icons.Default.Check, "No uploads", "Screenshots are never sent to our servers."),
                    Bullet(Icons.Default.Check, "No tracking", "We don't share data with anyone.")
                )
            ),
            OnboardingPage(
                gradient = Brush.linearGradient(
                    listOf(Color(0xFFE07A2A), Color(0xFFB83B6E))
                ),
                icon = Icons.Default.CheckCircle,
                title = "Ready to Start",
                subtitle = "Your first commitment is one screenshot away.",
                bullets = emptyList()
            )
        )
    }

    val pagerState = rememberPagerState(pageCount = { pages.size })
    val scope = rememberCoroutineScope()

    Box(modifier = Modifier.fillMaxSize()) {
        HorizontalPager(state = pagerState) { index ->
            CinematicPageView(page = pages[index])
        }

        // Page indicator
        Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 96.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(pages.size) { idx ->
                val selected = pagerState.currentPage == idx
                val size by animateFloatAsState(
                    if (selected) 22f else 8f,
                    animationSpec = SeddlyPremium.Motion.snappy,
                    label = "dot"
                )
                Box(
                    modifier = Modifier
                        .width(size.dp)
                        .height(8.dp)
                        .clip(RoundedCornerShape(50))
                        .background(Color.White.copy(alpha = if (selected) 1f else 0.4f))
                )
            }
        }

        // CTA
        Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(horizontal = 32.dp, vertical = 24.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(50))
                .background(Color.White)
                .clickable {
                    if (pagerState.currentPage < pages.lastIndex) {
                        scope.launch {
                            pagerState.animateScrollToPage(pagerState.currentPage + 1)
                        }
                    } else {
                        onFinished()
                    }
                }
                .padding(vertical = 16.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = if (pagerState.currentPage < pages.lastIndex) "Continue" else "Get Started",
                color = Color(0xFF1A73E8),
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold
            )
        }

        // Skip
        Text(
            text = "Skip",
            color = Color.White.copy(alpha = 0.8f),
            fontSize = 14.sp,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(24.dp)
                .clickable { onFinished() }
        )
    }
}

private data class OnboardingPage(
    val gradient: Brush,
    val icon: ImageVector,
    val title: String,
    val subtitle: String,
    val bullets: List<Bullet>
)

private data class Bullet(
    val icon: ImageVector,
    val title: String,
    val description: String
)

@Composable
private fun CinematicPageView(page: OnboardingPage) {
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { visible = true }

    val iconScale by animateFloatAsState(
        targetValue = if (visible) 1f else 0.6f,
        animationSpec = SeddlyPremium.Motion.celebratory,
        label = "iconScale"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(page.gradient),
        contentAlignment = Alignment.Center
    ) {
        // Ambient orb
        Box(
            modifier = Modifier
                .size(420.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.08f))
        )

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 32.dp)
        ) {
            Spacer(Modifier.height(80.dp))

            Icon(
                imageVector = page.icon,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier
                    .size(96.dp)
                    .scale(iconScale)
            )

            Spacer(Modifier.height(24.dp))

            Text(
                text = page.title,
                color = Color.White,
                fontSize = 34.sp,
                fontWeight = FontWeight.Bold
            )

            Spacer(Modifier.height(8.dp))

            Text(
                text = page.subtitle,
                color = Color.White.copy(alpha = 0.9f),
                fontSize = 17.sp
            )

            Spacer(Modifier.height(32.dp))

            page.bullets.forEachIndexed { idx, bullet ->
                AnimatedVisibility(
                    visible = visible,
                    enter = fadeIn(animationSpec = tween(400, delayMillis = 250 + idx * 80)) +
                        slideInVertically(
                            animationSpec = tween(400, delayMillis = 250 + idx * 80),
                            initialOffsetY = { it / 4 }
                        )
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 8.dp)
                    ) {
                        Icon(
                            imageVector = bullet.icon,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(28.dp)
                        )
                        Spacer(Modifier.width(12.dp))
                        Column {
                            Text(
                                bullet.title,
                                color = Color.White,
                                fontSize = 15.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                            Text(
                                bullet.description,
                                color = Color.White.copy(alpha = 0.85f),
                                fontSize = 12.sp
                            )
                        }
                    }
                }
            }
        }
    }
}
