package com.example.digital_wellbeing_launcher

import android.content.Intent
import android.content.ComponentName
import android.app.AppOpsManager
import android.app.role.RoleManager
import android.app.usage.UsageStatsManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.os.Process
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
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
    private val policyPrefs by lazy {
        getSharedPreferences(AppLimitAccessibilityService.PREFERENCES_NAME, MODE_PRIVATE)
    }

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

                    "getAppPolicies" -> {
                        result.success(policyPrefs.getString("policies_json", "[]"))
                    }

                    "getThemeSettings" -> {
                        result.success(
                            mapOf(
                                "dark" to policyPrefs.getBoolean("theme_dark", false),
                                "accentIndex" to policyPrefs.getInt("theme_accent_index", 0),
                            ),
                        )
                    }

                    "saveThemeSettings" -> {
                        val dark = call.argument<Boolean>("dark")
                        val accentIndex = call.argument<Int>("accentIndex")
                        if (dark == null || accentIndex == null) {
                            result.error(
                                "INVALID_THEME_SETTINGS",
                                "Theme settings are incomplete",
                                null,
                            )
                        } else {
                            policyPrefs.edit()
                                .putBoolean("theme_dark", dark)
                                .putInt("theme_accent_index", accentIndex.coerceIn(0, 4))
                                .apply()
                            result.success(null)
                        }
                    }

                    "getFavoriteApps" -> {
                        val packages = policyPrefs.getString("favorite_packages", "[]") ?: "[]"
                        try {
                            val array = org.json.JSONArray(packages)
                            result.success((0 until array.length()).map { array.optString(it) })
                        } catch (_: Exception) {
                            result.success(emptyList<String>())
                        }
                    }

                    "saveFavoriteApps" -> {
                        val packages = call.argument<List<String>>("packages")
                        if (packages == null) {
                            result.error("INVALID_FAVORITES", "Favorite app data is missing", null)
                        } else {
                            policyPrefs.edit()
                                .putString("favorite_packages", org.json.JSONArray(packages).toString())
                                .apply()
                            result.success(null)
                        }
                    }

                    "saveAppPolicies" -> {
                        val policies = call.argument<String>("policies")
                        if (policies == null) {
                            result.error("INVALID_POLICIES", "Policy data is missing", null)
                        } else {
                            val activeLimitPackages = mutableSetOf<String>()
                            try {
                                val items = org.json.JSONArray(policies)
                                for (index in 0 until items.length()) {
                                    val item = items.optJSONObject(index) ?: continue
                                    if (item.optBoolean("dailyLimitEnabled", false)) {
                                        activeLimitPackages.add(item.optString("packageName"))
                                    }
                                }
                            } catch (error: Exception) {
                                result.error("INVALID_POLICIES", "Policy data is invalid", null)
                                return@setMethodCallHandler
                            }
                            val today = currentDateKey()
                            val oldUsage = if (
                                policyPrefs.getString("usage_date", null) == today
                            ) {
                                org.json.JSONObject(
                                    policyPrefs.getString("usage_json", "{}") ?: "{}",
                                )
                            } else {
                                org.json.JSONObject()
                            }
                            val filteredUsage = org.json.JSONObject()
                            val usageKeys = oldUsage.keys()
                            while (usageKeys.hasNext()) {
                                val key = usageKeys.next()
                                if (key in activeLimitPackages) {
                                    filteredUsage.put(key, oldUsage.optLong(key, 0L))
                                }
                            }
                            policyPrefs.edit().putString("policies_json", policies).apply()
                            policyPrefs.edit()
                                .putString("usage_date", today)
                                .putString("usage_json", filteredUsage.toString())
                                .apply()
                            result.success(null)
                        }
                    }

                    "getDailyUsage" -> {
                        val today = currentDateKey()
                        if (policyPrefs.getString("usage_date", null) != today) {
                            policyPrefs.edit()
                                .putString("usage_date", today)
                                .putString("usage_json", "{}")
                                .apply()
                        }
                        val usageJson = org.json.JSONObject(
                            policyPrefs.getString("usage_json", "{}") ?: "{}",
                        )
                        val usage = mutableMapOf<String, Long>()
                        val keys = usageJson.keys()
                        while (keys.hasNext()) {
                            val key = keys.next()
                            usage[key] = usageJson.optLong(key, 0L)
                        }
                        result.success(usage)
                    }

                    "hasUsageAccess" -> {
                        result.success(hasUsageAccess())
                    }

                    "openUsageAccessSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                            result.success(null)
                        } catch (error: Exception) {
                            result.error(
                                "USAGE_SETTINGS_UNAVAILABLE",
                                error.localizedMessage ?: "Could not open Usage Access settings",
                                null,
                            )
                        }
                    }

                    "getAppUsageStats" -> {
                        appQueryExecutor.execute {
                            try {
                                if (!hasUsageAccess()) {
                                    mainHandler.post {
                                        result.error(
                                            "USAGE_ACCESS_REQUIRED",
                                            "Allow Usage Access in Android settings to view app usage.",
                                            null,
                                        )
                                    }
                                    return@execute
                                }
                                val usageManager = getSystemService(USAGE_STATS_SERVICE)
                                    as UsageStatsManager
                                val now = System.currentTimeMillis()
                                val calendar = java.util.Calendar.getInstance().apply {
                                    timeInMillis = now
                                    set(java.util.Calendar.HOUR_OF_DAY, 0)
                                    set(java.util.Calendar.MINUTE, 0)
                                    set(java.util.Calendar.SECOND, 0)
                                    set(java.util.Calendar.MILLISECOND, 0)
                                }
                                val dailyUsage = mutableMapOf<String, Long>()
                                usageManager.queryUsageStats(
                                    UsageStatsManager.INTERVAL_DAILY,
                                    calendar.timeInMillis,
                                    now,
                                ).orEmpty().forEach { stat ->
                                    if (stat.totalTimeInForeground > 0L) {
                                        dailyUsage[stat.packageName] =
                                            (dailyUsage[stat.packageName] ?: 0L) +
                                                stat.totalTimeInForeground / 1000L
                                    }
                                }
                                mainHandler.post { result.success(dailyUsage) }
                            } catch (error: Exception) {
                                mainHandler.post {
                                    result.error(
                                        "USAGE_QUERY_FAILED",
                                        error.localizedMessage ?: "Could not read app usage",
                                        null,
                                    )
                                }
                            }
                        }
                    }

                    "isEnforcementEnabled" -> {
                        val accessibilityEnabled = Settings.Secure.getInt(
                            contentResolver,
                            Settings.Secure.ACCESSIBILITY_ENABLED,
                            0,
                        ) == 1
                        val enabledServices = Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
                        ).orEmpty()
                        val serviceName = ComponentName(
                            this,
                            AppLimitAccessibilityService::class.java,
                        ).flattenToString()
                        result.success(
                            accessibilityEnabled && enabledServices.split(':').any {
                                it.equals(serviceName, ignoreCase = true)
                            },
                        )
                    }

                    "openAccessibilitySettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                            result.success(null)
                        } catch (error: Exception) {
                            result.error(
                                "ACCESSIBILITY_SETTINGS_UNAVAILABLE",
                                error.localizedMessage ?: "Could not open Accessibility settings",
                                null,
                            )
                        }
                    }

                    "consumeEnforcementEvent" -> {
                        val encoded = policyPrefs.getString("blocked_event_json", null)
                        if (encoded == null) {
                            result.success(null)
                        } else {
                            policyPrefs.edit().remove("blocked_event_json").apply()
                            val event = org.json.JSONObject(encoded)
                            result.success(
                                mapOf(
                                    "label" to event.optString("label", "This app"),
                                    "reason" to event.optString("reason", "limit"),
                                ),
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

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun currentDateKey(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

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
