package com.example.money_tracker

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class TransactionDetectorTest {

    private fun createNotification(
        packageName: String,
        title: String,
        text: String
    ): NormalizedNotification {
        val payload = mapOf(
            "packageName" to packageName,
            "title" to title,
            "body" to text,
            "postTimeMillis" to 1000L
        )
        return NotificationContentExtractor.extract(payload)
    }

    private fun detector(): TransactionDetector {
        val duplicateGuard = DuplicateGuard()
        return TransactionDetector(setOf("com.example.simulator"), duplicateGuard)
    }

    @Test
    fun `test Simulator Expense`() {
        val notification = createNotification(
            "com.example.simulator",
            "Catatan Finansial",
            "Pengeluaran Rp50.000"
        )
        
        val result = detector().evaluate(notification)
        
        assertEquals(DetectionResultType.ACCEPTED, result.type)
        assertEquals(NotificationSource.SIMULATOR, result.source)
        assertNotNull(result.transaction)
        assertEquals("expense", result.transaction?.type)
        assertEquals(50000.0, result.transaction?.amount)
    }

    @Test
    fun `test Simulator Income`() {
        val notification = createNotification(
            "com.example.simulator",
            "Catatan Finansial",
            "Pemasukkan Rp2.500.000"
        )
        
        val result = detector().evaluate(notification)
        
        assertEquals(DetectionResultType.ACCEPTED, result.type)
        assertEquals(NotificationSource.SIMULATOR, result.source)
        assertNotNull(result.transaction)
        assertEquals("income", result.transaction?.type)
        assertEquals(2500000.0, result.transaction?.amount)
    }

    @Test
    fun `test Missing Amount`() {
        val notification = createNotification(
            "com.example.simulator",
            "Catatan Finansial",
            "Pengeluaran"
        )
        
        val result = detector().evaluate(notification)
        
        assertEquals(DetectionResultType.AMOUNT_NOT_FOUND, result.type)
        assertNull(result.transaction)
    }

    @Test
    fun `test Missing Transaction Type`() {
        val notification = createNotification(
            "com.example.simulator",
            "Catatan Finansial",
            "Rp50.000"
        )
        
        val result = detector().evaluate(notification)
        
        assertEquals(DetectionResultType.TRANSACTION_TYPE_NOT_FOUND, result.type)
        assertNull(result.transaction)
    }

    @Test
    fun `test Real myBCA Expense`() {
        val notification = createNotification(
            "com.bca.mybca.omni.android",
            "myBCA",
            "Pengeluaran ke Rekening Rp50.000 berhasil."
        )
        
        val result = detector().evaluate(notification)
        
        assertEquals(DetectionResultType.ACCEPTED, result.type)
        assertEquals(NotificationSource.MYBCA, result.source)
        assertEquals("expense", result.transaction?.type)
        assertEquals(50000.0, result.transaction?.amount)
    }

    @Test
    fun `test Unrelated App`() {
        val notification = createNotification(
            "com.example.otherapp",
            "Hello",
            "Pengeluaran Rp50.000"
        )
        
        val result = detector().evaluate(notification)
        
        assertEquals(DetectionResultType.UNKNOWN_PACKAGE, result.type)
        assertNull(result.transaction)
    }
    
    @Test
    fun `test Duplicate Notification`() {
        val notification = createNotification(
            "com.example.simulator",
            "Catatan Finansial",
            "Pengeluaran Rp50.000"
        )
        
        val myDetector = detector()
        
        val result1 = myDetector.evaluate(notification)
        assertEquals(DetectionResultType.ACCEPTED, result1.type)
        
        val result2 = myDetector.evaluate(notification)
        assertEquals(DetectionResultType.DUPLICATE_NOTIFICATION, result2.type)
    }
}
