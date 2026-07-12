import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/entities/android_notification_payload.dart';

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

  Stream<AndroidNotificationPayload> get notifications {
    return _notificationsController.stream;
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

  Future<void> showConfirmationNotification(
    AndroidNotificationPayload payload,
  ) {
    return _channel.invokeMethod<void>('showConfirmationNotification', {
      ...payload.toPlatformMap(),
      'filterAccepted': true,
    });
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _notificationsController.close();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'notificationPosted') {
      return;
    }

    final arguments = call.arguments;
    if (arguments is Map<Object?, Object?>) {
      final payload = AndroidNotificationPayload.fromPlatformMap(arguments);
      _notificationsController.add(payload);
    }
  }
}
