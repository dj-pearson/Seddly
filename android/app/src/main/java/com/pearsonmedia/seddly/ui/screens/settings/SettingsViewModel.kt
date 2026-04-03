package com.pearsonmedia.seddly.ui.screens.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.pearsonmedia.seddly.data.local.dao.PrivacyAuditDao
import com.pearsonmedia.seddly.service.auth.SecureStorageService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SettingsUiState(
    val subscriptionTier: String = "Free",
    val auditLogCount: Int = 0,
    val biometricEnabled: Boolean = false
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val privacyAuditDao: PrivacyAuditDao,
    private val secureStorage: SecureStorageService
) : ViewModel() {

    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            privacyAuditDao.observeCount().collect { count ->
                _uiState.value = _uiState.value.copy(auditLogCount = count)
            }
        }
    }

    fun toggleBiometric() {
        _uiState.value = _uiState.value.copy(
            biometricEnabled = !_uiState.value.biometricEnabled
        )
    }

    fun exportData() {
        // Will be implemented in future story
    }

    fun deleteAllData() {
        viewModelScope.launch {
            // Clear secure storage
            secureStorage.clearAll()
            // Database clearing will be handled by repository
        }
    }
}
