package com.pearsonmedia.seddly.ui.screens.detail

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.pearsonmedia.seddly.data.local.entity.CommitmentEntity
import com.pearsonmedia.seddly.data.repository.CommitmentRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import javax.inject.Inject

data class DetailUiState(
    val commitment: CommitmentEntity? = null,
    val isLoading: Boolean = true
)

@HiltViewModel
class CommitmentDetailViewModel @Inject constructor(
    private val repository: CommitmentRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(DetailUiState())
    val uiState: StateFlow<DetailUiState> = _uiState.asStateFlow()

    fun loadCommitment(id: String) {
        viewModelScope.launch {
            repository.observeById(id).collectLatest { commitment ->
                _uiState.value = DetailUiState(
                    commitment = commitment,
                    isLoading = false
                )
            }
        }
    }

    fun updateStatus(status: String) {
        val id = _uiState.value.commitment?.id ?: return
        viewModelScope.launch {
            repository.updateStatus(id, status)
        }
    }

    fun updateSummary(summary: String) {
        val commitment = _uiState.value.commitment ?: return
        viewModelScope.launch {
            repository.update(commitment.copy(summary = summary.trim()))
        }
    }

    fun updateDeadline(deadline: Long) {
        val commitment = _uiState.value.commitment ?: return
        viewModelScope.launch {
            repository.update(commitment.copy(deadline = deadline))
        }
    }

    fun delete() {
        val id = _uiState.value.commitment?.id ?: return
        viewModelScope.launch {
            repository.softDelete(id)
        }
    }
}
