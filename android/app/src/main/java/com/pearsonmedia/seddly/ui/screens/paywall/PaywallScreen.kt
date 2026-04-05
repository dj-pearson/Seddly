package com.pearsonmedia.seddly.ui.screens.paywall

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AllInclusive
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CloudSync
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pearsonmedia.seddly.ui.components.ProBadge
import com.pearsonmedia.seddly.ui.components.ProShimmerBox
import com.pearsonmedia.seddly.ui.theme.SeddlyPremium

/**
 * Premium paywall screen (US-140). Mirrors iOS SubscriptionView redesign:
 * hero gradient header, horizontally scrolling feature showcase with shimmer,
 * billing toggle with savings pill, tier cards, social proof row, CTA.
 */
@Composable
fun PaywallScreen(
    currentTier: String = "free",
    onPurchase: (tier: String, yearly: Boolean) -> Unit = { _, _ -> },
    onRestore: () -> Unit = {},
    onOpenTerms: () -> Unit = {},
    onOpenPrivacy: () -> Unit = {}
) {
    var yearly by remember { mutableStateOf(true) }
    var selectedPro by remember { mutableStateOf(true) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .background(MaterialTheme.colorScheme.background)
    ) {
        HeroHeader()
        Spacer(Modifier.height(8.dp))
        FeatureShowcase()
        Spacer(Modifier.height(24.dp))
        BillingToggle(yearly = yearly, onChange = { yearly = it })
        Spacer(Modifier.height(16.dp))
        TierCard(
            name = "Pro",
            price = if (yearly) "$39.99" else "$4.99",
            period = if (yearly) "/yr" else "/mo",
            tagline = "For serious accountability",
            highlights = listOf(
                "Auto-scan Screenshots",
                "Unlimited commitments",
                "AI extraction",
                "Smart reminders"
            ),
            isSelected = selectedPro,
            isCurrent = currentTier == "pro",
            onClick = { selectedPro = true }
        )
        Spacer(Modifier.height(12.dp))
        TierCard(
            name = "Pro+",
            price = if (yearly) "$79.99" else "$9.99",
            period = if (yearly) "/yr" else "/mo",
            tagline = "Everything in Pro, plus sync & disputes",
            highlights = listOf(
                "Cross-device sync",
                "AI dispute summaries",
                "Unlimited history",
                "Priority processing"
            ),
            isSelected = !selectedPro,
            isCurrent = currentTier == "pro_plus",
            crown = true,
            onClick = { selectedPro = false }
        )
        Spacer(Modifier.height(16.dp))
        SocialProof()
        Spacer(Modifier.height(16.dp))
        CtaButton(
            label = if (selectedPro) "Start Pro" else "Start Pro+",
            onClick = { onPurchase(if (selectedPro) "pro" else "pro_plus", yearly) }
        )
        Spacer(Modifier.height(16.dp))
        FooterLinks(
            onRestore = onRestore,
            onOpenTerms = onOpenTerms,
            onOpenPrivacy = onOpenPrivacy
        )
        Spacer(Modifier.height(32.dp))
    }
}

@Composable
private fun HeroHeader() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(260.dp)
            .clip(RoundedCornerShape(bottomStart = 28.dp, bottomEnd = 28.dp))
            .background(SeddlyPremium.Gradients.hero),
        contentAlignment = Alignment.BottomCenter
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(bottom = 32.dp, start = 24.dp, end = 24.dp)
        ) {
            ProBadge()
            Spacer(Modifier.height(12.dp))
            Text(
                text = "Unlock Your Full Ledger",
                color = Color.White,
                fontSize = 30.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.height(6.dp))
            Text(
                text = "AI extraction. Unlimited commitments. Cross-device sync.",
                color = Color.White.copy(alpha = 0.88f),
                fontSize = 14.sp
            )
        }
    }
}

private data class Feature(val icon: ImageVector, val title: String, val benefit: String)

@Composable
private fun FeatureShowcase() {
    val items = listOf(
        Feature(Icons.Default.AutoAwesome, "AI Extraction", "Never miss a promise — Seddly reads your screenshots."),
        Feature(Icons.Default.AllInclusive, "Unlimited Ledger", "Track as many commitments as life throws at you."),
        Feature(Icons.Default.CloudSync, "Cloud Sync", "Stay accountable across all your devices."),
        Feature(Icons.Default.Notifications, "Smart Reminders", "Get nudged at exactly the right moment."),
        Feature(Icons.Default.Description, "Dispute Summaries", "AI-ready timelines when you need to escalate.")
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items.forEach { f ->
            ProShimmerBox(
                modifier = Modifier
                    .width(220.dp)
                    .height(180.dp)
                    .shadow(4.dp, RoundedCornerShape(16.dp))
                    .clip(RoundedCornerShape(16.dp))
                    .background(MaterialTheme.colorScheme.surface)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(16.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(SeddlyPremium.Gradients.hero),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = f.icon,
                            contentDescription = null,
                            tint = Color.White
                        )
                    }
                    Spacer(Modifier.height(12.dp))
                    Text(f.title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(4.dp))
                    Text(
                        f.benefit,
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 3
                    )
                }
            }
        }
    }
}

