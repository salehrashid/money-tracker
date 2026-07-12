package com.example.money_tracker

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.MethodChannel

object MoneyNotificationBridge {
    const val channelName = "money_tracker/notification_listener"

    private const val logTag = "MoneyNotification"
    private const val preferencesName = "money_tracker_notification_listener"
    private const val monitoredPackagesKey = "monitored_packages"
    private const val confirmationChannelId = "money_tracker_notification_review"
    private const val confirmationNotificationId = 7101
    private const val maxRecentNotifications = 100

    @Volatile
    private var channel: MethodChannel? = null
    private val recentNotifications = mutableListOf<Map<String, Any?>>()

    fun attachChannel(methodChannel: MethodChannel) {
        channel = methodChannel
    }

    fun detachChannel() {
        channel = null
    }

    fun dispatchNotification(payload: Map<String, Any?>) {
        rememberNotification(payload)
        channel?.invokeMethod("notificationPosted", payload)
    }

    fun recentNotifications(): List<Map<String, Any?>> {
        return synchronized(recentNotifications) {
            recentNotifications.toList()
        }
    }

    fun isNotificationListenerEnabled(context: Context): Boolean {
        val enabledListeners = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false

        val componentName = ComponentName(
            context,
            MoneyNotificationListenerService::class.java,
        )
        return enabledListeners.split(':').any { listener ->
            ComponentName.unflattenFromString(listener) == componentName
        }
    }

    fun areConfirmationNotificationsAllowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
            if (!granted) {
                return false
            }
        }

        val notificationManager = notificationManager(context)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            notificationManager.areNotificationsEnabled()
        } else {
            true
        }
    }

    fun getMonitoredPackages(context: Context): Set<String> {
        return preferences(context).getStringSet(monitoredPackagesKey, emptySet()).orEmpty()
    }

    fun setMonitoredPackages(context: Context, packageNames: List<String>) {
        val normalized = packageNames
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .toSet()

        preferences(context)
            .edit()
            .putStringSet(monitoredPackagesKey, normalized)
            .apply()
    }

    fun isPackageMonitored(context: Context, packageName: String): Boolean {
        val monitoredPackages = getMonitoredPackages(context)
        if (monitoredPackages.isEmpty() && isDebuggable(context)) {
            return true
        }
        return monitoredPackages.contains(packageName)
    }

    fun showConfirmationNotification(context: Context, payload: Map<*, *>) {
        if (payload["filterAccepted"] != true) {
            return
        }
        if (!areConfirmationNotificationsAllowed(context)) {
            return
        }

        createConfirmationChannel(context)

        val title = payload["title"] as? String ?: "Notification captured"
        val body = bodyFromPayload(payload)
        val appName = payload["appName"] as? String ?: "Money Tracker"
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            confirmationNotificationId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, confirmationChannelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setContentTitle("Review captured transaction")
            .setContentText("$appName: ${title.ifBlank { body }}")
            .setStyle(Notification.BigTextStyle().bigText(body.ifBlank { title }))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(Notification.PRIORITY_DEFAULT)
            .build()

        notificationManager(context).notify(confirmationNotificationId, notification)
    }

    fun logLifecycle(message: String) {
        Log.d(logTag, message)
    }

    fun logNotification(event: String, payload: Map<String, Any?>) {
        Log.d(
            logTag,
            """
            [Notification]
            Event:
            $event

            Package:
            ${payload["packageName"].orEmptyText()}

            Application:
            ${payload["appName"].orEmptyText()}

            Title:
            ${payload["title"].orEmptyText()}

            Body:
            ${payload["body"].orEmptyText()}

            Sub Text:
            ${payload["subText"].orEmptyText()}

            Big Text:
            ${payload["bigText"].orEmptyText()}

            Channel ID:
            ${payload["channelId"].orEmptyText()}

            Post Time:
            ${payload["postTimeMillis"].orEmptyText()}

            Notification ID:
            ${payload["notificationId"].orEmptyText()}

            Ticker:
            ${payload["ticker"].orEmptyText()}

            Extras:
            ${payload["extras"].orEmptyText()}

            Result:
            ${payload["result"].orEmptyText()}

            ------------------------
            """.trimIndent(),
        )
    }

    private fun createConfirmationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            confirmationChannelId,
            "Transaction review",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Confirms captured financial notifications for review."
        }
        val notificationManager = notificationManager(context)
        notificationManager.createNotificationChannel(channel)
    }

    private fun notificationManager(context: Context): NotificationManager {
        return context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    }

    private fun isDebuggable(context: Context): Boolean {
        return context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
    }

    private fun rememberNotification(payload: Map<String, Any?>) {
        synchronized(recentNotifications) {
            recentNotifications.add(payload)
            while (recentNotifications.size > maxRecentNotifications) {
                recentNotifications.removeAt(0)
            }
        }
    }

    private fun bodyFromPayload(payload: Map<*, *>): String {
        val body = payload["body"] as? String ?: ""
        if (body.isNotBlank()) {
            return body
        }

        val bigText = payload["bigText"] as? String ?: ""
        if (bigText.isNotBlank()) {
            return bigText
        }

        return payload["subText"] as? String ?: "Open Money Tracker to review."
    }

    private fun Any?.orEmptyText(): String {
        return this?.toString().orEmpty()
    }

    private fun preferences(context: Context) = context.getSharedPreferences(
        preferencesName,
        Context.MODE_PRIVATE,
    )
}
