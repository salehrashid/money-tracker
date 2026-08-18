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
import java.text.NumberFormat
import java.util.Locale

object MoneyNotificationBridge {
    const val channelName = "money_tracker/notification_listener"

    private const val logTag = "MoneyNotification"
    private const val preferencesName = "money_tracker_notification_listener"
    private const val monitoredPackagesKey = "monitored_packages"
    private const val confirmationChannelId = "money_tracker_notification_review"
    private const val maxRecentNotifications = 100
    private const val reviewIntentAction = "com.example.money_tracker.ADD_TRANSACTION_REVIEW"

    @Volatile
    private var channel: MethodChannel? = null
    @Volatile
    private var initialTransactionReviewRequest: Map<String, Any?>? = null
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

    fun getInitialTransactionReviewRequest(): Map<String, Any?>? {
        return initialTransactionReviewRequest
    }

    fun handleLaunchIntent(intent: Intent?) {
        val payload = transactionPayloadFromIntent(intent) ?: return
        initialTransactionReviewRequest = payload
        channel?.invokeMethod("transactionReviewRequested", payload)
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
        if (payload["action"] != "add_transaction" || payload["source"] != "mybca_notification") {
            return
        }
        if (!areConfirmationNotificationsAllowed(context)) {
            return
        }

        createConfirmationChannel(context)

        val transactionType = (payload["transactionType"] as? String).orEmpty()
        val amount = readDouble(payload["amount"]) ?: return
        val typeLabel = when (transactionType) {
            "income" -> "Income"
            "expense" -> "Expense"
            else -> return
        }
        val notificationId = reviewNotificationId(payload)
        val title = "New $typeLabel Detected"
        val sourceApplication = (payload["sourceApplication"] as? String)
            ?.takeIf { it.isNotBlank() }
            ?: "notification"
        val body = "$typeLabel ${formatIdr(amount)} was detected from $sourceApplication. Tap to review and add the transaction."
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.apply {
                action = reviewIntentAction
                putTransactionExtras(payload)
            }
            ?: Intent(context, MainActivity::class.java).apply {
                action = reviewIntentAction
                putTransactionExtras(payload)
            }
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, confirmationChannelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_DEFAULT)
        }

        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        notificationManager(context).notify(notificationId, notification)
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

            Notification Key:
            ${payload["notificationKey"].orEmptyText()}

            Application:
            ${payload["appName"].orEmptyText()}

            Title:
            ${payload["title"].orEmptyText().redactSensitiveNumbers()}

            Body:
            ${payload["body"].orEmptyText().redactSensitiveNumbers()}

            Sub Text:
            ${payload["subText"].orEmptyText().redactSensitiveNumbers()}

            Big Text:
            ${payload["bigText"].orEmptyText().redactSensitiveNumbers()}

            Text Lines:
            ${payload["textLines"].orEmptyText().redactSensitiveNumbers()}

            Channel ID:
            ${payload["channelId"].orEmptyText()}

            Post Time:
            ${payload["postTimeMillis"].orEmptyText()}

            Notification ID:
            ${payload["notificationId"].orEmptyText()}

            Ticker:
            ${payload["ticker"].orEmptyText().redactSensitiveNumbers()}

            Extras:
            ${payload["extras"].orEmptyText().redactSensitiveNumbers()}

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

    private fun Any?.orEmptyText(): String {
        return this?.toString().orEmpty()
    }

    private fun String.redactSensitiveNumbers(): String {
        return replace(Regex("\\d{4,}"), "[number]")
    }

    private fun Intent.putTransactionExtras(payload: Map<*, *>) {
        putExtra("action", "add_transaction")
        putExtra("source", "mybca_notification")
        putExtra("transactionType", payload["transactionType"] as? String)
        putExtra("amount", readDouble(payload["amount"]) ?: 0.0)
        putExtra("description", payload["description"] as? String)
        putExtra("detectedAtMillis", readLong(payload["detectedAtMillis"]) ?: 0L)
        putExtra("sourcePackage", payload["sourcePackage"] as? String)
        putExtra("sourceApplication", payload["sourceApplication"] as? String ?: "myBCA")
        putExtra("originalText", payload["originalText"] as? String)
    }

    private fun transactionPayloadFromIntent(intent: Intent?): Map<String, Any?>? {
        if (intent?.action != reviewIntentAction) {
            return null
        }

        val transactionType = intent.getStringExtra("transactionType") ?: return null
        val amount = intent.getDoubleExtra("amount", 0.0)
        if (amount <= 0.0) {
            return null
        }

        return mapOf(
            "action" to "add_transaction",
            "source" to "mybca_notification",
            "transactionType" to transactionType,
            "amount" to amount,
            "description" to intent.getStringExtra("description").orEmpty(),
            "detectedAtMillis" to intent.getLongExtra("detectedAtMillis", 0L),
            "sourcePackage" to intent.getStringExtra("sourcePackage").orEmpty(),
            "sourceApplication" to intent.getStringExtra("sourceApplication").orEmpty(),
            "originalText" to intent.getStringExtra("originalText").orEmpty(),
        )
    }

    private fun reviewNotificationId(payload: Map<*, *>): Int {
        val input = listOf(
            payload["sourcePackage"].orEmptyText(),
            payload["transactionType"].orEmptyText(),
            payload["amount"].orEmptyText(),
            payload["detectedAtMillis"].orEmptyText(),
            payload["description"].orEmptyText(),
        ).joinToString("|")
        return 7101 + (input.hashCode() and 0x0fffffff)
    }

    private fun readDouble(value: Any?): Double? {
        return when (value) {
            is Double -> value
            is Float -> value.toDouble()
            is Int -> value.toDouble()
            is Long -> value.toDouble()
            is String -> value.toDoubleOrNull()
            else -> null
        }
    }

    private fun readLong(value: Any?): Long? {
        return when (value) {
            is Long -> value
            is Int -> value.toLong()
            is Double -> value.toLong()
            is String -> value.toLongOrNull()
            else -> null
        }
    }

    private fun formatIdr(amount: Double): String {
        val formatter = NumberFormat.getIntegerInstance(Locale.forLanguageTag("id-ID"))
        return "Rp${formatter.format(amount.toLong())}"
    }

    private fun preferences(context: Context) = context.getSharedPreferences(
        preferencesName,
        Context.MODE_PRIVATE,
    )
}
