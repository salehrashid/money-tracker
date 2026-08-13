package com.example.money_tracker

object NotificationContentExtractor {

    fun extract(payload: Map<String, Any?>): NormalizedNotification {
        val packageName = (payload["packageName"] as? String)?.trim()?.lowercase() ?: ""
        val appName = (payload["appName"] as? String)?.trim() ?: ""
        val notificationKey = (payload["notificationKey"] as? String)?.trim() ?: ""
        val notificationId = payload["notificationId"] as? Int ?: 0
        val tag = (payload["tag"] as? String)?.trim() ?: ""
        val postTimeMillis = (payload["postTimeMillis"] as? Long) ?: System.currentTimeMillis()

        val title = (payload["title"] as? String)?.trim() ?: ""
        val body = (payload["body"] as? String)?.trim() ?: ""
        val bigText = (payload["bigText"] as? String)?.trim() ?: ""
        val subText = (payload["subText"] as? String)?.trim() ?: ""
        val ticker = (payload["ticker"] as? String)?.trim() ?: ""

        val textLines = (payload["textLines"] as? List<*>)?.mapNotNull { it?.toString() } ?: emptyList()

        val extras = payload["extras"] as? Map<*, *> ?: emptyMap<Any, Any>()
        val interestingExtras = extractInterestingExtras(extras)

        val parts = mutableListOf<String>()
        parts.add(title)
        parts.add(body)
        parts.add(bigText)
        parts.add(subText)
        parts.add(ticker)
        parts.addAll(textLines)
        parts.addAll(interestingExtras)

        val normalizedParts = mutableListOf<String>()
        val seen = mutableSetOf<String>()

        for (part in parts) {
            val normalized = normalizeText(part)
            if (normalized.isEmpty()) continue
            val comparable = normalized.lowercase()
            if (seen.add(comparable)) {
                normalizedParts.add(normalized)
            }
        }

        val searchableText = normalizedParts.joinToString("\n")

        return NormalizedNotification(
            packageName = packageName,
            appName = appName,
            searchableText = searchableText,
            lowerText = searchableText.lowercase(),
            postTimeMillis = postTimeMillis,
            notificationKey = notificationKey,
            notificationId = notificationId,
            tag = tag,
            title = title,
            body = body
        )
    }

    private fun extractInterestingExtras(extras: Map<*, *>): List<String> {
        val interestingKeys = setOf(
            "android.title",
            "android.text",
            "android.bigText",
            "android.subText",
            "android.summaryText",
            "android.infoText",
            "android.textLines"
        )
        return extras.entries
            .filter { interestingKeys.contains(it.key.toString()) }
            .mapNotNull { it.value?.toString() }
    }

    private fun normalizeText(value: String): String {
        return value
            .replace(Regex("[\\u00a0\\u2000-\\u200b\\u202f\\u205f\\u3000]"), " ")
            .replace(Regex("\\r\\n?"), "\n")
            .split("\n")
            .map { it.replace(Regex("\\s+"), " ").trim() }
            .filter { it.isNotEmpty() }
            .joinToString("\n")
            .trim()
    }
}
