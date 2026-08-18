package com.example.money_tracker

import android.app.Notification
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.content.pm.PackageManager
import android.service.notification.StatusBarNotification

class MoneyNotificationListenerService : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        MoneyNotificationBridge.logLifecycle("Notification Listener Connected")
    }

    override fun onListenerDisconnected() {
        MoneyNotificationBridge.logLifecycle("Notification Listener Disconnected")
        super.onListenerDisconnected()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) {
            MoneyNotificationBridge.logLifecycle("Notification Posted with null payload")
            return
        }

        val payload = buildPayload(sbn)
        MoneyNotificationBridge.logNotification("Notification Posted", payload)

        NativeNotificationPipeline.processNotification(this, payload)

        MoneyNotificationBridge.dispatchNotification(payload)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        if (sbn == null) {
            MoneyNotificationBridge.logLifecycle("Notification Removed with null payload")
            return
        }

        val payload = buildPayload(sbn)
        MoneyNotificationBridge.logNotification("Notification Removed", payload)
    }

    private fun buildPayload(sbn: StatusBarNotification): Map<String, Any?> {
        val notification = sbn.notification
        val packageName = sbn.packageName.orEmpty()
        val extras = notification.extras

        return mapOf(
            "packageName" to packageName,
            "appName" to appNameFor(packageName),
            "notificationKey" to sbn.key.orEmpty(),
            "title" to readNotificationText(notification, Notification.EXTRA_TITLE),
            "body" to readNotificationText(notification, Notification.EXTRA_TEXT),
            "subText" to readNotificationText(notification, Notification.EXTRA_SUB_TEXT),
            "bigText" to readNotificationText(notification, Notification.EXTRA_BIG_TEXT),
            "textLines" to readNotificationTextLines(notification),
            "channelId" to readChannelId(notification),
            "postTimeMillis" to sbn.postTime,
            "receivedAtMillis" to System.currentTimeMillis(),
            "notificationId" to sbn.id,
            "tag" to sbn.tag.orEmpty(),
            "ticker" to notification.tickerText?.toString()?.trim().orEmpty(),
            "extras" to bundleToSafeMap(extras),
            "result" to "Received Successfully",
        )
    }

    private fun readNotificationText(notification: Notification, key: String): String {
        val value = notification.extras?.getCharSequence(key)
        return value?.toString()?.trim().orEmpty()
    }

    private fun readNotificationTextLines(notification: Notification): List<String> {
        val lines = notification.extras?.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?: return emptyList()
        return lines
            .mapNotNull { it?.toString()?.trim() }
            .filter { it.isNotEmpty() }
    }

    private fun readChannelId(notification: Notification): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notification.channelId.orEmpty()
        } else {
            ""
        }
    }

    private fun bundleToSafeMap(bundle: Bundle?): Map<String, String> {
        if (bundle == null) {
            return emptyMap()
        }

        return bundle.keySet().associateWith { key -> readBundleValue(bundle, key) }
    }

    @Suppress("DEPRECATION")
    private fun readBundleValue(bundle: Bundle, key: String): String {
        return bundle.get(key)?.toString().orEmpty()
    }

    private fun appNameFor(packageName: String): String {
        if (packageName.isBlank()) {
            return ""
        }

        return try {
            val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(applicationInfo).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            packageName
        }
    }
}
