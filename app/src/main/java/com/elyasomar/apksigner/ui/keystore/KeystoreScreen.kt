package com.elyasomar.apksigner.ui.keystore

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.elyasomar.apksigner.R
import com.elyasomar.apksigner.domain.model.CertificateInfo
import com.elyasomar.apksigner.domain.model.KeyAlgorithm
import com.elyasomar.apksigner.domain.model.KeystoreFormat
import com.elyasomar.apksigner.ui.icons.AppIcons
import com.elyasomar.apksigner.ui.signer.components.InfoRow
import com.elyasomar.apksigner.ui.signer.components.SectionCard

@Composable
fun KeystoreScreen(
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier,
    viewModel: KeystoreViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val scrollState = rememberScrollState()
    val enabled = !state.isGenerating

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
        AnimatedVisibility(visible = state.isGenerating) {
            LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
        }

        SectionCard(title = stringResource(R.string.ks_section_file), icon = AppIcons.Description) {
            OutlinedTextField(
                value = state.fileName,
                onValueChange = viewModel::onFileNameChanged,
                label = { Text(stringResource(R.string.ks_field_file_name)) },
                singleLine = true,
                enabled = enabled,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(12.dp))
            Text(
                text = stringResource(R.string.ks_field_format),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(6.dp))
            ChoiceChips(
                options = KeystoreFormat.entries,
                selected = state.format,
                enabled = enabled,
                label = { it.displayName },
                onSelected = viewModel::onFormatChanged,
            )
        }

        SectionCard(title = stringResource(R.string.ks_section_key), icon = AppIcons.Key) {
            Text(
                text = stringResource(R.string.ks_field_algorithm),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(6.dp))
            ChoiceChips(
                options = KeyAlgorithm.entries,
                selected = state.algorithm,
                enabled = enabled,
                label = { it.displayName },
                onSelected = viewModel::onAlgorithmChanged,
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = state.alias,
                onValueChange = viewModel::onAliasChanged,
                label = { Text(stringResource(R.string.ks_field_alias)) },
                singleLine = true,
                enabled = enabled,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = state.validityYears,
                onValueChange = viewModel::onValidityChanged,
                label = { Text(stringResource(R.string.ks_field_validity)) },
                singleLine = true,
                enabled = enabled,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.fillMaxWidth(),
            )
        }

        SectionCard(title = stringResource(R.string.ks_section_passwords), icon = AppIcons.Lock) {
            PasswordField(
                value = state.storePassword,
                onValueChange = viewModel::onStorePasswordChanged,
                label = stringResource(R.string.ks_field_store_password),
                enabled = enabled,
            )
            Spacer(Modifier.height(12.dp))
            PasswordField(
                value = state.keyPassword,
                onValueChange = viewModel::onKeyPasswordChanged,
                label = stringResource(R.string.ks_field_key_password),
                supportingText = stringResource(R.string.ks_hint_min_password),
                enabled = enabled,
            )
        }

        SectionCard(
            title = stringResource(R.string.ks_section_certificate),
            icon = AppIcons.VerifiedUser,
        ) {
            DnField(state.commonName, viewModel::onCommonNameChanged, R.string.ks_field_cn, enabled)
            Spacer(Modifier.height(12.dp))
            DnField(state.organizationalUnit, viewModel::onOrgUnitChanged, R.string.ks_field_ou, enabled)
            Spacer(Modifier.height(12.dp))
            DnField(state.organization, viewModel::onOrganizationChanged, R.string.ks_field_o, enabled)
            Spacer(Modifier.height(12.dp))
            DnField(state.locality, viewModel::onLocalityChanged, R.string.ks_field_l, enabled)
            Spacer(Modifier.height(12.dp))
            DnField(state.state, viewModel::onStateChanged, R.string.ks_field_st, enabled)
            Spacer(Modifier.height(12.dp))
            DnField(state.country, viewModel::onCountryChanged, R.string.ks_field_c, enabled)
        }

        SectionCard(title = stringResource(R.string.ks_section_output), icon = AppIcons.Folder) {
            Text(
                text = state.outputFolder?.displayName
                    ?: stringResource(R.string.ks_placeholder_no_output),
                style = MaterialTheme.typography.bodyMedium,
                color = if (state.outputFolder != null) {
                    MaterialTheme.colorScheme.onSurface
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                },
            )
            Spacer(Modifier.height(12.dp))
            Button(
                onClick = { outputLauncher.launch(null) },
                enabled = enabled,
                modifier = Modifier.fillMaxWidth(),
            ) { Text(stringResource(R.string.action_select_output)) }
        }

        Button(
            onClick = viewModel::generate,
            enabled = state.canGenerate,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
        ) {
            if (state.isGenerating) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp,
                    color = MaterialTheme.colorScheme.onPrimary,
                )
                Spacer(Modifier.width(12.dp))
                Text(stringResource(R.string.ks_action_generating))
            } else {
                Text(stringResource(R.string.ks_action_generate))
            }
        }

        state.errorMessage?.let { message ->
            ErrorCard(message = message, onDismiss = viewModel::onErrorDismissed)
        }

        state.result?.let { result ->
            SuccessCard(fileName = result.outputFileName)
            CertificateCard(alias = result.alias, info = result.certificateInfo)
        }

        Spacer(Modifier.height(8.dp))
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun <T> ChoiceChips(
    options: List<T>,
    selected: T,
    enabled: Boolean,
    label: (T) -> String,
    onSelected: (T) -> Unit,
) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        options.forEach { option ->
            FilterChip(
                selected = option == selected,
                onClick = { onSelected(option) },
                enabled = enabled,
                label = { Text(label(option)) },
            )
        }
    }
}

@Composable
private fun DnField(
    value: String,
    onValueChange: (String) -> Unit,
    labelRes: Int,
    enabled: Boolean,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(stringResource(labelRes)) },
        singleLine = true,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun PasswordField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    enabled: Boolean,
    supportingText: String? = null,
) {
    var visible by rememberSaveable { mutableStateOf(false) }
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        supportingText = supportingText?.let { { Text(it) } },
        singleLine = true,
        enabled = enabled,
        visualTransformation = if (visible) {
            VisualTransformation.None
        } else {
            PasswordVisualTransformation()
        },
        trailingIcon = {
            IconButton(onClick = { visible = !visible }) {
                Icon(
                    imageVector = if (visible) AppIcons.VisibilityOff else AppIcons.Visibility,
                    contentDescription = null,
                )
            }
        },
        modifier = Modifier.fillMaxWidth(),
    )
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
            TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.End)) {
                Text(stringResource(R.string.action_dismiss))
            }
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
        Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = AppIcons.CheckCircle,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(28.dp),
            )
            Spacer(Modifier.width(12.dp))
            Column {
                Text(
                    text = stringResource(R.string.ks_msg_success),
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
private fun CertificateCard(alias: String, info: CertificateInfo) {
    SectionCard(
        title = stringResource(R.string.section_certificate_info),
        icon = AppIcons.VerifiedUser,
    ) {
        InfoRow(stringResource(R.string.ks_label_alias), alias)
        InfoRow(stringResource(R.string.label_subject), info.subject)
        InfoRow(stringResource(R.string.label_signature_algorithm), info.signatureAlgorithm)
        InfoRow(stringResource(R.string.label_sha256), info.sha256Fingerprint, monospace = true)
        InfoRow(stringResource(R.string.label_valid_from), info.validFrom)
        InfoRow(stringResource(R.string.label_valid_until), info.validUntil)
    }
}
