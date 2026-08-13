package com.example.money_tracker

object TransactionParser {

    private val amountPattern = Regex(
        "\\b(IDR|Rp)\\s*([0-9]{1,3}(?:(?:[.,][0-9]{3})+)(?:\\.[0-9]{2})?|[0-9]+(?:\\.[0-9]{2})?)\\b",
        RegexOption.IGNORE_CASE
    )

    fun extractTransactionType(lowerText: String): String? {
        if (lowerText.contains("pengeluaran")) {
            return "expense"
        }
        if (lowerText.contains("pemasukkan") || lowerText.contains("pemasukan")) {
            return "income"
        }
        return null
    }

    fun extractAmount(text: String): Double? {
        val match = amountPattern.find(text) ?: return null
        val rawCurrency = match.groupValues.getOrNull(1)?.lowercase()
        val rawAmount = match.groupValues.getOrNull(2) ?: return null

        val normalized = if (rawCurrency == "rp") {
            rawAmount.replace(".", "").replace(",", ".")
        } else {
            rawAmount.replace(",", "")
        }
        return normalized.toDoubleOrNull()
    }

    fun extractDescription(text: String): String? {
        val singleLineText = text.replace("\n", " ")
        val regex = Regex("\\b(?:untuk|di|ke|dari)\\s+(.+)$", RegexOption.IGNORE_CASE)
        val match = regex.find(singleLineText) ?: return null
        
        var description = match.groupValues.getOrNull(1) ?: return null
        description = description.replace(amountPattern, "")
            .replace(Regex("\\s+"), " ")
            .trim()
            .replace(Regex("[.!]+$"), "")

        if (description.isEmpty() || looksSensitive(description)) {
            return null
        }
        
        return if (description.length > 120) {
            description.substring(0, 120).trim()
        } else {
            description
        }
    }

    private fun looksSensitive(value: String): Boolean {
        val digits = Regex("\\d").findAll(value).count()
        return digits >= 8
    }
}
