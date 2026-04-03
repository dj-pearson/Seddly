package com.pearsonmedia.seddly.ui.screens.manual

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material3.Button
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.pearsonmedia.seddly.data.local.entity.CommitmentCategory
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ManualEntryScreen(
    onBack: () -> Unit,
    onSaved: () -> Unit,
    viewModel: ManualEntryViewModel = hiltViewModel()
) {
    var entityName by remember { mutableStateOf("") }
    var summary by remember { mutableStateOf("") }
    var dollarAmount by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }
    var deadline by remember { mutableStateOf<Long?>(null) }
    var selectedCategory by remember { mutableStateOf(CommitmentCategory.UNCATEGORIZED) }
    var showDatePicker by remember { mutableStateOf(false) }
    var categoryExpanded by remember { mutableStateOf(false) }
    var amountError by remember { mutableStateOf<String?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Add Commitment") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp)
        ) {
            OutlinedTextField(
                value = entityName,
                onValueChange = { entityName = it },
                label = { Text("Entity Name *") },
                placeholder = { Text("Who made this commitment?") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )

            Spacer(Modifier.height(12.dp))

            OutlinedTextField(
                value = summary,
                onValueChange = { summary = it },
                label = { Text("Summary *") },
                placeholder = { Text("What was promised?") },
                modifier = Modifier.fillMaxWidth(),
                minLines = 2
            )

            Spacer(Modifier.height(12.dp))

            // Category dropdown
            ExposedDropdownMenuBox(
                expanded = categoryExpanded,
                onExpandedChange = { categoryExpanded = it }
            ) {
                OutlinedTextField(
                    value = selectedCategory.displayName,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Category") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = categoryExpanded) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .menuAnchor(MenuAnchorType.PrimaryNotEditable)
                )
                ExposedDropdownMenu(
                    expanded = categoryExpanded,
                    onDismissRequest = { categoryExpanded = false }
                ) {
                    CommitmentCategory.entries.forEach { category ->
                        DropdownMenuItem(
                            text = { Text(category.displayName) },
                            onClick = {
                                selectedCategory = category
                                categoryExpanded = false
                            }
                        )
                    }
                }
            }

            Spacer(Modifier.height(12.dp))

            // Deadline
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = deadline?.let {
                        SimpleDateFormat("MMM d, yyyy", Locale.getDefault()).format(Date(it))
                    } ?: "",
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Deadline") },
                    placeholder = { Text("Optional") },
                    modifier = Modifier.weight(1f),
                    trailingIcon = {
                        IconButton(onClick = { showDatePicker = true }) {
                            Icon(Icons.Default.CalendarToday, "Pick date")
                        }
                    }
                )
                if (deadline != null) {
                    Spacer(Modifier.width(8.dp))
                    TextButton(onClick = { deadline = null }) {
                        Text("Clear")
                    }
                }
            }

            // Past deadline warning
            deadline?.let { dl ->
                if (dl < System.currentTimeMillis()) {
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = "This commitment will be immediately overdue",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.error
                    )
                }
            }

            Spacer(Modifier.height(12.dp))

            // Dollar amount
            OutlinedTextField(
                value = dollarAmount,
                onValueChange = { input ->
                    dollarAmount = input
                    amountError = validateAmount(input)
                },
                label = { Text("Dollar Amount") },
                placeholder = { Text("0.00") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                isError = amountError != null,
                supportingText = amountError?.let { { Text(it) } },
                prefix = { Text("$") }
            )

            Spacer(Modifier.height(12.dp))

            OutlinedTextField(
                value = notes,
                onValueChange = { notes = it },
                label = { Text("Notes") },
                placeholder = { Text("Optional notes...") },
                modifier = Modifier.fillMaxWidth(),
                minLines = 3
            )

            Spacer(Modifier.height(24.dp))

            Button(
                onClick = {
                    val amount = dollarAmount.toDoubleOrNull()
                    viewModel.saveCommitment(
                        entityName = entityName.trim(),
                        summary = summary.trim(),
                        category = selectedCategory,
                        deadline = deadline,
                        dollarAmount = amount,
                        notes = notes.trim().ifEmpty { null }
                    )
                    onSaved()
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = entityName.isNotBlank() && summary.isNotBlank() && amountError == null
            ) {
                Text("Save Commitment")
            }
        }

        if (showDatePicker) {
            val datePickerState = rememberDatePickerState(initialSelectedDateMillis = deadline)
            DatePickerDialog(
                onDismissRequest = { showDatePicker = false },
                confirmButton = {
                    TextButton(onClick = {
                        deadline = datePickerState.selectedDateMillis
                        showDatePicker = false
                    }) { Text("OK") }
                },
                dismissButton = {
                    TextButton(onClick = { showDatePicker = false }) { Text("Cancel") }
                }
            ) {
                DatePicker(state = datePickerState)
            }
        }
    }
}

private fun validateAmount(input: String): String? {
    if (input.isBlank()) return null
    val cleaned = input.replace("$", "").trim()
    if (cleaned.isEmpty()) return null
    if (cleaned.count { it == '.' } > 1) return "Invalid amount format"
    val value = cleaned.toDoubleOrNull() ?: return "Not a valid number"
    if (value < 0) return "Amount cannot be negative"
    return null
}
