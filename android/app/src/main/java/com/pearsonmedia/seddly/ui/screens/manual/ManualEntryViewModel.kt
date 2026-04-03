package com.pearsonmedia.seddly.ui.screens.manual

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.pearsonmedia.seddly.data.local.entity.CommitmentCategory
import com.pearsonmedia.seddly.data.local.entity.CommitmentEntity
import com.pearsonmedia.seddly.data.local.entity.CommitmentSource
import com.pearsonmedia.seddly.data.repository.CommitmentRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ManualEntryViewModel @Inject constructor(
    private val repository: CommitmentRepository
) : ViewModel() {

    fun saveCommitment(
        entityName: String,
        summary: String,
        category: CommitmentCategory,
        deadline: Long?,
        dollarAmount: Double?,
        notes: String?
    ) {
        viewModelScope.launch {
            val commitment = CommitmentEntity(
                entityName = entityName,
                summary = summary,
                fullText = summary,
                category = category.value,
                deadline = deadline,
                dollarAmount = dollarAmount,
                notes = notes,
                source = CommitmentSource.MANUAL.value,
                confidenceScore = 100 // Manual entry = full confidence
            )
            repository.insert(commitment)
        }
    }
}
