package com.elyasomar.apksigner.data.inspect

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.elyasomar.apksigner.domain.model.ApkInfo
import com.elyasomar.apksigner.domain.model.SigningException
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

/** Reads human-readable metadata from an APK file via the platform parser. */
@Singleton
class ApkInspector @Inject constructor(
    @ApplicationContext private val context: Context,
) {

    fun inspect(apk: File): ApkInfo {
        val packageInfo = context.packageManager
            .getPackageArchiveInfo(apk.absolutePath, 0)
            ?: throw SigningException("The selected file is not a valid APK.")

        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            packageInfo.versionCode.toLong()
        }

        // ApplicationInfo.minSdkVersion is available since API 24; this app's
        // own minSdk is 26, so it is always readable here.
        val minSdk = packageInfo.applicationInfo?.minSdkVersion ?: 0

        return ApkInfo(
            packageName = packageInfo.packageName ?: "—",
            versionName = packageInfo.versionName ?: "—",
            versionCode = versionCode,
            minSdk = minSdk,
        )
    }
}
