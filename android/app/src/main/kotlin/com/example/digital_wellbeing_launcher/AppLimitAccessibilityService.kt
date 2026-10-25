package com.example.digital_wellbeing_launcher

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.view.accessibility.AccessibilityEvent
import android.view.inputmethod.InputMethodManager
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AppLimitAccessibilityService : AccessibilityService() {
    companion object {
        const val PREFERENCES_NAME = "wellbeing_launcher_policies"
        private const val USAGE_DATE_KEY = "usage_date"
        private const val USAGE_JSON_KEY = "usage_json"
        private const val POLICY_JSON_KEY = "policies_json"
        private const val BLOCK_EVENT_KEY = "blocked_event_json"
    }

    private data class Policy(
        val packageName: String,
        val label: String,
        val dailyLimitEnabled: Boolean,
        val dailyLimitMinutes: Int,
        val usageWindowEnabled: Boolean,
        val windowStartMinute: Int,
        val windowEndMinute: Int,
    )

    private val handler = Handler(Looper.getMainLooper())
    private val preferences by lazy {
        getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
    }
    private var foregroundPackage: String? = null
    private var lastAccountedAt = 0L
    private var lastPersistedAt = 0L
    private var usageDate = ""
    private val usageSeconds = mutableMapOf<String, Long>()
    private var cachedPoliciesJson: String? = null
    private var cachedPolicies = emptyMap<String, Policy>()

    private val usageTicker = object : Runnable {
        override fun run() {
            val now = System.currentTimeMillis()
            accountUsageUntil(now)
            foregroundPackage?.let(::enforcePolicy)
            if (now - lastPersistedAt >= 5_000L) persistUsage()
            handler.postDelayed(this, 1_000L)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        refreshUsageDay()
        loadUsage()
        lastAccountedAt = System.currentTimeMillis()
        lastPersistedAt = lastAccountedAt
        handler.removeCallbacks(usageTicker)
        handler.post(usageTicker)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event ?: return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED
        ) return

        val packageName = event.packageName?.toString() ?: return
        if (isInputMethod(packageName)) return

        val now = System.currentTimeMillis()
        accountUsageUntil(now)
        lastAccountedAt = now
        if (packageName == this.packageName) persistUsage()
        foregroundPackage = if (
            packageName == this.packageName || packageName == "com.android.systemui"
        ) {
            null
        } else {
            packageName
        }
        foregroundPackage?.let(::enforcePolicy)
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        handler.removeCallbacks(usageTicker)
        accountUsageUntil(System.currentTimeMillis())
        persistUsage()
        super.onDestroy()
    }

    private fun isInputMethod(packageName: String): Boolean {
        val manager = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        return manager?.enabledInputMethodList?.any {
            it.packageName == packageName
        } == true
    }

    private fun accountUsageUntil(now: Long) {
        refreshUsageDay()
        val app = foregroundPackage
        val last = lastAccountedAt
        if (app == null || last <= 0L) {
            lastAccountedAt = now
            return
        }

        val elapsedSeconds = (((now - last).coerceAtLeast(0L)) / 1_000L)
            .coerceAtMost(2L)
        val policy = policies()[app]
        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        if (elapsedSeconds > 0 && powerManager?.isInteractive != false && policy?.dailyLimitEnabled == true) {
            usageSeconds[app] = (usageSeconds[app] ?: 0L) + elapsedSeconds
        }
        lastAccountedAt = now
    }

    private fun enforcePolicy(packageName: String) {
        if (packageName == this.packageName) return
        val policy = policies()[packageName] ?: return
        val reason = when {
            policy.usageWindowEnabled && !isWithinUsageWindow(policy) -> "outside_window"
            policy.dailyLimitEnabled &&
                (usageSeconds[packageName] ?: 0L) >= policy.dailyLimitMinutes * 60L -> "daily_limit"
            else -> null
        } ?: return

        preferences.edit().putString(
            BLOCK_EVENT_KEY,
            JSONObject()
                .put("packageName", packageName)
                .put("label", policy.label)
                .put("reason", reason)
                .toString(),
        ).apply()
        persistUsage()
        foregroundPackage = null
        lastAccountedAt = System.currentTimeMillis()
        performGlobalAction(GLOBAL_ACTION_HOME)
    }

    private fun isWithinUsageWindow(policy: Policy): Boolean {
        val calendar = java.util.Calendar.getInstance()
        val currentMinute = calendar.get(java.util.Calendar.HOUR_OF_DAY) * 60 +
            calendar.get(java.util.Calendar.MINUTE)
        val start = policy.windowStartMinute.coerceIn(0, 1439)
        val end = policy.windowEndMinute.coerceIn(0, 1439)
        if (start == end) return true
        return if (start < end) {
            currentMinute >= start && currentMinute < end
        } else {
            currentMinute >= start || currentMinute < end
        }
    }

    private fun policies(): Map<String, Policy> {
        val encoded = preferences.getString(POLICY_JSON_KEY, "[]") ?: "[]"
        if (encoded == cachedPoliciesJson) return cachedPolicies

        val loaded = mutableMapOf<String, Policy>()
        try {
            val array = JSONArray(encoded)
            for (index in 0 until array.length()) {
                val item = array.optJSONObject(index) ?: continue
                val packageName = item.optString("packageName")
                if (packageName.isBlank()) continue
                val policy = Policy(
                    packageName = packageName,
                    label = item.optString("label", packageName),
                    dailyLimitEnabled = item.optBoolean("dailyLimitEnabled", false),
                    dailyLimitMinutes = item.optInt("dailyLimitMinutes", 30),
                    usageWindowEnabled = item.optBoolean("usageWindowEnabled", false),
                    windowStartMinute = item.optInt("windowStartMinute", 540),
                    windowEndMinute = item.optInt("windowEndMinute", 1080),
                )
                if (policy.dailyLimitEnabled || policy.usageWindowEnabled) {
                    loaded[packageName] = policy
                }
            }
        } catch (_: Exception) {
            // Invalid preferences disable enforcement until valid policies are saved.
        }
        usageSeconds.keys.retainAll(loaded.filterValues { it.dailyLimitEnabled }.keys)
        cachedPoliciesJson = encoded
        cachedPolicies = loaded
        return loaded
    }

    private fun refreshUsageDay() {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        if (today == usageDate) return
        usageDate = today
        usageSeconds.clear()
        preferences.edit()
            .putString(USAGE_DATE_KEY, today)
            .putString(USAGE_JSON_KEY, "{}")
            .apply()
    }

    private fun loadUsage() {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        if (preferences.getString(USAGE_DATE_KEY, null) != today) {
            usageDate = today
            usageSeconds.clear()
            preferences.edit()
                .putString(USAGE_DATE_KEY, today)
                .putString(USAGE_JSON_KEY, "{}")
                .apply()
            return
        }
        usageDate = today
        usageSeconds.clear()
        try {
            val encoded = preferences.getString(USAGE_JSON_KEY, "{}") ?: "{}"
            val json = JSONObject(encoded)
            val keys = json.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                usageSeconds[key] = json.optLong(key, 0L)
            }
        } catch (_: Exception) {
            usageSeconds.clear()
        }
    }

    private fun persistUsage() {
        refreshUsageDay()
        val json = JSONObject()
        usageSeconds.forEach { (packageName, seconds) -> json.put(packageName, seconds) }
        preferences.edit()
            .putString(USAGE_DATE_KEY, usageDate)
            .putString(USAGE_JSON_KEY, json.toString())
            .apply()
        lastPersistedAt = System.currentTimeMillis()
    }
}
