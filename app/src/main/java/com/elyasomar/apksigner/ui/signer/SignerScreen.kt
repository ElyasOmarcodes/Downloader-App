package com.elyasomar.apksigner.ui.signer

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.elyasomar.apksigner.R
import com.elyasomar.apksigner.domain.model.ApkInfo
import com.elyasomar.apksigner.domain.model.CertificateInfo
import com.elyasomar.apksigner.domain.model.SignatureVersions
import com.elyasomar.apksigner.ui.icons.AppIcons
import com.elyasomar.apksigner.ui.signer.components.InfoRow
import com.elyasomar.apksigner.ui.signer.components.SectionCard

@Composable
fun SignerScreen(
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier,
    viewModel: SignerViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val scrollState = rememberScrollState()

    val artifactLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri: Uri? -> uri?.let(viewModel::onApkSelected) }

    val keystoreLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri: Uri? -> uri?.let(viewModel::onKeystoreSelected) }

    val outputLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocumentTree(),
    ) { uri: Uri? ->
        uri?.let {
            val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            runCatching { context.contentResolver.takePersistableUriPermission(it, flags) }
            viewModel.onOutputFolderSelected(it)
        }
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .verticalScroll(scrollState)
            .padding(contentPadding)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        AnimatedVisibility(visible = state.isSigning) {
            LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
        }

        SectionCard(title = stringResource(R.string.section_apk), icon = AppIcons.Android) {
            DocumentRow(
                fileName = state.apk?.displayName,
                placeholder = stringResource(R.string.placeholder_no_apk),
            )
            Spacer(Modifier.height(12.dp))
            FilledTonalButton(
                onClick = { artifactLauncher.launch(arrayOf("*/*")) },
                enabled = !state.isSigning,
                modifier = Modifier.fillMaxWidth(),
            ) { Text(stringResource(R.string.action_select_apk)) }
        }

        SectionCard(title = stringResource(R.string.section_keystore), icon = AppIcons.Key) {
            DocumentRow(
                fileName = state.keystore?.displayName,
                placeholder = stringResource(R.string.placeholder_no_keystore),
            )
            Spacer(Modifier.height(12.dp))
            FilledTonalButton(
                onClick = { keystoreLauncher.launch(arrayOf("*/*")) },
                enabled = !state.isSigning,
                modifier = Modifier.fillMaxWidth(),
            ) { Text(stringResource(R.string.action_select_keystore)) }
        }

        SectionCard(
            title = stringResource(R.string.section_credentials),
            icon = AppIcons.Lock,
        ) {
            CredentialFields(
                state = state,
                onKeystorePasswordChanged = viewModel::onKeystorePasswordChanged,
                onKeyAliasChanged = viewModel::onKeyAliasChanged,
                onKeyPasswordChanged = viewModel::onKeyPasswordChanged,
            )
        }

        SectionCard(
            title = stringResource(R.string.section_signature_versions),
            icon = AppIcons.Shield,
        ) {
            if (state.isBundleSelected) {
                Text(
                    text = stringResource(R.string.note_aab_scheme),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            } else {
                SignatureVersionSelector(
                    versions = state.versions,
                    enabled = !state.isSigning,
                    onVersionsChanged = viewModel::onVersionsChanged,
                )
            }
        }

        SectionCard(
            title = stringResource(R.string.section_output),
            icon = AppIcons.Folder,
        ) {
            DocumentRow(
                fileName = state.outputFolder?.displayName,
                placeholder = stringResource(R.string.placeholder_no_output),
            )
            Spacer(Modifier.height(12.dp))
            FilledTonalButton(
                onClick = { outputLauncher.launch(null) },
                enabled = !state.isSigning,
                modifier = Modifier.fillMaxWidth(),
            ) { Text(stringResource(R.string.action_select_output)) }
        }

        Button(
            onClick = viewModel::sign,
            enabled = state.canSign,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
        ) {
            if (state.isSigning) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp,
                    color = MaterialTheme.colorScheme.onPrimary,
                )
                Spacer(Modifier.width(12.dp))
                Text(stringResource(R.string.action_signing))
            } else {
                Text(stringResource(R.string.action_sign))
            }
        }

        state.errorMessage?.let { message ->
            ErrorCard(message = message, onDismiss = viewModel::onErrorDismissed)
        }

        state.result?.let { result ->
            SuccessCard(fileName = result.outputFileName)
            result.apkInfo?.let { ApkInfoCard(info = it) }
            CertificateInfoCard(info = result.certificateInfo)
        }

        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun DocumentRow(fileName: String?, placeholder: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(
            imageVector = AppIcons.Description,
            contentDescription = null,
            tint = if (fileName != null) {
                MaterialTheme.colorScheme.primary
            } else {
                MaterialTheme.colorScheme.onSurfaceVariant
            },
        )
        Spacer(Modifier.width(8.dp))
        Text(
            text = fileName ?: placeholder,
            style = MaterialTheme.typography.bodyMedium,
            color = if (fileName != null) {
                MaterialTheme.colorScheme.onSurface
            } else {
                MaterialTheme.colorScheme.onSurfaceVariant
            },
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun CredentialFields(
    state: SignerUiState,
    onKeystorePasswordChanged: (String) -> Unit,
    onKeyAliasChanged: (String) -> Unit,
    onKeyPasswordChanged: (String) -> Unit,
) {
    var storePasswordVisible by rememberSaveable { mutableStateOf(false) }
    var keyPasswordVisible by rememberSaveable { mutableStateOf(false) }

    OutlinedTextField(
        value = state.keystorePassword,
        onValueChange = onKeystorePasswordChanged,
        label = { Text(stringResource(R.string.field_keystore_password)) },
        singleLine = true,
        enabled = !state.isSigning,
        visualTransformation = passwordTransformation(storePasswordVisible),
        trailingIcon = {
            PasswordToggle(visible = storePasswordVisible) { storePasswordVisible = it }
        },
        modifier = Modifier.fillMaxWidth(),
    )
    Spacer(Modifier.height(12.dp))
    OutlinedTextField(
        value = state.keyAlias,
        onValueChange = onKeyAliasChanged,
        label = { Text(stringResource(R.string.field_key_alias)) },
        singleLine = true,
        enabled = !state.isSigning,
        modifier = Modifier.fillMaxWidth(),
    )
    Spacer(Modifier.height(12.dp))
    OutlinedTextField(
        value = state.keyPassword,
        onValueChange = onKeyPasswordChanged,
        label = { Text(stringResource(R.string.field_key_password)) },
        supportingText = { Text(stringResource(R.string.field_key_password_hint)) },
        singleLine = true,
        enabled = !state.isSigning,
        visualTransformation = passwordTransformation(keyPasswordVisible),
        trailingIcon = {
            PasswordToggle(visible = keyPasswordVisible) { keyPasswordVisible = it }
        },
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun SignatureVersionSelector(
    versions: SignatureVersions,
    enabled: Boolean,
    onVersionsChanged: (SignatureVersions) -> Unit,
) {
    SchemeToggle(
        label = stringResource(R.string.scheme_v1),
        checked = versions.v1,
        enabled = enabled,
    ) { onVersionsChanged(versions.copy(v1 = it)) }
    SchemeToggle(
        label = stringResource(R.string.scheme_v2),
        checked = versions.v2,
        enabled = enabled,
    ) { onVersionsChanged(versions.copy(v2 = it)) }
    SchemeToggle(
        label = stringResource(R.string.scheme_v3),
        checked = versions.v3,
        enabled = enabled,
    ) { onVersionsChanged(versions.copy(v3 = it)) }
    SchemeToggle(
        label = stringResource(R.string.scheme_v4),
        checked = versions.v4,
        enabled = enabled,
    ) { onVersionsChanged(versions.copy(v4 = it)) }
}

@Composable
private fun SchemeToggle(
    label: String,
    checked: Boolean,
    enabled: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            enabled = enabled,
        )
    }
}

@Composable
private fun PasswordToggle(visible: Boolean, onToggle: (Boolean) -> Unit) {
    IconButton(onClick = { onToggle(!visible) }) {
        Icon(
            imageVector = if (visible) AppIcons.VisibilityOff else AppIcons.Visibility,
            contentDescription = null,
        )
    }
}

@Composable
private fun ErrorCard(message: String, onDismiss: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.errorContainer,
        ),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onErrorContainer,
            )
            Spacer(Modifier.height(8.dp))
            TextButton(
                onClick = onDismiss,
                modifier = Modifier.align(Alignment.End),
            ) { Text(stringResource(R.string.action_dismiss)) }
        }
    }
}

