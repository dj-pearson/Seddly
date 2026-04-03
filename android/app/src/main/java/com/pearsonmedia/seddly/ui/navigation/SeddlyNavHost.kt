package com.pearsonmedia.seddly.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ListAlt
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.pearsonmedia.seddly.ui.screens.detail.CommitmentDetailScreen
import com.pearsonmedia.seddly.ui.screens.ledger.LedgerScreen
import com.pearsonmedia.seddly.ui.screens.manual.ManualEntryScreen
import com.pearsonmedia.seddly.ui.screens.settings.SettingsScreen

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
                NavigationBar {
                    bottomNavItems.forEach { screen ->
                        NavigationBarItem(
                            icon = { Icon(screen.icon!!, contentDescription = screen.title) },
                            label = { Text(screen.title) },
                            selected = currentDestination?.hierarchy?.any { it.route == screen.route } == true,
                            onClick = {
                                navController.navigate(screen.route) {
                                    popUpTo(Screen.Ledger.route) { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            }
                        )
                    }
                }
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Screen.Ledger.route,
            modifier = Modifier.padding(innerPadding)
        ) {
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

            composable(Screen.Settings.route) {
                SettingsScreen()
            }

            composable(
                route = Screen.CommitmentDetail.route,
                arguments = listOf(navArgument("commitmentId") { type = NavType.StringType })
            ) { backStackEntry ->
                val commitmentId = backStackEntry.arguments?.getString("commitmentId") ?: return@composable
                CommitmentDetailScreen(
                    commitmentId = commitmentId,
                    onBack = { navController.popBackStack() }
                )
            }

            composable(Screen.ManualEntry.route) {
                ManualEntryScreen(
                    onBack = { navController.popBackStack() },
                    onSaved = { navController.popBackStack() }
                )
            }
        }
    }
}
