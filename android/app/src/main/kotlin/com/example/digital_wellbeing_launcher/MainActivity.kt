package com.example.digital_wellbeing_launcher

import android.content.Intent
import android.content.ComponentName
import android.net.Uri
import android.Manifest
import android.content.pm.PackageManager
import android.app.ActivityOptions
import android.app.AppOpsManager
import android.app.role.RoleManager
import android.app.usage.UsageStatsManager
import android.app.usage.UsageEvents
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.os.Process
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.location.Geocoder
import android.os.Bundle
import java.net.HttpURLConnection
import java.net.URL
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
        private const val WEATHER_LOCATION_REQUEST_CODE = 7402
    }

    private val appQueryExecutor = Executors.newSingleThreadExecutor()
    private val weatherExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingWeatherResult: MethodChannel.Result? = null
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

                    "getCurrentWeather" -> requestCurrentWeather(result)

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
                        val savedMode = if (policyPrefs.contains("theme_mode")) {
                            policyPrefs.getInt("theme_mode", 0)
                        } else if (policyPrefs.getBoolean("theme_dark", false)) {
                            2
                        } else {
                            0
                        }
                        result.success(
                            mapOf(
                                "mode" to savedMode,
                                "dark" to (savedMode != 0),
                                "accentIndex" to policyPrefs.getInt("theme_accent_index", 0),
                            ),
                        )
                    }

                    "getUserName" -> {
                        result.success(policyPrefs.getString("user_name", null))
                    }

                    "saveUserName" -> {
                        val name = call.argument<String>("name")?.trim()
                        if (name.isNullOrBlank()) {
                            result.error("INVALID_USER_NAME", "A name is required", null)
                        } else {
                            policyPrefs.edit().putString("user_name", name).apply()
                            result.success(null)
                        }
                    }

                    "saveThemeSettings" -> {
                        val mode = call.argument<Int>("mode")
                        val accentIndex = call.argument<Int>("accentIndex")
                        if (mode == null || accentIndex == null) {
                            result.error(
                                "INVALID_THEME_SETTINGS",
                                "Theme settings are incomplete",
                                null,
                            )
                        } else {
                            policyPrefs.edit()
                                .putInt("theme_mode", mode.coerceIn(0, 2))
                                .putBoolean("theme_dark", mode != 0)
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
                                val now = System.currentTimeMillis()
                                val calendar = java.util.Calendar.getInstance().apply {
                                    timeInMillis = now
                                    set(java.util.Calendar.HOUR_OF_DAY, 0)
                                    set(java.util.Calendar.MINUTE, 0)
                                    set(java.util.Calendar.SECOND, 0)
                                    set(java.util.Calendar.MILLISECOND, 0)
                                }
                                val dailyUsage = getScreenTimeWithFallback(calendar.timeInMillis, now)
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

                    "getWeeklyUsageStats" -> {
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
                                val now = System.currentTimeMillis()
                                val todayCalendar = java.util.Calendar.getInstance().apply {
                                    timeInMillis = now
                                    set(java.util.Calendar.HOUR_OF_DAY, 0)
                                    set(java.util.Calendar.MINUTE, 0)
                                    set(java.util.Calendar.SECOND, 0)
                                    set(java.util.Calendar.MILLISECOND, 0)
                                }
                                val todayMidnight = todayCalendar.timeInMillis
                                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                                val weeklyList = mutableListOf<Map<String, Any>>()

                                for (offset in 13 downTo 0) {
                                    val dayCal = java.util.Calendar.getInstance().apply {
                                        timeInMillis = todayMidnight
                                        add(java.util.Calendar.DAY_OF_YEAR, -offset)
                                    }
                                    val startTime = dayCal.timeInMillis
                                    val endTime = if (offset == 0) now else startTime + (24 * 60 * 60 * 1000L)

                                    val dayUsage = getScreenTimeWithFallback(startTime, endTime)

                                    weeklyList.add(
                                        mapOf(
                                            "dateKey" to dateFormat.format(dayCal.time),
                                            "timestamp" to startTime,
                                            "isToday" to (offset == 0),
                                            "usage" to dayUsage,
                                        ),
                                    )
                                }
                                mainHandler.post { result.success(weeklyList) }
                            } catch (error: Exception) {
                                mainHandler.post {
                                    result.error(
                                        "USAGE_QUERY_FAILED",
                                        error.localizedMessage ?: "Could not read weekly app usage",
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
                                    val launchOptions = ActivityOptions.makeCustomAnimation(
                                        this,
                                        R.anim.app_enter_from_bottom,
                                        R.anim.app_exit_to_bottom,
                                    )
                                    startActivity(launchIntent, launchOptions.toBundle())
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

                    "openAppInfo" -> openPackageSettings(call, result, uninstall = false)

                    "uninstallApp" -> openPackageSettings(call, result, uninstall = true)

                    else -> result.notImplemented()
                }
            }
    }

    private fun requestCurrentWeather(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            pendingWeatherResult = result
            requestPermissions(
                arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION),
                WEATHER_LOCATION_REQUEST_CODE,
            )
            return
        }
        findLocationAndFetchWeather(result)
    }

    private fun openPackageSettings(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
        uninstall: Boolean,
    ) {
        val packageName = call.argument<String>("packageName")
        if (packageName.isNullOrBlank()) {
            result.error("INVALID_PACKAGE", "A package name is required", null)
            return
        }

        try {
            val packageUri = Uri.parse("package:$packageName")
            val intent = if (uninstall) {
                Intent(Intent.ACTION_DELETE, packageUri)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).setData(packageUri)
            }
            startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error(
                if (uninstall) "UNINSTALL_UNAVAILABLE" else "APP_INFO_UNAVAILABLE",
                error.localizedMessage ?: "Could not open app settings",
                null,
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != WEATHER_LOCATION_REQUEST_CODE) return

        val result = pendingWeatherResult ?: return
        pendingWeatherResult = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            findLocationAndFetchWeather(result)
        } else {
            result.success(null)
        }
    }

    @Suppress("MissingPermission", "DEPRECATION")
    private fun findLocationAndFetchWeather(result: MethodChannel.Result) {
        val locationManager = getSystemService(LOCATION_SERVICE) as? LocationManager
        if (locationManager == null) {
            result.success(null)
            return
        }

        val provider = when {
            locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ->
                LocationManager.NETWORK_PROVIDER
            locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ->
                LocationManager.GPS_PROVIDER
            else -> {
                result.success(null)
                return
            }
        }
        var completed = false
        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                if (completed) return
                completed = true
                locationManager.removeUpdates(this)
                weatherExecutor.execute {
                    val weather = try {
                        fetchCurrentWeather(location)
                    } catch (_: Exception) {
                        null
                    }
                    mainHandler.post { result.success(weather) }
                }
            }

            override fun onProviderDisabled(provider: String) {
                if (!completed) {
                    completed = true
                    locationManager.removeUpdates(this)
                    result.success(null)
                }
            }
        }

        try {
            locationManager.requestSingleUpdate(provider, listener, mainHandler.looper)
            mainHandler.postDelayed({
                if (!completed) {
                    completed = true
                    locationManager.removeUpdates(listener)
                    result.success(null)
                }
            }, 15_000L)
        } catch (_: Exception) {
            completed = true
            result.success(null)
        }
    }

    private fun fetchCurrentWeather(location: Location): Map<String, Any>? {
        val endpoint = URL(
            "https://api.open-meteo.com/v1/forecast" +
                "?latitude=${location.latitude}&longitude=${location.longitude}" +
                "&current=temperature_2m&timezone=auto",
        )
        val connection = endpoint.openConnection() as HttpURLConnection
        return try {
            connection.connectTimeout = 8_000
            connection.readTimeout = 8_000
            connection.requestMethod = "GET"
            val payload = connection.inputStream.bufferedReader().use { it.readText() }
            val temperature = org.json.JSONObject(payload)
                .getJSONObject("current")
                .getDouble("temperature_2m")
            val place = try {
                @Suppress("DEPRECATION")
                val address = Geocoder(this, Locale.getDefault())
                    .getFromLocation(location.latitude, location.longitude, 1)
                    ?.firstOrNull()
                address?.locality
                    ?: address?.subAdminArea
                    ?: address?.adminArea
                    ?: address?.countryName
            } catch (_: Exception) {
                null
            }
            mapOf(
                "temperatureC" to temperature,
                "locationName" to (place ?: "your location"),
            )
        } finally {
            connection.disconnect()
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

    private fun calculateScreenTime(startTime: Long, endTime: Long): Map<String, Long>? {
        if (startTime >= endTime) return emptyMap()

        val usageManager = getSystemService(USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return null

        // Look back up to 3 hours before startTime to catch apps already running across the window boundary
        val queryStart = maxOf(0L, startTime - (3 * 3600 * 1000L))
        val usageEvents = try {
            usageManager.queryEvents(queryStart, endTime)
        } catch (_: Exception) {
            null
        } ?: return null

        if (!usageEvents.hasNextEvent()) {
            return null
        }

        val appTimeMillis = mutableMapOf<String, Long>()
        var currentPkg: String? = null
        var currentSessionStart = 0L
        val activeActivities = mutableSetOf<String>()

        fun closeSession(sessionEnd: Long) {
            val pkg = currentPkg ?: return
            val sessionStart = currentSessionStart
            currentPkg = null
            currentSessionStart = 0L
            activeActivities.clear()

            if (sessionEnd > sessionStart) {
                val clampedStart = maxOf(sessionStart, startTime)
                val clampedEnd = minOf(sessionEnd, endTime)
                if (clampedEnd > clampedStart) {
                    val duration = clampedEnd - clampedStart
                    appTimeMillis[pkg] = (appTimeMillis[pkg] ?: 0L) + duration
                }
            }
        }

        val event = UsageEvents.Event()

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            val pkg = event.packageName ?: continue
            val time = event.timeStamp

            if (time > endTime) break

            when (event.eventType) {
                1 -> { // UsageEvents.Event.ACTIVITY_RESUMED or MOVE_TO_FOREGROUND
                    if (pkg == packageName || pkg == "com.android.systemui") {
                        // User returned to launcher or system UI: end any active foreground app session
                        closeSession(time)
                    } else {
                        val activityKey = "$pkg/${event.className ?: "default"}"
                        if (currentPkg != pkg) {
                            // Switched from a different app to this app
                            closeSession(time)
                            currentPkg = pkg
                            currentSessionStart = time
                            activeActivities.add(activityKey)
                        } else {
                            // Another activity within the same app resumed
                            activeActivities.add(activityKey)
                        }
                    }
                }

                2, 23 -> { // UsageEvents.Event.ACTIVITY_PAUSED or ACTIVITY_STOPPED
                    if (currentPkg == pkg) {
                        val activityKey = "$pkg/${event.className ?: "default"}"
                        val removed = activeActivities.remove(activityKey)
                        if (!removed && activeActivities.isNotEmpty()) {
                            val first = activeActivities.first()
                            activeActivities.remove(first)
                        }
                        if (activeActivities.isEmpty()) {
                            closeSession(time)
                        }
                    }
                }

                16, 18 -> { // UsageEvents.Event.SCREEN_NON_INTERACTIVE or KEYGUARD_SHOWN
                    closeSession(time)
                }
            }
        }

        // Account for any app still active in the foreground at endTime
        if (currentPkg != null) {
            closeSession(endTime)
        }

        val maxWindowSeconds = ((endTime - startTime) / 1000L).coerceAtLeast(0L)
        return appTimeMillis.mapValues { (_, millis) ->
            (millis / 1000L).coerceIn(0L, maxWindowSeconds)
        }.filterValues { it > 0L }
    }

    private fun getScreenTimeWithFallback(startTime: Long, endTime: Long): Map<String, Long> {
        if (startTime >= endTime) return emptyMap()

        val eventBasedUsage = calculateScreenTime(startTime, endTime)
        if (eventBasedUsage != null) {
            return eventBasedUsage
        }

        val usageManager = getSystemService(USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyMap()
        val aggregated = try {
            usageManager.queryAndAggregateUsageStats(startTime, endTime)
        } catch (_: Exception) {
            null
        } ?: return emptyMap()

        val maxWindowSeconds = ((endTime - startTime) / 1000L).coerceAtLeast(0L)
        val fallbackMap = mutableMapOf<String, Long>()
        aggregated.forEach { (pkg, stat) ->
            if (pkg != packageName && pkg != "com.android.systemui" && stat.totalTimeInForeground > 0L) {
                val seconds = (stat.totalTimeInForeground / 1000L).coerceIn(0L, maxWindowSeconds)
                if (seconds > 0L) {
                    fallbackMap[pkg] = seconds
                }
            }
        }
        return fallbackMap
    }

    override fun onDestroy() {
        appQueryExecutor.shutdown()
        weatherExecutor.shutdown()
        super.onDestroy()
    }
}