@Composable
private fun SuccessCard(fileName: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer,
        ),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = AppIcons.CheckCircle,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(28.dp),
            )
            Spacer(Modifier.width(12.dp))
            Column {
                Text(
                    text = stringResource(R.string.msg_success),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = stringResource(R.string.msg_saved_as, fileName),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                )
            }
        }
    }
}

@Composable
private fun ApkInfoCard(info: ApkInfo) {
    SectionCard(
        title = stringResource(R.string.section_apk_info),
        icon = AppIcons.Android,
    ) {
        InfoRow(stringResource(R.string.label_package), info.packageName)
        InfoRow(
            stringResource(R.string.label_version),
            "${info.versionName} (${info.versionCode})",
        )
        if (info.minSdk > 0) {
            InfoRow(stringResource(R.string.label_min_sdk), info.minSdk.toString())
        }
    }
}

@Composable
private fun CertificateInfoCard(info: CertificateInfo) {
    SectionCard(
        title = stringResource(R.string.section_certificate_info),
        icon = AppIcons.VerifiedUser,
    ) {
        InfoRow(stringResource(R.string.label_subject), info.subject)
        InfoRow(stringResource(R.string.label_issuer), info.issuer)
        InfoRow(stringResource(R.string.label_serial), info.serialNumber, monospace = true)
        InfoRow(
            stringResource(R.string.label_signature_algorithm),
            info.signatureAlgorithm,
        )
        InfoRow(stringResource(R.string.label_sha256), info.sha256Fingerprint, monospace = true)
        HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
        InfoRow(stringResource(R.string.label_valid_from), info.validFrom)
        InfoRow(stringResource(R.string.label_valid_until), info.validUntil)
        val validityText = if (info.isCurrentlyValid) {
            stringResource(R.string.label_valid)
        } else {
            stringResource(R.string.label_expired)
        }
        Box(modifier = Modifier.padding(top = 8.dp)) {
            Text(
                text = validityText,
                style = MaterialTheme.typography.labelLarge,
                color = if (info.isCurrentlyValid) {
                    MaterialTheme.colorScheme.primary
                } else {
                    MaterialTheme.colorScheme.error
                },
            )
        }
    }
}

private fun passwordTransformation(visible: Boolean): VisualTransformation =
    if (visible) VisualTransformation.None else PasswordVisualTransformation()
