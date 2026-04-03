package com.pearsonmedia.seddly.ui.screens.detail

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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.RemoveCircleOutline
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.pearsonmedia.seddly.data.local.entity.CommitmentStatus
import com.pearsonmedia.seddly.ui.components.ConfidenceBadge
import com.pearsonmedia.seddly.ui.theme.SeddlyColors
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CommitmentDetailScreen(
    commitmentId: String,
    onBack: () -> Unit,
    viewModel: CommitmentDetailViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var isEditing by remember { mutableStateOf(false) }
    var showDeleteDialog by remember { mutableStateOf(false) }
    var showDatePicker by remember { mutableStateOf(false) }

    LaunchedEffect(commitmentId) {
        viewModel.loadCommitment(commitmentId)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Commitment Detail") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                actions = {
                    if (uiState.commitment != null) {
                        IconButton(
                            onClick = { isEditing = !isEditing },
                            modifier = Modifier.semantics {
                                contentDescription = "Edit commitment details"
                            }
                        ) {
                            Icon(Icons.Default.Edit, "Edit")
                        }
                    }
                }
            )
        }
    ) { padding ->
        val commitment = uiState.commitment

        when {
            uiState.isLoading -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            }
            commitment == null -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    contentAlignment = Alignment.Center
                ) {
                    Text("Commitment not found")
                }
            }
            else -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                        .verticalScroll(rememberScrollState())
                        .padding(16.dp)
                ) {
                    // Status header
                    Card(
                        colors = CardDefaults.cardColors(
                            containerColor = SeddlyColors.statusColor(commitment.status).copy(alpha = 0.1f)
                        ),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(12.dp)
                                    .clip(CircleShape)
                                    .background(SeddlyColors.statusColor(commitment.status))
                            )
                            Spacer(Modifier.width(12.dp))
                            Text(
                                text = commitment.status.replaceFirstChar { it.uppercase() },
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold
                            )
                            Spacer(Modifier.weight(1f))
                            ConfidenceBadge(score = commitment.confidenceScore)
                        }
                    }

                    Spacer(Modifier.height(16.dp))

                    // Entity name
                    Text(
                        text = commitment.entityName,
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold
                    )

                    Spacer(Modifier.height(8.dp))

                    // Summary
                    if (isEditing) {
                        var editedSummary by remember { mutableStateOf(commitment.summary) }
                        OutlinedTextField(
                            value = editedSummary,
                            onValueChange = { editedSummary = it },
                            label = { Text("Summary") },
                            modifier = Modifier.fillMaxWidth(),
                            minLines = 2
                        )
                        Spacer(Modifier.height(8.dp))
                        Button(
                            onClick = {
                                viewModel.updateSummary(editedSummary)
                                isEditing = false
                            }
                        ) {
                            Text("Save")
                        }
                    } else {
                        Text(
                            text = commitment.summary,
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    Spacer(Modifier.height(16.dp))

                    // Details card
                    Card(
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            // Deadline
                            DetailRow(
                                label = "Deadline",
                                value = commitment.deadline?.let {
                                    SimpleDateFormat("MMMM d, yyyy", Locale.getDefault()).format(Date(it))
                                } ?: "No deadline set",
                                icon = { Icon(Icons.Default.CalendarToday, null, Modifier.size(18.dp)) },
                                onEdit = if (isEditing) { { showDatePicker = true } } else null
                            )

                            // Amount
                            commitment.dollarAmount?.let { amount ->
                                Spacer(Modifier.height(12.dp))
                                DetailRow(
                                    label = "Amount",
                                    value = "$${String.format("%.2f", amount)}"
                                )
                            }

                            // Category
                            Spacer(Modifier.height(12.dp))
                            DetailRow(
                                label = "Category",
                                value = commitment.category.replaceFirstChar { it.uppercase() }
                            )

                            // Source
                            Spacer(Modifier.height(12.dp))
                            DetailRow(
                                label = "Source",
                                value = commitment.source.replace("_", " ").replaceFirstChar { it.uppercase() }
                            )

                            // Created
                            Spacer(Modifier.height(12.dp))
                            DetailRow(
                                label = "Created",
                                value = SimpleDateFormat("MMM d, yyyy h:mm a", Locale.getDefault())
                                    .format(Date(commitment.createdAt))
                            )
                        }
                    }

                    // AI Reasoning
                    commitment.aiReasoning?.let { reasoning ->
                        Spacer(Modifier.height(16.dp))
                        Card(
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Text(
                                    "AI Reasoning",
                                    style = MaterialTheme.typography.titleSmall,
                                    fontWeight = FontWeight.SemiBold
                                )
                                Spacer(Modifier.height(8.dp))
                                Text(
                                    text = reasoning,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }

                    // Notes
                    commitment.notes?.takeIf { it.isNotBlank() }?.let { notes ->
                        Spacer(Modifier.height(16.dp))
                        Card(
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Text(
                                    "Notes",
                                    style = MaterialTheme.typography.titleSmall,
                                    fontWeight = FontWeight.SemiBold
                                )
                                Spacer(Modifier.height(8.dp))
                                Text(
                                    text = notes,
                                    style = MaterialTheme.typography.bodyMedium
                                )
                            }
                        }
                    }

                    Spacer(Modifier.height(24.dp))

                    // Action buttons
                    if (commitment.status == CommitmentStatus.PENDING.value ||
                        commitment.status == CommitmentStatus.OVERDUE.value
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Button(
                                onClick = { viewModel.updateStatus(CommitmentStatus.FULFILLED.value) },
                                modifier = Modifier
                                    .weight(1f)
                                    .semantics { contentDescription = "Mark this commitment as fulfilled" },
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = SeddlyColors.Fulfilled
                                )
                            ) {
                                Icon(Icons.Default.CheckCircle, null, Modifier.size(18.dp))
                                Spacer(Modifier.width(8.dp))
                                Text("Fulfill")
                            }

                            OutlinedButton(
                                onClick = { viewModel.updateStatus(CommitmentStatus.DISMISSED.value) },
                                modifier = Modifier
                                    .weight(1f)
                                    .semantics { contentDescription = "Dismiss this commitment" }
                            ) {
                                Icon(Icons.Default.RemoveCircleOutline, null, Modifier.size(18.dp))
                                Spacer(Modifier.width(8.dp))
                                Text("Dismiss")
                            }
                        }

                        Spacer(Modifier.height(12.dp))
                    }

                    // Delete button
                    OutlinedButton(
                        onClick = { showDeleteDialog = true },
                        modifier = Modifier
                            .fillMaxWidth()
                            .semantics { contentDescription = "Delete this commitment permanently" },
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = MaterialTheme.colorScheme.error
                        )
                    ) {
                        Icon(Icons.Default.Delete, null, Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("Delete")
                    }

                    // Past deadline warning
                    commitment.deadline?.let { dl ->
                        if (dl < System.currentTimeMillis() && commitment.status == CommitmentStatus.PENDING.value) {
                            Spacer(Modifier.height(8.dp))
                            Text(
                                text = "This commitment is past its deadline",
                                style = MaterialTheme.typography.labelMedium,
                                color = SeddlyColors.UrgencyOverdue
                            )
                        }
                    }

                    Spacer(Modifier.height(32.dp))
                }
            }
        }

        // Delete confirmation dialog
        if (showDeleteDialog) {
            AlertDialog(
                onDismissRequest = { showDeleteDialog = false },
                title = { Text("Delete Commitment?") },
                text = { Text("This action cannot be undone. The commitment will be permanently removed.") },
                confirmButton = {
                    TextButton(
                        onClick = {
                            viewModel.delete()
                            showDeleteDialog = false
                            onBack()
                        }
                    ) {
                        Text("Delete", color = MaterialTheme.colorScheme.error)
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showDeleteDialog = false }) {
                        Text("Cancel")
                    }
                }
            )
        }

        // Date picker dialog
        if (showDatePicker) {
            val datePickerState = rememberDatePickerState(
                initialSelectedDateMillis = uiState.commitment?.deadline
            )
            DatePickerDialog(
                onDismissRequest = { showDatePicker = false },
                confirmButton = {
                    TextButton(onClick = {
                        datePickerState.selectedDateMillis?.let { viewModel.updateDeadline(it) }
                        showDatePicker = false
                    }) {
                        Text("OK")
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showDatePicker = false }) {
                        Text("Cancel")
                    }
                }
            ) {
                DatePicker(state = datePickerState)
            }
        }
    }
}

@Composable
private fun DetailRow(
    label: String,
    value: String,
    icon: @Composable (() -> Unit)? = null,
    onEdit: (() -> Unit)? = null
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            icon?.invoke()
            if (icon != null) Spacer(Modifier.width(8.dp))
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = value,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium
            )
            onEdit?.let {
                Spacer(Modifier.width(8.dp))
                IconButton(onClick = it, modifier = Modifier.size(20.dp)) {
                    Icon(Icons.Default.Edit, "Edit", Modifier.size(14.dp))
                }
            }
        }
    }
}
