import 'dart:developer' as developer;

import '../entities/android_notification_payload.dart';

enum NotificationFilterResultType {
  accepted('ACCEPTED'),
  rejectedPackage('REJECTED_PACKAGE'),
  rejectedTitle('REJECTED_TITLE'),
  rejectedBody('REJECTED_BODY'),
  rejectedAmount('REJECTED_AMOUNT'),
  rejectedDuplicate('REJECTED_DUPLICATE');

  const NotificationFilterResultType(this.logValue);

  final String logValue;
}

class NotificationFilterResult {
  const NotificationFilterResult({
    required this.type,
    required this.notification,
    this.amount,
  });

  final NotificationFilterResultType type;
  final AndroidNotificationPayload notification;
  final double? amount;

  bool get isAccepted => type == NotificationFilterResultType.accepted;
}

class NotificationFilter {
  NotificationFilter({
    Set<String> allowedPackageNames = const {'com.bca.mybca.omni.android'},
    this.maxDedupeEntries = 200,
  }) : _allowedPackageNames = allowedPackageNames
           .map((packageName) => packageName.trim().toLowerCase())
           .where((packageName) => packageName.isNotEmpty)
           .toSet();

  final Set<String> _allowedPackageNames;
  final int maxDedupeEntries;
  final _seenKeys = <String>{};
  final _seenOrder = <String>[];

  NotificationFilterResult evaluate(AndroidNotificationPayload notification) {
    final result = _evaluate(notification);
    _logResult(result);
    return result;
  }

  NotificationFilterResult _evaluate(AndroidNotificationPayload notification) {
    final packageName = notification.packageName.trim().toLowerCase();
    if (!_allowedPackageNames.contains(packageName)) {
      return NotificationFilterResult(
        type: NotificationFilterResultType.rejectedPackage,
        notification: notification,
      );
    }

    if (!notification.title.toLowerCase().contains('catatan finansial')) {
      return NotificationFilterResult(
        type: NotificationFilterResultType.rejectedTitle,
        notification: notification,
      );
    }

    final body = _searchableBody(notification);
    final lowerBody = body.toLowerCase();
    final hasTransactionKeyword =
        lowerBody.contains('pengeluaran') || lowerBody.contains('pemasukan');
    if (!hasTransactionKeyword || !lowerBody.contains('idr')) {
      return NotificationFilterResult(
        type: NotificationFilterResultType.rejectedBody,
        notification: notification,
      );
    }

    final amount = _extractAmount(body);
    if (amount == null) {
      return NotificationFilterResult(
        type: NotificationFilterResultType.rejectedAmount,
        notification: notification,
      );
    }

    final dedupeKey = _dedupeKey(notification);
    if (_seenKeys.contains(dedupeKey)) {
      return NotificationFilterResult(
        type: NotificationFilterResultType.rejectedDuplicate,
        notification: notification,
        amount: amount,
      );
    }

    _remember(dedupeKey);
    return NotificationFilterResult(
      type: NotificationFilterResultType.accepted,
      notification: notification,
      amount: amount,
    );
  }

  double? _extractAmount(String body) {
    final match = RegExp(
      r'\bIDR\s+([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{2})?|[0-9]+(?:\.[0-9]{2})?)\b',
      caseSensitive: false,
    ).firstMatch(body);
    if (match == null) {
      return null;
    }

    final rawAmount = match.group(1);
    if (rawAmount == null) {
      return null;
    }

    return double.tryParse(rawAmount.replaceAll(',', ''));
  }

  String _dedupeKey(AndroidNotificationPayload notification) {
    return [
      notification.packageName.trim().toLowerCase(),
      notification.title.trim().toLowerCase(),
      notification.displayBody.trim(),
      notification.receivedAt.millisecondsSinceEpoch,
    ].join('|');
  }

  String _searchableBody(AndroidNotificationPayload notification) {
    return [
      notification.body,
      notification.bigText,
      notification.subText,
    ].where((value) => value.trim().isNotEmpty).join('\n');
  }

  void _remember(String key) {
    _seenKeys.add(key);
    _seenOrder.add(key);

    while (_seenOrder.length > maxDedupeEntries) {
      _seenKeys.remove(_seenOrder.removeAt(0));
    }
  }

  void _logResult(NotificationFilterResult result) {
    final notification = result.notification;
    developer.log('''
------------------------------------------------
Package
${notification.packageName}

Title
${notification.title}

Body
${notification.displayBody}

Result
${result.type.logValue}
------------------------------------------------
''', name: 'NotificationFilter');
  }
}
