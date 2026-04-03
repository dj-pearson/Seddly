package com.pearsonmedia.seddly.ui.screens.ledger

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SearchBar
import androidx.compose.material3.SearchBarDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.pearsonmedia.seddly.data.local.entity.CommitmentStatus
import com.pearsonmedia.seddly.ui.components.CommitmentCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LedgerScreen(
    onCommitmentClick: (String) -> Unit,
    onAddManualClick: () -> Unit,
    viewModel: LedgerViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showSearch by remember { mutableStateOf(false) }
    var showFilterMenu by remember { mutableStateOf(false) }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Top App Bar
            TopAppBar(
                title = {
                    Column {
                        Text("Ledger")
                        if (uiState.overdueCount > 0) {
                            Text(
                                text = "${uiState.overdueCount} overdue",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.error
                            )
                        }
                    }
                },
                actions = {
                    IconButton(
                        onClick = { showSearch = !showSearch },
                        modifier = Modifier.semantics {
                            contentDescription = "Search commitments"
                        }
                    ) {
                        Icon(Icons.Default.Search, "Search")
                    }
                    Box {
                        IconButton(
                            onClick = { showFilterMenu = true },
                            modifier = Modifier.semantics {
                                contentDescription = "Filter commitments by status"
                            }
                        ) {
                            Icon(Icons.Default.FilterList, "Filter")
                        }
                        DropdownMenu(
                            expanded = showFilterMenu,
                            onDismissRequest = { showFilterMenu = false }
                        ) {
                            DropdownMenuItem(
                                text = { Text("All") },
                                onClick = {
                                    viewModel.onStatusFilterChanged(null)
                                    showFilterMenu = false
                                }
                            )
                            CommitmentStatus.entries.forEach { status ->
                                DropdownMenuItem(
                                    text = { Text(status.value.replaceFirstChar { it.uppercase() }) },
                                    onClick = {
                                        viewModel.onStatusFilterChanged(status)
                                        showFilterMenu = false
                                    }
                                )
                            }
                        }
                    }
                }
            )

            // Search bar
            AnimatedVisibility(
                visible = showSearch,
                enter = slideInVertically(),
                exit = slideOutVertically()
            ) {
                SearchBar(
                    inputField = {
                        SearchBarDefaults.InputField(
                            query = uiState.searchQuery,
                            onQueryChange = viewModel::onSearchQueryChanged,
                            onSearch = { showSearch = false },
                            expanded = false,
                            onExpandedChange = {},
                            placeholder = { Text("Search commitments...") },
                            trailingIcon = {
                                if (uiState.searchQuery.isNotEmpty()) {
                                    IconButton(onClick = { viewModel.onSearchQueryChanged("") }) {
                                        Icon(Icons.Default.Close, "Clear search")
                                    }
                                }
                            }
                        )
                    },
                    expanded = false,
                    onExpandedChange = {},
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                ) {}
            }

            // Status filter chips
            if (uiState.selectedStatus != null) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    FilterChip(
                        selected = true,
                        onClick = { viewModel.onStatusFilterChanged(null) },
                        label = { Text(uiState.selectedStatus!!.value.replaceFirstChar { it.uppercase() }) },
                        trailingIcon = { Icon(Icons.Default.Close, "Clear filter", Modifier.size(16.dp)) }
                    )
                }
            }

            // Bulk action bar
            AnimatedVisibility(visible = uiState.isSelectionMode && uiState.selectedIds.isNotEmpty()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp)
                        .semantics {
                            contentDescription = "${uiState.selectedIds.size} commitments selected"
                        },
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        "${uiState.selectedIds.size} selected",
                        style = MaterialTheme.typography.labelLarge
                    )
                    Row {
                        TextButton(onClick = { viewModel.bulkUpdateStatus(CommitmentStatus.FULFILLED) }) {
                            Icon(Icons.Default.CheckCircle, null, Modifier.size(16.dp))
                            Spacer(Modifier.width(4.dp))
                            Text("Fulfill")
                        }
                        TextButton(onClick = { viewModel.bulkUpdateStatus(CommitmentStatus.DISMISSED) }) {
                            Text("Dismiss")
                        }
                    }
                }
            }

            // Content
            when {
                uiState.isLoading -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                }
                uiState.commitments.isEmpty() -> {
                    EmptyLedgerContent(onAddClick = onAddManualClick)
                }
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(
                            horizontal = 16.dp,
                            vertical = 8.dp
                        )
                    ) {
                        items(
                            items = uiState.commitments,
                            key = { it.id }
                        ) { commitment ->
                            CommitmentCard(
                                commitment = commitment,
                                isSelected = commitment.id in uiState.selectedIds,
                                isSelectionMode = uiState.isSelectionMode,
                                onClick = {
                                    if (uiState.isSelectionMode) {
                                        viewModel.toggleSelection(commitment.id)
                                    } else {
                                        onCommitmentClick(commitment.id)
                                    }
                                },
                                onLongClick = {
                                    if (!uiState.isSelectionMode) {
                                        viewModel.toggleSelectionMode()
                                        viewModel.toggleSelection(commitment.id)
                                    }
                                },
                                onFulfill = { viewModel.fulfillCommitment(commitment.id) },
                                onDismiss = { viewModel.dismissCommitment(commitment.id) }
                            )
                        }
                    }
                }
            }
        }

        // FAB
        if (!uiState.isSelectionMode) {
            FloatingActionButton(
                onClick = onAddManualClick,
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(16.dp)
                    .semantics { contentDescription = "Add commitment manually" }
            ) {
                Icon(Icons.Default.Add, contentDescription = "Add")
            }
        }
    }
}

@Composable
private fun EmptyLedgerContent(onAddClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "No Commitments Yet",
            style = MaterialTheme.typography.headlineSmall,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Take a screenshot of a promise, commitment, or agreement and Seddly will track it for you.",
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(modifier = Modifier.height(24.dp))
        TextButton(onClick = onAddClick) {
            Icon(Icons.Default.Add, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("Add Manually")
        }
    }
}
