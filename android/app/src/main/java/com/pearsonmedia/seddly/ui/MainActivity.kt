package com.pearsonmedia.seddly.ui

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.pearsonmedia.seddly.ui.navigation.SeddlyNavHost
import com.pearsonmedia.seddly.ui.theme.SeddlyTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val deepLinkCommitmentId = extractCommitmentId(intent)

        setContent {
            SeddlyTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    SeddlyNavHost(deepLinkCommitmentId = deepLinkCommitmentId)
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Handle deep links when activity is already running
        val commitmentId = extractCommitmentId(intent)
        if (commitmentId != null) {
            // Navigation will be handled via saved state
            setIntent(intent)
        }
    }

    private fun extractCommitmentId(intent: Intent?): String? {
        val uri = intent?.data ?: return null
        // Handle seddly://commitment/{id} and https://seddly.com/c/{id}
        return when {
            uri.scheme == "seddly" && uri.host == "commitment" -> uri.lastPathSegment
            uri.host == "seddly.com" && uri.path?.startsWith("/c/") == true -> uri.lastPathSegment
            else -> null
        }
    }
}
