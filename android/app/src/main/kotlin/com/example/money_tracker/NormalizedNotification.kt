package com.example.money_tracker

data class NormalizedNotification(
    val packageName: String,
    val appName: String,
    val searchableText: String,
    val lowerText: String,
    val postTimeMillis: Long,
    val notificationKey: String,
    val notificationId: Int,
    val tag: String,
    val title: String,
    val body: String
)
