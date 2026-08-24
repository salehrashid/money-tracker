import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/offline/sync_coordinator.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/notification_log.dart';
import '../../domain/repositories/notification_log_repository.dart';
import '../datasources/firebase_notification_log_data_source.dart';

class FirebaseNotificationLogRepository implements NotificationLogRepository {
  FirebaseNotificationLogRepository({
    required FirebaseNotificationLogDataSource dataSource,
    required LocalFirstCollection<NotificationLog> local,
    FirebaseErrorMapper errorMapper = const FirebaseErrorMapper(),
  }) : _errorMapper = errorMapper,
       _local = local;

  final FirebaseErrorMapper _errorMapper;
  final LocalFirstCollection<NotificationLog> _local;

  @override
  Stream<Result<List<NotificationLog>>> watchLogs() async* {
    await for (final logs in _local.watch()) {
      logs.sort(_sortLogs);
      yield Success(logs);
    }
  }

  @override
  Future<Result<NotificationLog>> saveLog(NotificationLog log) async {
    try {
      final saved = log.id.isEmpty ? log.copyWith(id: log.dedupeHash) : log;
      final timestamped = saved.copyWith(updatedAt: DateTime.now().toUtc());
      final exists = _local.current.any((item) => item.id == timestamped.id);
      await _local.save(timestamped, isCreate: !exists);
      return Success(timestamped);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<void>> markRead(String logId) {
    return _updateOne(logId, {'isRead': true});
  }

  @override
  Future<Result<void>> markAllRead() async {
    try {
      for (final log in _local.current.where((item) => !item.isRead)) {
        await _local.save(log.copyWith(isRead: true), isCreate: false);
      }
      return const Success(null);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<void>> ignore(String logId) {
    return _updateOne(logId, {
      'isRead': true,
      'status': NotificationLogStatus.ignoredNonTransaction.firestoreValue,
    });
  }

  @override
  Future<Result<void>> markProcessed({
    required String logId,
    required String transactionId,
  }) {
    return _updateOne(logId, {
      'isRead': true,
      'status': NotificationLogStatus.saved.firestoreValue,
      'transactionId': transactionId,
    });
  }

  @override
  Future<Result<void>> deleteLog(String logId) {
    return deleteLogs({logId});
  }

  @override
  Future<Result<void>> deleteLogs(Set<String> logIds) async {
    try {
      final now = DateTime.now().toUtc();
      for (final log in _local.current.where(
        (item) => logIds.contains(item.id),
      )) {
        await _local.delete(log.copyWith(deletedAt: now));
      }
      return const Success(null);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<void>> deleteReadLogs() async {
    try {
      final ids = _local.current
          .where((item) => item.isRead)
          .map((item) => item.id)
          .toSet();
      return deleteLogs(ids);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<void>> deleteOlderThan(DateTime cutoff) async {
    try {
      final ids = _local.current
          .where((item) => item.receivedAt.isBefore(cutoff.toUtc()))
          .map((item) => item.id)
          .toSet();
      return deleteLogs(ids);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  Future<Result<void>> _updateOne(
    String logId,
    Map<String, dynamic> values,
  ) async {
    if (logId.trim().isEmpty) {
      return const Failure(
        AppFailure(
          type: AppFailureType.validation,
          code: 'missing-notification-log-id',
          message: 'Choose a notification first.',
        ),
      );
    }

    try {
      final current = _local.current
          .where((item) => item.id == logId)
          .firstOrNull;
      if (current == null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.notFound,
            code: 'notification-log-not-found',
            message: 'Notification not found.',
          ),
        );
      }
      final updated = current.copyWith(
        updatedAt: DateTime.now().toUtc(),
        isRead: values['isRead'] as bool?,
        status: values['status'] == null
            ? null
            : NotificationLogStatus.fromFirestore(values['status'] as String),
        transactionId: values['transactionId'] as String?,
      );
      await _local.save(updated, isCreate: false);
      return const Success(null);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  AppFailure _mapError(Object error) {
    if (error is FormatException) {
      return AppFailure(
        type: AppFailureType.validation,
        code: 'invalid-notification-log-data',
        message: 'Saved notification data is invalid. Please try again.',
        details: error,
      );
    }

    return _errorMapper.map(error);
  }
}

int _sortLogs(NotificationLog first, NotificationLog second) {
  return second.receivedAt.compareTo(first.receivedAt);
}
