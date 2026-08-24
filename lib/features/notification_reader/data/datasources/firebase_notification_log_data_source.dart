import 'package:firedart/firedart.dart';

import '../../../../core/firebase/firestore_user_collections.dart';
import '../dto/notification_log_dto.dart';

class FirebaseNotificationLogDataSource {
  const FirebaseNotificationLogDataSource(this._collections);

  final FirestoreUserCollections _collections;

  Stream<List<NotificationLogDto>> watchLogs() async* {
    yield const [];

    final initialDocuments = await _collections.notificationLogs.get();
    yield _activeLogs(initialDocuments);

    yield* _collections.notificationLogs.stream.map(_activeLogs);
  }

  List<NotificationLogDto> _activeLogs(Iterable<Document> documents) {
    return documents
        .map(NotificationLogDto.fromFirestore)
        .where((log) => log.deletedAt == null)
        .toList(growable: false);
  }

  Future<NotificationLogDto> saveLog(NotificationLogDto log) async {
    final document = log.id.isEmpty
        ? _collections.notificationLogs.document(log.dedupeHash)
        : _collections.notificationLogs.document(log.id);
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
            updatedAt: log.updatedAt,
            isRead: log.isRead,
            transactionId: log.transactionId,
            deletedAt: log.deletedAt,
          )
        : log;

    final exists = await document.exists;
    final now = DateTime.now().toUtc();
    final data = {
      ...saved.toFirestore(),
      'serverUpdatedAt': now,
      if (!exists) 'serverCreatedAt': now,
    };
    if (exists) {
      await document.update(data);
    } else {
      await document.set(data);
    }
    return saved;
  }

  Future<void> updateLog(String logId, Map<String, dynamic> values) async {
    await _collections.notificationLogs.document(logId).update({
      ...values,
      'serverUpdatedAt': DateTime.now().toUtc(),
    });
  }

  Future<void> updateAllMatching({
    required QueryReference query,
    required Map<String, dynamic> values,
  }) async {
    final documents = await query.get();
    await _commitBatches(
      documents.map((doc) => _BatchUpdate(doc.reference, values)),
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
            (logId) => _BatchUpdate(
              _collections.notificationLogs.document(logId),
              values,
            ),
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
      values: {'deletedAt': deletedAt.toUtc()},
    );
  }

  Future<void> deleteOlderThan(DateTime cutoff) async {
    final documents = await _collections.notificationLogs
        .where('receivedAt', isLessThan: cutoff.toUtc())
        .get();
    await _commitDeletes(documents.map((doc) => doc.reference));
  }

  Future<void> _commitBatches(Iterable<_BatchUpdate> updates) async {
    for (final update in updates) {
      await update.reference.update({
        ...update.values,
        'serverUpdatedAt': DateTime.now().toUtc(),
      });
    }
  }

  Future<void> _commitDeletes(Iterable<DocumentReference> references) async {
    for (final reference in references) {
      await reference.delete();
    }
  }
}

class _BatchUpdate {
  const _BatchUpdate(this.reference, this.values);

  final DocumentReference reference;
  final Map<String, dynamic> values;
}
