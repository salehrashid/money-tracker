package com.example.money_tracker

enum class NotificationSource(val label: String) {
    MYBCA("myBCA"),
    SIMULATOR("Simulator"),
    UNKNOWN("Unknown")
}

data class NativeDetectedTransaction(
    val type: String,
    val amount: Double,
    val description: String?,
    val originalText: String,
    val detectedAtMillis: Long,
    val sourcePackage: String,
    val sourceApplication: String
) {
    fun toPayload(): Map<String, Any?> {
        return mapOf(
            "action" to "add_transaction",
            "source" to "mybca_notification",
            "transactionType" to type.lowercase(),
            "amount" to amount,
            "description" to (description ?: ""),
            "originalText" to originalText,
            "detectedAtMillis" to detectedAtMillis,
            "sourcePackage" to sourcePackage,
            "sourceApplication" to sourceApplication
        )
    }
}
