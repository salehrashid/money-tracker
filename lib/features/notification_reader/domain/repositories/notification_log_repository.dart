import '../../../../core/utils/result.dart';
import '../entities/notification_log.dart';

abstract interface class NotificationLogRepository {
  Stream<Result<List<NotificationLog>>> watchLogs();

  Future<Result<NotificationLog>> saveLog(NotificationLog log);

  Future<Result<void>> markRead(String logId);

  Future<Result<void>> markAllRead();

  Future<Result<void>> ignore(String logId);

  Future<Result<void>> markProcessed({
    required String logId,
    required String transactionId,
  });

  Future<Result<void>> deleteLog(String logId);

  Future<Result<void>> deleteLogs(Set<String> logIds);

  Future<Result<void>> deleteReadLogs();

  Future<Result<void>> deleteOlderThan(DateTime cutoff);
}
