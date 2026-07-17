package com.elyasomar.apksigner.ui.signer

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elyasomar.apksigner.data.storage.DocumentStorage
import com.elyasomar.apksigner.domain.model.SignatureVersions
import com.elyasomar.apksigner.domain.model.SigningException
import com.elyasomar.apksigner.domain.model.SigningRequest
import com.elyasomar.apksigner.domain.repository.SigningRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SignerViewModel @Inject constructor(
    private val repository: SigningRepository,
    private val storage: DocumentStorage,
) : ViewModel() {

    private val _uiState = MutableStateFlow(SignerUiState())
    val uiState: StateFlow<SignerUiState> = _uiState.asStateFlow()

    fun onApkSelected(uri: Uri) {
        val name = storage.displayName(uri, "app.apk")
        _uiState.update { it.copy(apk = SelectedDocument(uri, name), result = null, errorMessage = null) }
    }

    fun onKeystoreSelected(uri: Uri) {
        val name = storage.displayName(uri, "keystore.jks")
        _uiState.update { it.copy(keystore = SelectedDocument(uri, name), result = null, errorMessage = null) }
    }

    fun onOutputFolderSelected(uri: Uri) {
        val name = storage.folderName(uri, "Selected folder")
        _uiState.update { it.copy(outputFolder = SelectedDocument(uri, name)) }
    }

    fun onKeystorePasswordChanged(value: String) {
        _uiState.update { it.copy(keystorePassword = value) }
    }

    fun onKeyAliasChanged(value: String) {
        _uiState.update { it.copy(keyAlias = value) }
    }

    fun onKeyPasswordChanged(value: String) {
        _uiState.update { it.copy(keyPassword = value) }
    }

    fun onVersionsChanged(versions: SignatureVersions) {
        _uiState.update { it.copy(versions = versions) }
    }

    fun onErrorDismissed() {
        _uiState.update { it.copy(errorMessage = null) }
    }

    fun onResultDismissed() {
        _uiState.update { it.copy(result = null) }
    }

    fun sign() {
        val state = _uiState.value
        if (!state.canSign) return

        if (!state.versions.isV4Satisfied) {
            _uiState.update {
                it.copy(errorMessage = "V4 signing requires V2 or V3 to be enabled.")
            }
            return
        }

        val request = SigningRequest(
            apkUri = state.apk!!.uri,
            keystoreUri = state.keystore!!.uri,
            outputTreeUri = state.outputFolder!!.uri,
            keystorePassword = state.keystorePassword.toCharArray(),
            keyAlias = state.keyAlias.trim(),
            keyPassword = state.keyPassword.toCharArray(),
            versions = state.versions,
        )

        _uiState.update { it.copy(isSigning = true, errorMessage = null, result = null) }

        viewModelScope.launch {
            try {
                val success = repository.signApk(request)
                _uiState.update { it.copy(isSigning = false, result = success) }
            } catch (e: SigningException) {
                _uiState.update { it.copy(isSigning = false, errorMessage = e.message) }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(isSigning = false, errorMessage = e.message ?: "An unexpected error occurred.")
                }
            }
        }
    }
}
