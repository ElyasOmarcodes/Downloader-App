package com.elyasomar.apksigner.ui.keystore

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elyasomar.apksigner.data.storage.DocumentStorage
import com.elyasomar.apksigner.domain.model.KeyAlgorithm
import com.elyasomar.apksigner.domain.model.KeystoreFormat
import com.elyasomar.apksigner.domain.model.KeystoreSpec
import com.elyasomar.apksigner.domain.model.SigningException
import com.elyasomar.apksigner.domain.repository.KeystoreRepository
import com.elyasomar.apksigner.ui.signer.SelectedDocument
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class KeystoreViewModel @Inject constructor(
    private val repository: KeystoreRepository,
    private val storage: DocumentStorage,
) : ViewModel() {

    private val _uiState = MutableStateFlow(KeystoreUiState())
    val uiState: StateFlow<KeystoreUiState> = _uiState.asStateFlow()

    fun onOutputFolderSelected(uri: Uri) {
        val name = storage.folderName(uri, "Selected folder")
        _uiState.update { it.copy(outputFolder = SelectedDocument(uri, name)) }
    }

    fun onFileNameChanged(value: String) = _uiState.update { it.copy(fileName = value) }
    fun onFormatChanged(value: KeystoreFormat) = _uiState.update { it.copy(format = value) }
    fun onAlgorithmChanged(value: KeyAlgorithm) = _uiState.update { it.copy(algorithm = value) }
    fun onAliasChanged(value: String) = _uiState.update { it.copy(alias = value) }
    fun onStorePasswordChanged(value: String) = _uiState.update { it.copy(storePassword = value) }
    fun onKeyPasswordChanged(value: String) = _uiState.update { it.copy(keyPassword = value) }
    fun onValidityChanged(value: String) =
        _uiState.update { it.copy(validityYears = value.filter(Char::isDigit).take(4)) }

    fun onCommonNameChanged(value: String) = _uiState.update { it.copy(commonName = value) }
    fun onOrgUnitChanged(value: String) = _uiState.update { it.copy(organizationalUnit = value) }
    fun onOrganizationChanged(value: String) = _uiState.update { it.copy(organization = value) }
    fun onLocalityChanged(value: String) = _uiState.update { it.copy(locality = value) }
    fun onStateChanged(value: String) = _uiState.update { it.copy(state = value) }
    fun onCountryChanged(value: String) =
        _uiState.update { it.copy(country = value.uppercase().take(2)) }

    fun onErrorDismissed() = _uiState.update { it.copy(errorMessage = null) }

    fun generate() {
        val state = _uiState.value
        if (!state.canGenerate) return

        val spec = KeystoreSpec(
            outputTreeUri = state.outputFolder!!.uri,
            fileName = state.fileName.trim(),
            format = state.format,
            algorithm = state.algorithm,
            alias = state.alias.trim(),
            storePassword = state.storePassword.toCharArray(),
            keyPassword = state.keyPassword.toCharArray(),
            validityYears = state.validityYears.toIntOrNull() ?: 25,
            commonName = state.commonName,
            organizationalUnit = state.organizationalUnit,
            organization = state.organization,
            locality = state.locality,
            state = state.state,
            country = state.country,
        )

        _uiState.update { it.copy(isGenerating = true, errorMessage = null, result = null) }

        viewModelScope.launch {
            try {
                val success = repository.generateKeystore(spec)
                _uiState.update { it.copy(isGenerating = false, result = success) }
            } catch (e: SigningException) {
                _uiState.update { it.copy(isGenerating = false, errorMessage = e.message) }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isGenerating = false,
                        errorMessage = e.message ?: "An unexpected error occurred.",
                    )
                }
            }
        }
    }
}
