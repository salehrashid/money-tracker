package com.example.money_tracker

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MoneyNotificationBridge.handleLaunchIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        MoneyNotificationBridge.handleLaunchIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MoneyNotificationBridge.channelName,
        )
        MoneyNotificationBridge.attachChannel(channel)
        channel.setMethodCallHandler(::handleNotificationMethodCall)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        MoneyNotificationBridge.detachChannel()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun handleNotificationMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isNotificationListenerEnabled" -> {
                result.success(MoneyNotificationBridge.isNotificationListenerEnabled(this))
            }
            "openNotificationListenerSettings" -> {
                startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                result.success(null)
            }
            "areConfirmationNotificationsAllowed" -> {
                result.success(MoneyNotificationBridge.areConfirmationNotificationsAllowed(this))
            }
            "requestConfirmationNotificationPermission" -> {
                requestConfirmationNotificationPermission()
                result.success(null)
            }
            "getMonitoredPackages" -> {
                result.success(MoneyNotificationBridge.getMonitoredPackages(this).toList())
            }
            "getRecentNotifications" -> {
                result.success(MoneyNotificationBridge.recentNotifications())
            }
            "getInitialTransactionReviewRequest" -> {
                result.success(MoneyNotificationBridge.getInitialTransactionReviewRequest())
            }
            "setMonitoredPackages" -> {
                val packageNames = call.argument<List<String>>("packageNames").orEmpty()
                MoneyNotificationBridge.setMonitoredPackages(this, packageNames)
                result.success(null)
            }
            "showConfirmationNotification" -> {
                val payload = call.arguments as? Map<*, *>
                if (payload == null) {
                    result.error(
                        "invalid_payload",
                        "Notification payload is invalid.",
                        null,
                    )
                    return
                }

                MoneyNotificationBridge.showConfirmationNotification(this, payload)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestConfirmationNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                notificationPermissionRequestCode,
            )
        }
    }

    private companion object {
        const val notificationPermissionRequestCode = 5001
    }
}
