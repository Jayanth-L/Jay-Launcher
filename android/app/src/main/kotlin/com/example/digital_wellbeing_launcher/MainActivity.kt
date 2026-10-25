package com.example.digital_wellbeing_launcher

import android.content.Intent
import android.app.role.RoleManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import java.util.concurrent.Executors
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val HOME_ROLE_REQUEST_CODE = 7401
    }

    private val appQueryExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val channelName = "com.example.digital_wellbeing_launcher/apps"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isDefaultHomeApp" -> {
                        result.success(isDefaultHomeApp())
                    }

                    "requestHomeRole" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                val roleManager = getSystemService(RoleManager::class.java)
                                when {
                                    roleManager == null -> result.error(
                                        "HOME_ROLE_UNAVAILABLE",
                                        "Android home app selection is unavailable",
                                        null,
                                    )
                                    !roleManager.isRoleAvailable(RoleManager.ROLE_HOME) -> result.error(
                                        "HOME_ROLE_UNAVAILABLE",
                                        "Android home app selection is unavailable",
                                        null,
                                    )
                                    roleManager.isRoleHeld(RoleManager.ROLE_HOME) -> result.success(null)
                                    else -> {
                                        startActivityForResult(
                                            roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME),
                                            HOME_ROLE_REQUEST_CODE,
                                        )
                                        result.success(null)
                                    }
                                }
                            } else {
                                startActivity(Intent(Settings.ACTION_HOME_SETTINGS))
                                result.success(null)
                            }
                        } catch (error: Exception) {
                            result.error(
                                "HOME_ROLE_REQUEST_FAILED",
                                error.localizedMessage ?: "Could not open home app settings",
                                null,
                            )
                        }
                    }

                    "getInstalledApps" -> appQueryExecutor.execute {
                        try {
                            val apps = queryLaunchableApps()
                            mainHandler.post { result.success(apps) }
                        } catch (error: Exception) {
                            mainHandler.post {
                                result.error(
                                    "APP_QUERY_FAILED",
                                    error.localizedMessage ?: "Could not load installed apps",
                                    null,
                                )
                            }
                        }
                    }

                    "launchApp" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.error("INVALID_PACKAGE", "A package name is required", null)
                        } else {
                            try {
                                val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                                if (launchIntent == null) {
                                    result.error("APP_NOT_LAUNCHABLE", "This app cannot be opened", null)
                                } else {
                                    startActivity(launchIntent)
                                    result.success(null)
                                }
                            } catch (error: Exception) {
                                result.error(
                                    "APP_LAUNCH_FAILED",
                                    error.localizedMessage ?: "Could not open app",
                                    null,
                                )
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun isDefaultHomeApp(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            return roleManager?.isRoleHeld(RoleManager.ROLE_HOME) == true
        }

        val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val resolved = packageManager.resolveActivity(homeIntent, 0)
        return resolved?.activityInfo?.packageName == packageName
    }

    private fun queryLaunchableApps(): List<Map<String, Any>> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val pm = this.packageManager
        val seenPackages = mutableSetOf<String>()

        return pm.queryIntentActivities(launcherIntent, 0)
            .mapNotNull { resolveInfo ->
                val packageName = resolveInfo.activityInfo?.packageName ?: return@mapNotNull null
                if (packageName == this.packageName || !seenPackages.add(packageName)) {
                    return@mapNotNull null
                }

                buildMap<String, Any> {
                    put(
                        "label",
                        resolveInfo.loadLabel(pm).toString().ifBlank {
                            packageName
                        },
                    )
                    put("packageName", packageName)
                }
            }
    }

    override fun onDestroy() {
        appQueryExecutor.shutdown()
        super.onDestroy()
    }
}
