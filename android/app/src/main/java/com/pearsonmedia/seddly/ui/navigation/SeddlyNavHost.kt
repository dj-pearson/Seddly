package com.pearsonmedia.seddly.ui.navigation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ListAlt
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pearsonmedia.seddly.service.HapticsService
import com.pearsonmedia.seddly.ui.theme.SeddlyPremium
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavType
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.Spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.pearsonmedia.seddly.ui.screens.detail.CommitmentDetailScreen
import com.pearsonmedia.seddly.ui.screens.ledger.LedgerScreen
import com.pearsonmedia.seddly.ui.screens.manual.ManualEntryScreen
import com.pearsonmedia.seddly.ui.screens.settings.SettingsScreen

/**
 * Floating bottom navigation with rounded 24dp surface, accent-tinted shadow,
 * and gradient selection pill (US-143). Replaces the default NavigationBar.
 */
@Composable
private fun FloatingBottomNav(
    items: List<Screen>,
    currentRoute: String?,
    onNavigate: (Screen) -> Unit
) {
    val view = LocalView.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .shadow(
                elevation = 12.dp,
                shape = RoundedCornerShape(24.dp),
                ambientColor = Color.Black.copy(alpha = 0.08f),
                spotColor = Color(0xFF1A73E8).copy(alpha = 0.25f)
            )
            .clip(RoundedCornerShape(24.dp))
            .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.96f))
            .padding(6.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        items.forEach { screen ->
            val selected = currentRoute == screen.route
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .then(
                        if (selected) Modifier.background(SeddlyPremium.Gradients.hero)
                        else Modifier
                    )
                    .clickable {
                        HapticsService.select(view)
                        onNavigate(screen)
                    }
                    .padding(horizontal = 18.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = screen.icon!!,
                    contentDescription = screen.title,
                    tint = if (selected) Color.White else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(22.dp)
                )
                if (selected) {
                    Text(
                        text = screen.title,
                        color = Color.White,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(start = 8.dp)
                    )
                }
            }
        }
    }
}

sealed class Screen(val route: String, val title: String, val icon: ImageVector?) {
    data object Ledger : Screen("ledger", "Ledger", Icons.Default.ListAlt)
    data object Settings : Screen("settings", "Settings", Icons.Default.Settings)
    data object CommitmentDetail : Screen("commitment/{commitmentId}", "Detail", null) {
        fun createRoute(id: String) = "commitment/$id"
    }
    data object ManualEntry : Screen("manual_entry", "Add Commitment", null)
}

private val bottomNavItems = listOf(Screen.Ledger, Screen.Settings)

@Composable
fun SeddlyNavHost(
    deepLinkCommitmentId: String? = null
) {
    val navController = rememberNavController()

    // Handle deep link navigation
    LaunchedEffect(deepLinkCommitmentId) {
        deepLinkCommitmentId?.let { id ->
            navController.navigate(Screen.CommitmentDetail.createRoute(id))
        }
    }

    Scaffold(
        bottomBar = {
            val navBackStackEntry by navController.currentBackStackEntryAsState()
            val currentDestination = navBackStackEntry?.destination

            // Only show bottom bar on top-level screens
            val showBottomBar = bottomNavItems.any { screen ->
                currentDestination?.hierarchy?.any { it.route == screen.route } == true
            }

            if (showBottomBar) {
                FloatingBottomNav(
                    items = bottomNavItems,
                    currentRoute = currentDestination?.route,
                    onNavigate = { screen ->
                        navController.navigate(screen.route) {
                            popUpTo(Screen.Ledger.route) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    }
                )
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Screen.Ledger.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            // Expressive motion spring (US-144) — matches iOS SeddlyMotion.smooth.
            val smoothSpring = spring<Float>(
                stiffness = Spring.StiffnessMediumLow,
                dampingRatio = 0.82f
            )
            val smoothOffsetSpring = spring<androidx.compose.ui.unit.IntOffset>(
                stiffness = Spring.StiffnessMediumLow,
                dampingRatio = 0.82f
            )

            composable(Screen.Ledger.route) {
                LedgerScreen(
                    onCommitmentClick = { id ->
                        navController.navigate(Screen.CommitmentDetail.createRoute(id))
                    },
                    onAddManualClick = {
                        navController.navigate(Screen.ManualEntry.route)
                    }
                )
            }

            composable(
                Screen.Settings.route,
                enterTransition = {
                    slideInHorizontally(smoothOffsetSpring) { it / 3 } + fadeIn(smoothSpring)
                },
                exitTransition = {
                    slideOutHorizontally(smoothOffsetSpring) { -it / 3 } + fadeOut(smoothSpring)
                }
            ) {
                SettingsScreen()
            }

            composable(
                route = Screen.CommitmentDetail.route,
                arguments = listOf(navArgument("commitmentId") { type = NavType.StringType }),
                enterTransition = {
                    slideInVertically(smoothOffsetSpring) { it / 4 } + fadeIn(smoothSpring)
                },
                exitTransition = {
                    fadeOut(smoothSpring)
                },
                popExitTransition = {
                    slideOutVertically(smoothOffsetSpring) { it / 4 } + fadeOut(smoothSpring)
                }
            ) { backStackEntry ->
                val commitmentId = backStackEntry.arguments?.getString("commitmentId") ?: return@composable
                CommitmentDetailScreen(
                    commitmentId = commitmentId,
                    onBack = { navController.popBackStack() }
                )
            }

            composable(
                Screen.ManualEntry.route,
                enterTransition = {
                    slideInVertically(smoothOffsetSpring) { it } + fadeIn(smoothSpring)
                },
                popExitTransition = {
                    slideOutVertically(smoothOffsetSpring) { it } + fadeOut(smoothSpring)
                }
            ) {
                ManualEntryScreen(
                    onBack = { navController.popBackStack() },
                    onSaved = { navController.popBackStack() }
                )
            }
        }
    }
}
