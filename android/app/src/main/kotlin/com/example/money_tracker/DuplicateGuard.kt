package com.example.money_tracker

class DuplicateGuard(private val maxEntries: Int = 200) {
    private val seenKeys = mutableSetOf<String>()
    private val seenOrder = mutableListOf<String>()

    fun isDuplicate(key: String): Boolean {
        return synchronized(this) {
            seenKeys.contains(key)
        }
    }

    fun remember(key: String) {
        synchronized(this) {
            seenKeys.add(key)
            seenOrder.add(key)

            while (seenOrder.size > maxEntries) {
                seenKeys.remove(seenOrder.removeAt(0))
            }
        }
    }

    fun generateKey(notification: NormalizedNotification, transaction: NativeDetectedTransaction): String {
        val stablePlatformKey = listOf(
            notification.packageName,
            notification.notificationKey,
            notification.notificationId.toString(),
            notification.tag,
            notification.postTimeMillis.toString()
        ).joinToString("|")

        if (notification.notificationKey.isNotEmpty() || notification.notificationId != 0 || notification.tag.isNotEmpty()) {
            return stablePlatformKey
        }

        return listOf(
            notification.packageName,
            transaction.type,
            String.format("%.2f", transaction.amount),
            notification.searchableText.lowercase(),
            notification.postTimeMillis.toString()
        ).joinToString("|")
    }
}
