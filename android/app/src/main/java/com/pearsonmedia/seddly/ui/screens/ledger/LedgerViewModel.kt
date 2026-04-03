package com.pearsonmedia.seddly.ui.screens.ledger

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.pearsonmedia.seddly.data.local.entity.CommitmentEntity
import com.pearsonmedia.seddly.data.local.entity.CommitmentStatus
import com.pearsonmedia.seddly.data.repository.CommitmentRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class LedgerUiState(
    val commitments: List<CommitmentEntity> = emptyList(),
    val searchQuery: String = "",
    val selectedStatus: CommitmentStatus? = null,
    val overdueCount: Int = 0,
    val totalCount: Int = 0,
    val isSelectionMode: Boolean = false,
    val selectedIds: Set<String> = emptySet(),
    val isLoading: Boolean = true
)

enum class SortOption(val displayName: String) {
    DATE_ADDED("Date Added"),
    DEADLINE("Deadline"),
    ENTITY("Entity"),
    STATUS("Status")
}

@HiltViewModel
class LedgerViewModel @Inject constructor(
    private val repository: CommitmentRepository
) : ViewModel() {

    private val _searchQuery = MutableStateFlow("")
    private val _selectedStatus = MutableStateFlow<CommitmentStatus?>(null)
    private val _sortOption = MutableStateFlow(SortOption.DATE_ADDED)
    private val _isSelectionMode = MutableStateFlow(false)
    private val _selectedIds = MutableStateFlow<Set<String>>(emptySet())

    val uiState: StateFlow<LedgerUiState> = combine(
        repository.observeAll(),
        _searchQuery,
        _selectedStatus,
        _sortOption,
        repository.observeOverdueCount()
    ) { commitments, query, status, sort, overdueCount ->
        var filtered = commitments

        // Apply search filter
        if (query.isNotBlank()) {
            val lowerQuery = query.lowercase()
            filtered = filtered.filter {
                it.entityName.lowercase().contains(lowerQuery) ||
                    it.summary.lowercase().contains(lowerQuery) ||
                    it.fullText.lowercase().contains(lowerQuery)
            }
        }

        // Apply status filter
        status?.let { s ->
            filtered = filtered.filter { it.status == s.value }
        }

        // Apply sort
        filtered = when (sort) {
            SortOption.DATE_ADDED -> filtered.sortedByDescending { it.createdAt }
            SortOption.DEADLINE -> filtered.sortedBy { it.deadline ?: Long.MAX_VALUE }
            SortOption.ENTITY -> filtered.sortedBy { it.entityName.lowercase() }
            SortOption.STATUS -> filtered.sortedBy { it.status }
        }

        LedgerUiState(
            commitments = filtered,
            searchQuery = query,
            selectedStatus = status,
            overdueCount = overdueCount,
            totalCount = commitments.size,
            isSelectionMode = _isSelectionMode.value,
            selectedIds = _selectedIds.value,
            isLoading = false
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = LedgerUiState()
    )

    fun onSearchQueryChanged(query: String) {
        _searchQuery.value = query
    }

    fun onStatusFilterChanged(status: CommitmentStatus?) {
        _selectedStatus.value = status
    }

    fun onSortChanged(sort: SortOption) {
        _sortOption.value = sort
    }

    fun toggleSelectionMode() {
        _isSelectionMode.value = !_isSelectionMode.value
        if (!_isSelectionMode.value) {
            _selectedIds.value = emptySet()
        }
    }

    fun toggleSelection(id: String) {
        _selectedIds.value = if (id in _selectedIds.value) {
            _selectedIds.value - id
        } else {
            _selectedIds.value + id
        }
    }

    fun fulfillCommitment(id: String) {
        viewModelScope.launch {
            repository.updateStatus(id, CommitmentStatus.FULFILLED.value)
        }
    }

    fun dismissCommitment(id: String) {
        viewModelScope.launch {
            repository.updateStatus(id, CommitmentStatus.DISMISSED.value)
        }
    }

    fun deleteCommitment(id: String) {
        viewModelScope.launch {
            repository.softDelete(id)
        }
    }

    fun bulkUpdateStatus(status: CommitmentStatus) {
        viewModelScope.launch {
            val ids = _selectedIds.value.toList()
            if (ids.isNotEmpty()) {
                repository.bulkUpdateStatus(ids, status.value)
                _selectedIds.value = emptySet()
                _isSelectionMode.value = false
            }
        }
    }
}
