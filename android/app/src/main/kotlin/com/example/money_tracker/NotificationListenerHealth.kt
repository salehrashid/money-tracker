package com.example.money_tracker

import android.content.ComponentName
import android.content.Context
import android.os.SystemClock
import android.service.notification.NotificationListenerService
import android.util.Log

/** Connection state is deliberately process local; saved values are diagnostics only. */
object NotificationListenerHealth {
    private const val tag = "MoneyNotificationListener"
    private const val preferencesName = "notification_listener_health"
    private const val rebindIntervalMs = 2_000L
    private val processStartedAt = System.currentTimeMillis()

    @Volatile private var connected = false
    @Volatile private var lastRebindElapsed = 0L

    fun created(context: Context) {
        Log.i(tag, "SERVICE_CREATED")
        save(context, "lastServiceCreatedAt")
    }

    fun bound() = Log.i(tag, "SERVICE_BIND")

    fun connected(context: Context) {
        connected = true
        lastRebindElapsed = 0L
        prefs(context).edit().putInt("rebindAttempts", 0).apply()
        save(context, "lastConnectedAt")
        Log.i(tag, "LISTENER_CONNECTED")
    }

    fun disconnected(context: Context) {
        connected = false
        save(context, "lastDisconnectedAt")
        Log.w(tag, "LISTENER_DISCONNECTED")
    }

    fun destroyed() {
        connected = false
        Log.w(tag, "SERVICE_DESTROYED")
    }

    fun notificationReceived(context: Context, packageName: String) {
        save(context, "lastNotificationAt")
        Log.d(tag, "NOTIFICATION_RECEIVED package=$packageName")
    }

    @Synchronized
    fun requestRebind(context: Context): Boolean {
        if (!MoneyNotificationBridge.isNotificationListenerEnabled(context) || connected) return false
        val now = SystemClock.elapsedRealtime()
        if (lastRebindElapsed != 0L && now - lastRebindElapsed < rebindIntervalMs) return false
        lastRebindElapsed = now
        return try {
            NotificationListenerService.requestRebind(
                ComponentName(context, MoneyNotificationListenerService::class.java),
            )
            save(context, "lastRebindRequestedAt")
            val prefs = prefs(context)
            prefs.edit().putInt("rebindAttempts", prefs.getInt("rebindAttempts", 0) + 1).apply()
            Log.i(tag, "REBIND_REQUESTED")
            true
        } catch (error: RuntimeException) {
            Log.w(tag, "REBIND_REQUEST_FAILED", error)
            false
        }
    }

    fun snapshot(context: Context): Map<String, Any?> {
        val prefs = prefs(context)
        return mapOf(
            "notificationAccessGranted" to MoneyNotificationBridge.isNotificationListenerEnabled(context),
            "listenerConnected" to connected,
            "lastServiceCreatedAt" to timestamp(prefs, "lastServiceCreatedAt"),
            "lastConnectedAt" to timestamp(prefs, "lastConnectedAt"),
            "lastDisconnectedAt" to timestamp(prefs, "lastDisconnectedAt"),
            "lastNotificationAt" to timestamp(prefs, "lastNotificationAt"),
            "lastRebindRequestedAt" to timestamp(prefs, "lastRebindRequestedAt"),
            "rebindAttempts" to prefs.getInt("rebindAttempts", 0),
            "processStartedAt" to processStartedAt,
        )
    }

    private fun save(context: Context, key: String) {
        prefs(context).edit().putLong(key, System.currentTimeMillis()).apply()
    }

    private fun timestamp(prefs: android.content.SharedPreferences, key: String): Long? =
        if (prefs.contains(key)) prefs.getLong(key, 0L) else null

    private fun prefs(context: Context) =
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
}
