import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/android_notification_payload.dart';
import '../../domain/entities/notification_log.dart';
import '../../domain/repositories/notification_log_repository.dart';
import '../../domain/services/notification_filter.dart';

class WatchNotificationLogsUseCase {
  const WatchNotificationLogsUseCase(this._repository);

  final NotificationLogRepository _repository;

  Stream<Result<List<NotificationLog>>> execute() {
    return _repository.watchLogs();
  }
}

class SaveNotificationDetectionUseCase {
  const SaveNotificationDetectionUseCase(this._repository);

  final NotificationLogRepository _repository;

  Future<Result<NotificationLog>> execute(NotificationFilterResult result) {
    if (result.source == NotificationSource.unknown) {
      return Future.value(
        const Failure(
          AppFailure(
            type: AppFailureType.validation,
            code: 'unsupported-notification-source',
            message: 'Only MyBCA notifications can be stored.',
          ),
        ),
      );
    }

    final notification = result.notification;
    final transaction = result.detectedTransaction;
    final receivedAt = notification.postTime ?? notification.receivedAt;
    final log = NotificationLog(
      id: notification.dedupeHash,
      appName: _displayAppName(result, notification),
      packageName: notification.packageName,
      title: _displayTitle(notification),
      body: notification.displayBody,
      detectedType: transaction == null
          ? DetectedTransactionType.unknown
          : _detectedTypeFor(transaction.type),
      detectedAmount: transaction?.amount,
      status: _statusFor(result),
      dedupeHash: notification.dedupeHash,
      receivedAt: receivedAt.toUtc(),
      createdAt: DateTime.now().toUtc(),
    );

    return _repository.saveLog(log);
  }
}

class MarkNotificationReadUseCase {
  const MarkNotificationReadUseCase(this._repository);

  final NotificationLogRepository _repository;

  Future<Result<void>> execute(String logId) {
    return _repository.markRead(logId);
  }
}

class MarkAllNotificationsReadUseCase {
  const MarkAllNotificationsReadUseCase(this._repository);

  final NotificationLogRepository _repository;

  Future<Result<void>> execute() {
    return _repository.markAllRead();
  }
}

class IgnoreNotificationUseCase {
  const IgnoreNotificationUseCase(this._repository);

  final NotificationLogRepository _repository;

  Future<Result<void>> execute(String logId) {
    return _repository.ignore(logId);
  }
}

class MarkNotificationProcessedUseCase {
  const MarkNotificationProcessedUseCase(this._repository);

  final NotificationLogRepository _repository;

  Future<Result<void>> execute({
    required String logId,
    required String transactionId,
  }) {
    return _repository.markProcessed(
      logId: logId,
      transactionId: transactionId,
    );
  }
}

class DeleteNotificationUseCase {
  const DeleteNotificationUseCase(this._repository);

  final NotificationLogRepository _repository;

  Future<Result<void>> execute(String logId) {
    return _repository.deleteLog(logId);
  }
}

class DeleteNotificationsUseCase {
  const DeleteNotificationsUseCase(this._repository);

  final NotificationLogRepository _repository;

  Future<Result<void>> execute(Set<String> logIds) {
    return _repository.deleteLogs(logIds);
  }
}

class DeleteReadNotificationsUseCase {
  const DeleteReadNotificationsUseCase(this._repository);

  final NotificationLogRepository _repository;

  Future<Result<void>> execute() {
    return _repository.deleteReadLogs();
  }
}

class DeleteOldNotificationsUseCase {
  const DeleteOldNotificationsUseCase(this._repository);

  final NotificationLogRepository _repository;

  Future<Result<void>> execute() {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30));
    return _repository.deleteOlderThan(cutoff);
  }
}

String _displayAppName(
  NotificationFilterResult result,
  AndroidNotificationPayload notification,
) {
  if (notification.appName.trim().isNotEmpty) {
    return notification.appName;
  }
  return result.source.label(notification);
}

String _displayTitle(AndroidNotificationPayload notification) {
  final title = notification.title.trim();
  return title.isEmpty ? 'MyBCA notification' : title;
}

NotificationLogStatus _statusFor(NotificationFilterResult result) {
  if (result.isAccepted) {
    return NotificationLogStatus.pendingReview;
  }
  return switch (result.type) {
    NotificationFilterResultType.transactionTypeNotFound ||
    NotificationFilterResultType.amountNotFound ||
    NotificationFilterResultType.invalidAmount =>
      NotificationLogStatus.ignoredLowConfidence,
    _ => NotificationLogStatus.ignoredNonTransaction,
  };
}

DetectedTransactionType _detectedTypeFor(TransactionType type) {
  return switch (type) {
    TransactionType.income => DetectedTransactionType.income,
    TransactionType.expense => DetectedTransactionType.expense,
  };
}
