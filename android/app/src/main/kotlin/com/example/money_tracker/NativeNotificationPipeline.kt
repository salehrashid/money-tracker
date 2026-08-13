package com.example.money_tracker

import android.content.Context

object NativeNotificationPipeline {
    private val duplicateGuard = DuplicateGuard()

    fun processNotification(context: Context, payload: Map<String, Any?>) {
        val normalized = NotificationContentExtractor.extract(payload)
        val monitoredPackages = MoneyNotificationBridge.getMonitoredPackages(context)
        
        val detector = TransactionDetector(monitoredPackages, duplicateGuard)
        val result = detector.evaluate(normalized)

        if (result.type == DetectionResultType.ACCEPTED && result.transaction != null) {
            val transactionPayload = result.transaction.toPayload()
            MoneyNotificationBridge.showConfirmationNotification(context, transactionPayload)
        }
    }
}
