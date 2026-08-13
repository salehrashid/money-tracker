package com.example.money_tracker

import android.util.Log

enum class DetectionResultType(val logValue: String) {
    ACCEPTED("ACCEPTED"),
    UNKNOWN_PACKAGE("UNKNOWN_PACKAGE"),
    NOT_TRANSACTION("NOT_TRANSACTION"),
    TRANSACTION_TYPE_NOT_FOUND("TRANSACTION_TYPE_NOT_FOUND"),
    AMOUNT_NOT_FOUND("AMOUNT_NOT_FOUND"),
    INVALID_AMOUNT("INVALID_AMOUNT"),
    DUPLICATE_NOTIFICATION("DUPLICATE_NOTIFICATION"),
    INVALID_NOTIFICATION("INVALID_NOTIFICATION")
}

data class DetectionResult(
    val type: DetectionResultType,
    val source: NotificationSource,
    val transaction: NativeDetectedTransaction? = null
)

class TransactionDetector(
    private val allowedPackageNames: Set<String>,
    private val duplicateGuard: DuplicateGuard
) {
    private val myBcaPackageName = "com.bca.mybca.omni.android"

    fun evaluate(notification: NormalizedNotification): DetectionResult {
        if (notification.packageName.isEmpty() || notification.searchableText.isEmpty()) {
            return DetectionResult(DetectionResultType.INVALID_NOTIFICATION, NotificationSource.UNKNOWN)
        }

        val source = classifySource(notification)
        if (source == NotificationSource.UNKNOWN) {
            return DetectionResult(DetectionResultType.UNKNOWN_PACKAGE, source)
        }

        val transactionType = TransactionParser.extractTransactionType(notification.lowerText)
        if (transactionType == null) {
            return DetectionResult(DetectionResultType.TRANSACTION_TYPE_NOT_FOUND, source)
        }

        val amount = TransactionParser.extractAmount(notification.searchableText)
        if (amount == null) {
            return DetectionResult(DetectionResultType.AMOUNT_NOT_FOUND, source)
        }
        if (amount <= 0) {
            return DetectionResult(DetectionResultType.INVALID_AMOUNT, source)
        }

        val description = TransactionParser.extractDescription(notification.searchableText)

        val sourceApplication = when (source) {
            NotificationSource.MYBCA -> "myBCA"
            NotificationSource.SIMULATOR -> if (notification.appName.trim().isEmpty()) "Simulator" else notification.appName
            else -> "Unknown"
        }

        val transaction = NativeDetectedTransaction(
            type = transactionType,
            amount = amount,
            description = description,
            originalText = notification.searchableText,
            detectedAtMillis = notification.postTimeMillis,
            sourcePackage = notification.packageName,
            sourceApplication = sourceApplication
        )

        val dedupeKey = duplicateGuard.generateKey(notification, transaction)
        if (duplicateGuard.isDuplicate(dedupeKey)) {
            return DetectionResult(DetectionResultType.DUPLICATE_NOTIFICATION, source, transaction)
        }

        duplicateGuard.remember(dedupeKey)
        return DetectionResult(DetectionResultType.ACCEPTED, source, transaction)
    }

    private fun classifySource(notification: NormalizedNotification): NotificationSource {
        if (notification.packageName == myBcaPackageName) {
            return NotificationSource.MYBCA
        }
        if (allowedPackageNames.contains(notification.packageName)) {
            return NotificationSource.SIMULATOR
        }
        if (notification.lowerText.contains("catatan finansial")) {
            return NotificationSource.SIMULATOR
        }
        return NotificationSource.UNKNOWN
    }
}
