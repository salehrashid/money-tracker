import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/android_notification_payload.dart';
import '../../domain/entities/detected_transaction.dart';
import '../../domain/entities/notification_listener_status.dart';
import '../../domain/repositories/notification_listener_repository.dart';
import '../datasources/notification_listener_method_channel_data_source.dart';

class PlatformNotificationListenerRepository
    implements NotificationListenerRepository {
  const PlatformNotificationListenerRepository({
    required NotificationListenerMethodChannelDataSource dataSource,
    required bool isSupported,
  }) : _dataSource = dataSource,
       _isSupported = isSupported;

  final NotificationListenerMethodChannelDataSource _dataSource;
  final bool _isSupported;

  @override
  Stream<AndroidNotificationPayload> watchNotifications() {
    if (!_isSupported) {
      return const Stream.empty();
    }
    return _dataSource.notifications;
  }

  @override
  Future<Result<List<AndroidNotificationPayload>>>
  getRecentNotifications() async {
    if (!_isSupported) {
      return const Success([]);
    }

    try {
      return Success(await _dataSource.getRecentNotifications());
    } on Object catch (error) {
      return Failure(_mapPlatformFailure(error));
    }
  }

  @override
  Future<Result<NotificationListenerStatus>> getStatus() async {
    if (!_isSupported) {
      return const Success(
        NotificationListenerStatus(
          isSupported: false,
          isListenerEnabled: false,
          areConfirmationNotificationsAllowed: false,
          monitoredPackages: [],
          capturesAllPackagesInDebug: false,
        ),
      );
    }

    try {
      final isListenerEnabled = await _dataSource
          .isNotificationListenerEnabled();
      final areNotificationsAllowed = await _dataSource
          .areConfirmationNotificationsAllowed();
      final monitoredPackages = await _dataSource.getMonitoredPackages();

      return Success(
        NotificationListenerStatus(
          isSupported: true,
          isListenerEnabled: isListenerEnabled,
          areConfirmationNotificationsAllowed: areNotificationsAllowed,
          monitoredPackages: monitoredPackages,
          capturesAllPackagesInDebug: kDebugMode && monitoredPackages.isEmpty,
        ),
      );
    } on Object catch (error) {
      return Failure(_mapPlatformFailure(error));
    }
  }

  @override
  Future<Result<void>> openNotificationListenerSettings() async {
    if (!_isSupported) {
      return const Failure(_unsupportedFailure);
    }

    try {
      await _dataSource.openNotificationListenerSettings();
      return const Success(null);
    } on Object catch (error) {
      return Failure(_mapPlatformFailure(error));
    }
  }

  @override
  Future<Result<void>> requestConfirmationNotificationPermission() async {
    if (!_isSupported) {
      return const Failure(_unsupportedFailure);
    }

    try {
      await _dataSource.requestConfirmationNotificationPermission();
      return const Success(null);
    } on Object catch (error) {
      return Failure(_mapPlatformFailure(error));
    }
  }

  @override
  Future<Result<void>> setMonitoredPackages(List<String> packageNames) async {
    if (!_isSupported) {
      return const Failure(_unsupportedFailure);
    }

    final normalized =
        packageNames
            .map((packageName) => packageName.trim())
            .where((packageName) => packageName.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    try {
      await _dataSource.setMonitoredPackages(normalized);
      return const Success(null);
    } on Object catch (error) {
      return Failure(_mapPlatformFailure(error));
    }
  }

  @override
  Future<Result<void>> showConfirmationNotification(
    DetectedTransaction transaction,
  ) async {
    if (!_isSupported) {
      return const Failure(_unsupportedFailure);
    }
    if (transaction.amount <= 0) {
      return const Failure(
        AppFailure(
          type: AppFailureType.validation,
          message: 'Detected transaction amount is invalid.',
        ),
      );
    }

    try {
      await _dataSource.showConfirmationNotification(transaction);
      return const Success(null);
    } on Object catch (error) {
      return Failure(_mapPlatformFailure(error));
    }
  }

  @override
  Future<Result<DetectedTransaction?>>
  getInitialTransactionReviewRequest() async {
    if (!_isSupported) {
      return const Success(null);
    }

    try {
      return Success(await _dataSource.getInitialTransactionReviewRequest());
    } on FormatException {
      return const Failure(
        AppFailure(
          type: AppFailureType.validation,
          message: 'Transaction notification payload is invalid.',
        ),
      );
    } on Object catch (error) {
      return Failure(_mapPlatformFailure(error));
    }
  }

  @override
  Stream<DetectedTransaction> watchTransactionReviewRequests() {
    if (!_isSupported) {
      return const Stream.empty();
    }
    return _dataSource.transactionReviewRequests;
  }

  static bool get isAndroidSupported {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  static const _unsupportedFailure = AppFailure(
    type: AppFailureType.unavailable,
    message: 'Android notification listening is not supported on this device.',
  );

  static AppFailure _mapPlatformFailure(Object error) {
    if (error is PlatformException) {
      return AppFailure(
        type: AppFailureType.unavailable,
        message: error.message ?? 'Unable to access Android notifications.',
        code: error.code,
        details: kDebugMode ? error.details : null,
      );
    }
    if (error is MissingPluginException) {
      return const AppFailure(
        type: AppFailureType.unavailable,
        message: 'Android notification listener is unavailable in this build.',
      );
    }
    return AppFailure(
      type: AppFailureType.unknown,
      message: 'Unable to access Android notifications.',
      details: kDebugMode ? error : null,
    );
  }
}
