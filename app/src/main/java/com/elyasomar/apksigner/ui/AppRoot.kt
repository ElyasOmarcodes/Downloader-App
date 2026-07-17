package com.elyasomar.apksigner.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import com.elyasomar.apksigner.R
import com.elyasomar.apksigner.ui.icons.AppIcons
import com.elyasomar.apksigner.ui.keystore.KeystoreScreen
import com.elyasomar.apksigner.ui.signer.SignerScreen

private enum class AppTab(val titleRes: Int) {
    SIGN(R.string.tab_sign),
    CREATE_KEYSTORE(R.string.tab_create_keystore),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppRoot() {
    var selectedTab by rememberSaveable { mutableIntStateOf(0) }
    val tabs = AppTab.entries

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.app_name)) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    titleContentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                ),
            )
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = innerPadding.calculateTopPadding()),
        ) {
            TabRow(selectedTabIndex = selectedTab) {
                tabs.forEachIndexed { index, tab ->
                    Tab(
                        selected = selectedTab == index,
                        onClick = { selectedTab = index },
                        text = { Text(stringResource(tab.titleRes)) },
                        icon = {
                            Icon(
                                imageVector = if (tab == AppTab.SIGN) {
                                    AppIcons.Shield
                                } else {
                                    AppIcons.Key
                                },
                                contentDescription = null,
                            )
                        },
                    )
                }
            }

            val contentPadding = PaddingValues(bottom = innerPadding.calculateBottomPadding())
            Box(modifier = Modifier.fillMaxSize()) {
                when (tabs[selectedTab]) {
                    AppTab.SIGN -> SignerScreen(contentPadding = contentPadding)
                    AppTab.CREATE_KEYSTORE -> KeystoreScreen(contentPadding = contentPadding)
                }
            }
        }
    }
}
