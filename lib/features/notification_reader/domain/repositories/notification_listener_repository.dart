import '../../../../core/utils/result.dart';
import '../entities/android_notification_payload.dart';
import '../entities/detected_transaction.dart';
import '../entities/notification_listener_status.dart';

abstract interface class NotificationListenerRepository {
  Stream<AndroidNotificationPayload> watchNotifications();

  Future<Result<List<AndroidNotificationPayload>>> getRecentNotifications();

  Future<Result<NotificationListenerStatus>> getStatus();

  Future<Result<bool>> isNotificationPermissionGranted();

  Future<Result<void>> openNotificationListenerSettings();

  Future<Result<void>> requestConfirmationNotificationPermission();

  Future<Result<void>> setMonitoredPackages(List<String> packageNames);

  Future<Result<void>> showConfirmationNotification(
    DetectedTransaction transaction,
  );

  Future<Result<DetectedTransaction?>> getInitialTransactionReviewRequest();

  Stream<DetectedTransaction> watchTransactionReviewRequests();
}
