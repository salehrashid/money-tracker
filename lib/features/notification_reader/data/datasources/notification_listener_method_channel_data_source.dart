import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/entities/android_notification_payload.dart';
import '../../domain/entities/detected_transaction.dart';

class NotificationListenerMethodChannelDataSource {
  NotificationListenerMethodChannelDataSource({
    MethodChannel channel = const MethodChannel(
      'money_tracker/notification_listener',
    ),
  }) : _channel = channel {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final MethodChannel _channel;
  final _notificationsController =
      StreamController<AndroidNotificationPayload>.broadcast();
  final _transactionReviewRequestsController =
      StreamController<DetectedTransaction>.broadcast();

  Stream<AndroidNotificationPayload> get notifications {
    return _notificationsController.stream;
  }

  Stream<DetectedTransaction> get transactionReviewRequests {
    return _transactionReviewRequestsController.stream;
  }

  Future<bool> isNotificationListenerEnabled() async {
    return await _channel.invokeMethod<bool>('isNotificationListenerEnabled') ??
        false;
  }

  Future<void> openNotificationListenerSettings() {
    return _channel.invokeMethod<void>('openNotificationListenerSettings');
  }

  Future<bool> areConfirmationNotificationsAllowed() async {
    return await _channel.invokeMethod<bool>(
          'areConfirmationNotificationsAllowed',
        ) ??
        false;
  }

  Future<void> requestConfirmationNotificationPermission() {
    return _channel.invokeMethod<void>(
      'requestConfirmationNotificationPermission',
    );
  }

  Future<List<String>> getMonitoredPackages() async {
    final result = await _channel.invokeListMethod<String>(
      'getMonitoredPackages',
    );
    return result ?? const [];
  }

  Future<List<AndroidNotificationPayload>> getRecentNotifications() async {
    final result = await _channel.invokeListMethod<Object?>(
      'getRecentNotifications',
    );
    return result
            ?.whereType<Map<Object?, Object?>>()
            .map(AndroidNotificationPayload.fromPlatformMap)
            .toList() ??
        const [];
  }

  Future<void> setMonitoredPackages(List<String> packageNames) {
    return _channel.invokeMethod<void>('setMonitoredPackages', {
      'packageNames': packageNames,
    });
  }

  Future<void> showConfirmationNotification(DetectedTransaction transaction) {
    return _channel.invokeMethod<void>('showConfirmationNotification', {
      ...transaction.toNotificationPayload(),
    });
  }

  Future<DetectedTransaction?> getInitialTransactionReviewRequest() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'getInitialTransactionReviewRequest',
    );
    if (result == null) {
      return null;
    }
    return DetectedTransaction.fromNotificationPayload(result);
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _notificationsController.close();
    await _transactionReviewRequestsController.close();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    final arguments = call.arguments;
    if (call.method == 'notificationPosted') {
      if (arguments is Map<Object?, Object?>) {
        final payload = AndroidNotificationPayload.fromPlatformMap(arguments);
        _notificationsController.add(payload);
      }
      return;
    }

    if (call.method == 'transactionReviewRequested') {
      if (arguments is Map<Object?, Object?>) {
        try {
          _transactionReviewRequestsController.add(
            DetectedTransaction.fromNotificationPayload(arguments),
          );
        } on FormatException {
          return;
        }
      }
    }
  }
}