@Composable
private fun BillingToggle(yearly: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(50))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(4.dp)
    ) {
        Row(
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(50))
                .then(if (!yearly) Modifier.background(SeddlyPremium.Gradients.hero) else Modifier)
                .clickable { onChange(false) }
                .padding(vertical = 10.dp),
            horizontalArrangement = Arrangement.Center
        ) {
            Text(
                "Monthly",
                color = if (!yearly) Color.White else MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp
            )
        }
        Row(
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(50))
                .then(if (yearly) Modifier.background(SeddlyPremium.Gradients.hero) else Modifier)
                .clickable { onChange(true) }
                .padding(vertical = 10.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "Yearly",
                color = if (yearly) Color.White else MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp
            )
            Spacer(Modifier.width(6.dp))
            Text(
                "Save 33%",
                color = Color(0xFF2E7D32),
                fontSize = 10.sp,
                fontWeight = FontWeight.ExtraBold,
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(Color(0xFF2E7D32).copy(alpha = 0.15f))
                    .padding(horizontal = 6.dp, vertical = 2.dp)
            )
        }
    }
}

@Composable
private fun TierCard(
    name: String,
    price: String,
    period: String,
    tagline: String,
    highlights: List<String>,
    isSelected: Boolean,
    isCurrent: Boolean,
    crown: Boolean = false,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surface)
            .then(
                if (isSelected) Modifier.border(
                    width = 2.dp,
                    color = MaterialTheme.colorScheme.primary,
                    shape = RoundedCornerShape(16.dp)
                ) else Modifier
            )
            .shadow(if (isSelected) 8.dp else 2.dp, RoundedCornerShape(16.dp))
            .clickable { onClick() }
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(name, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
            if (crown) {
                Spacer(Modifier.width(6.dp))
                Icon(
                    Icons.Default.Star,
                    contentDescription = null,
                    tint = Color(0xFFF2C640),
                    modifier = Modifier.size(16.dp)
                )
            }
            Spacer(Modifier.weight(1f))
            Text(price, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Text(
                period,
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Spacer(Modifier.height(4.dp))
        Text(
            tagline,
            fontSize = 12.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.height(8.dp))
        highlights.forEach { h ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Default.Check,
                    contentDescription = null,
                    tint = Color(0xFF2E7D32),
                    modifier = Modifier.size(16.dp)
                )
                Spacer(Modifier.width(6.dp))
                Text(h, fontSize = 13.sp)
            }
            Spacer(Modifier.height(4.dp))
        }
        if (isCurrent) {
            Spacer(Modifier.height(4.dp))
            Text(
                "Current Plan",
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF2E7D32),
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(Color(0xFF2E7D32).copy(alpha = 0.15f))
                    .padding(horizontal = 8.dp, vertical = 3.dp)
            )
        }
    }
}

@Composable
private fun SocialProof() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surface)
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Row {
            repeat(5) {
                Icon(
                    Icons.Default.Star,
                    contentDescription = null,
                    tint = Color(0xFFF2C640),
                    modifier = Modifier.size(16.dp)
                )
            }
            Spacer(Modifier.width(8.dp))
            Text(
                "4.9 · 2,400+ reviews",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Spacer(Modifier.height(8.dp))
        Text(
            text = "\"Seddly caught a $1,200 refund I would have forgotten. Worth every penny.\"",
            fontSize = 12.sp,
            fontStyle = FontStyle.Italic,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun CtaButton(label: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(SeddlyPremium.Gradients.hero)
            .clickable { onClick() }
            .padding(vertical = 16.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            color = Color.White,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
private fun FooterLinks(
    onRestore: () -> Unit,
    onOpenTerms: () -> Unit,
    onOpenPrivacy: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            "Restore Purchases",
            fontSize = 12.sp,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.clickable { onRestore() }
        )
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(
                "Terms",
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.clickable { onOpenTerms() }
            )
            Text(
                "Privacy",
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.clickable { onOpenPrivacy() }
            )
        }
    }
}
