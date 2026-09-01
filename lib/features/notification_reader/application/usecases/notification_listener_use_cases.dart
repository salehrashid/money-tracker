import '../../../../core/utils/result.dart';
import '../../domain/entities/android_notification_payload.dart';
import '../../domain/entities/detected_transaction.dart';
import '../../domain/entities/notification_listener_status.dart';
import '../../domain/repositories/notification_listener_repository.dart';

class WatchAndroidNotificationsUseCase {
  const WatchAndroidNotificationsUseCase(this._repository);

  final NotificationListenerRepository _repository;

  Stream<AndroidNotificationPayload> execute() {
    return _repository.watchNotifications();
  }
}

class GetNotificationListenerStatusUseCase {
  const GetNotificationListenerStatusUseCase(this._repository);

  final NotificationListenerRepository _repository;

  Future<Result<NotificationListenerStatus>> execute() {
    return _repository.getStatus();
  }
}

class GetNotificationPermissionStatusUseCase {
  const GetNotificationPermissionStatusUseCase(this._repository);

  final NotificationListenerRepository _repository;

  Future<Result<bool>> execute() {
    return _repository.isNotificationPermissionGranted();
  }
}

class GetRecentAndroidNotificationsUseCase {
  const GetRecentAndroidNotificationsUseCase(this._repository);

  final NotificationListenerRepository _repository;

  Future<Result<List<AndroidNotificationPayload>>> execute() {
    return _repository.getRecentNotifications();
  }
}

class OpenNotificationListenerSettingsUseCase {
  const OpenNotificationListenerSettingsUseCase(this._repository);

  final NotificationListenerRepository _repository;

  Future<Result<void>> execute() {
    return _repository.openNotificationListenerSettings();
  }
}

class RequestConfirmationNotificationPermissionUseCase {
  const RequestConfirmationNotificationPermissionUseCase(this._repository);

  final NotificationListenerRepository _repository;

  Future<Result<void>> execute() {
    return _repository.requestConfirmationNotificationPermission();
  }
}

class SetMonitoredNotificationPackagesUseCase {
  const SetMonitoredNotificationPackagesUseCase(this._repository);

  final NotificationListenerRepository _repository;

  Future<Result<void>> execute(List<String> packageNames) {
    return _repository.setMonitoredPackages(packageNames);
  }
}

class ShowNotificationReviewConfirmationUseCase {
  const ShowNotificationReviewConfirmationUseCase(this._repository);

  final NotificationListenerRepository _repository;

  Future<Result<void>> execute(DetectedTransaction transaction) {
    return _repository.showConfirmationNotification(transaction);
  }
}

class GetInitialTransactionReviewRequestUseCase {
  const GetInitialTransactionReviewRequestUseCase(this._repository);

  final NotificationListenerRepository _repository;

  Future<Result<DetectedTransaction?>> execute() {
    return _repository.getInitialTransactionReviewRequest();
  }
}

class WatchTransactionReviewRequestsUseCase {
  const WatchTransactionReviewRequestsUseCase(this._repository);

  final NotificationListenerRepository _repository;

  Stream<DetectedTransaction> execute() {
    return _repository.watchTransactionReviewRequests();
  }
}
