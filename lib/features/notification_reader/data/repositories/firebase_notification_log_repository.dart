import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/notification_log.dart';
import '../../domain/repositories/notification_log_repository.dart';
import '../datasources/firebase_notification_log_data_source.dart';
import '../dto/notification_log_dto.dart';

class FirebaseNotificationLogRepository implements NotificationLogRepository {
  const FirebaseNotificationLogRepository({
    required FirebaseNotificationLogDataSource dataSource,
    FirebaseErrorMapper errorMapper = const FirebaseErrorMapper(),
  }) : _dataSource = dataSource,
       _errorMapper = errorMapper;

  final FirebaseNotificationLogDataSource _dataSource;
  final FirebaseErrorMapper _errorMapper;

  @override
  Stream<Result<List<NotificationLog>>> watchLogs() async* {
    try {
      await for (final dtos in _dataSource.watchLogs()) {
        final logs = dtos.map((dto) => dto.toDomain()).toList()
          ..sort(_sortLogs);
        yield Success(logs);
      }
    } catch (error) {
      yield Failure(_mapError(error));
    }
  }

  @override
  Future<Result<NotificationLog>> saveLog(NotificationLog log) async {
    try {
      final saved = await _dataSource.saveLog(
        NotificationLogDto.fromDomain(log),
      );
      return Success(saved.toDomain());
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
      await _dataSource.markAllRead();
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
      await _dataSource.updateMany(logIds, {
        'deletedAt': Timestamp.fromDate(DateTime.now().toUtc()),
      });
      return const Success(null);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<void>> deleteReadLogs() async {
    try {
      await _dataSource.deleteReadLogs(DateTime.now().toUtc());
      return const Success(null);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<void>> deleteOlderThan(DateTime cutoff) async {
    try {
      await _dataSource.deleteOlderThan(cutoff);
      return const Success(null);
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
      await _dataSource.updateLog(logId, values);
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
