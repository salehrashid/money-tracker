import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_user_collections.dart';
import '../dto/notification_log_dto.dart';

class FirebaseNotificationLogDataSource {
  const FirebaseNotificationLogDataSource(this._collections);

  final FirestoreUserCollections _collections;

  Stream<List<NotificationLogDto>> watchLogs() {
    return _collections.notificationLogs
        .where('deletedAt', isNull: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(NotificationLogDto.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<NotificationLogDto> saveLog(NotificationLogDto log) async {
    final document = log.id.isEmpty
        ? _collections.notificationLogs.doc(log.dedupeHash)
        : _collections.notificationLogs.doc(log.id);
    final saved = log.id.isEmpty
        ? NotificationLogDto(
            id: document.id,
            appName: log.appName,
            packageName: log.packageName,
            title: log.title,
            body: log.body,
            detectedType: log.detectedType,
            detectedAmount: log.detectedAmount,
            status: log.status,
            dedupeHash: log.dedupeHash,
            receivedAt: log.receivedAt,
            createdAt: log.createdAt,
            isRead: log.isRead,
            transactionId: log.transactionId,
            deletedAt: log.deletedAt,
          )
        : log;

    await document.set({
      ...saved.toFirestore(),
      if (log.id.isEmpty) 'serverCreatedAt': FieldValue.serverTimestamp(),
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return saved;
  }

  Future<void> updateLog(String logId, Map<String, dynamic> values) async {
    await _collections.notificationLogs.doc(logId).set({
      ...values,
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateAllMatching({
    required Query<Map<String, dynamic>> query,
    required Map<String, dynamic> values,
  }) async {
    final snapshot = await query.get();
    await _commitBatches(
      snapshot.docs.map((doc) => _BatchUpdate(doc.reference, values)),
    );
  }

  Future<void> updateMany(
    Iterable<String> logIds,
    Map<String, dynamic> values,
  ) async {
    await _commitBatches(
      logIds
          .where((logId) => logId.trim().isNotEmpty)
          .map(
            (logId) =>
                _BatchUpdate(_collections.notificationLogs.doc(logId), values),
          ),
    );
  }

  Future<void> markAllRead() {
    return updateAllMatching(
      query: _collections.notificationLogs
          .where('deletedAt', isNull: true)
          .where('isRead', isEqualTo: false),
      values: {'isRead': true},
    );
  }

  Future<void> deleteReadLogs(DateTime deletedAt) {
    return updateAllMatching(
      query: _collections.notificationLogs
          .where('deletedAt', isNull: true)
          .where('isRead', isEqualTo: true),
      values: {'deletedAt': Timestamp.fromDate(deletedAt)},
    );
  }

  Future<void> deleteOlderThan(DateTime cutoff) async {
    final snapshot = await _collections.notificationLogs
        .where('receivedAt', isLessThan: Timestamp.fromDate(cutoff))
        .get();
    await _commitDeletes(snapshot.docs.map((doc) => doc.reference));
  }

  Future<void> _commitBatches(Iterable<_BatchUpdate> updates) async {
    var batch = _collections.userDocument.firestore.batch();
    var count = 0;
    for (final update in updates) {
      batch.set(update.reference, update.values, SetOptions(merge: true));
      count += 1;
      if (count == 450) {
        await batch.commit();
        batch = _collections.userDocument.firestore.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit();
    }
  }

  Future<void> _commitDeletes(
    Iterable<DocumentReference<Map<String, dynamic>>> references,
  ) async {
    var batch = _collections.userDocument.firestore.batch();
    var count = 0;
    for (final reference in references) {
      batch.delete(reference);
      count += 1;
      if (count == 450) {
        await batch.commit();
        batch = _collections.userDocument.firestore.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit();
    }
  }
}

class _BatchUpdate {
  const _BatchUpdate(this.reference, this.values);

  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic> values;
}
