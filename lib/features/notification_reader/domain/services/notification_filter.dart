import 'dart:developer' as developer;

import '../entities/android_notification_payload.dart';
import '../entities/detected_transaction.dart';
import '../../../../shared/models/finance_enums.dart';

enum NotificationFilterResultType {
  accepted('ACCEPTED'),
  unknownPackage('UNKNOWN_PACKAGE'),
  notTransaction('NOT_TRANSACTION'),
  transactionTypeNotFound('TRANSACTION_TYPE_NOT_FOUND'),
  amountNotFound('AMOUNT_NOT_FOUND'),
  invalidAmount('INVALID_AMOUNT'),
  duplicateNotification('DUPLICATE_NOTIFICATION'),
  invalidNotification('INVALID_NOTIFICATION');

  const NotificationFilterResultType(this.logValue);

  final String logValue;
}

class NotificationFilterResult {
  const NotificationFilterResult({
    required this.type,
    required this.notification,
    required this.normalizedNotification,
    required this.source,
    this.detectedTransaction,
  });

  final NotificationFilterResultType type;
  final AndroidNotificationPayload notification;
  final NormalizedNotification normalizedNotification;
  final NotificationSource source;
  final DetectedTransaction? detectedTransaction;

  bool get isAccepted => type == NotificationFilterResultType.accepted;
  double? get amount => detectedTransaction?.amount;
  String get reason => type.logValue;
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
    final normalized = NormalizedNotification.fromPayload(notification);
    if (normalized.packageName.isEmpty || !notification.hasContent) {
      return NotificationFilterResult(
        type: NotificationFilterResultType.invalidNotification,
        notification: notification,
        normalizedNotification: normalized,
        source: NotificationSource.unknown,
      );
    }

    final source = _classifySource(normalized);
    if (source == NotificationSource.unknown) {
      return NotificationFilterResult(
        type: NotificationFilterResultType.unknownPackage,
        notification: notification,
        normalizedNotification: normalized,
        source: source,
      );
    }

    final transactionType = _extractTransactionType(normalized.lowerText);
    if (transactionType == null) {
      return NotificationFilterResult(
        type: NotificationFilterResultType.transactionTypeNotFound,
        notification: notification,
        normalizedNotification: normalized,
        source: source,
      );
    }

    final amount = _extractAmount(normalized.searchableText);
    if (amount == null) {
      return NotificationFilterResult(
        type: NotificationFilterResultType.amountNotFound,
        notification: notification,
        normalizedNotification: normalized,
        source: source,
      );
    }
    if (amount <= 0) {
      return NotificationFilterResult(
        type: NotificationFilterResultType.invalidAmount,
        notification: notification,
        normalizedNotification: normalized,
        source: source,
      );
    }

    final detectedTransaction = DetectedTransaction(
      type: transactionType,
      amount: amount,
      description: _extractDescription(normalized.searchableText),
      originalText: normalized.searchableText,
      detectedAt: notification.postTime ?? notification.receivedAt,
      sourcePackage: notification.packageName,
      source: source.label(notification),
    );

    final dedupeKey = _dedupeKey(notification, detectedTransaction);
    if (_seenKeys.contains(dedupeKey)) {
      return NotificationFilterResult(
        type: NotificationFilterResultType.duplicateNotification,
        notification: notification,
        normalizedNotification: normalized,
        source: source,
        detectedTransaction: detectedTransaction,
      );
    }

    _remember(dedupeKey);
    return NotificationFilterResult(
      type: NotificationFilterResultType.accepted,
      notification: notification,
      normalizedNotification: normalized,
      source: source,
      detectedTransaction: detectedTransaction,
    );
  }

  NotificationSource _classifySource(NormalizedNotification notification) {
    if (notification.packageName == myBcaPackageName) {
      return NotificationSource.myBca;
    }

    if (_allowedPackageNames.contains(notification.packageName)) {
      return NotificationSource.simulator;
    }

    if (notification.lowerText.contains('catatan finansial')) {
      return NotificationSource.simulator;
    }

    return NotificationSource.unknown;
  }

  TransactionType? _extractTransactionType(String lowerText) {
    if (lowerText.contains('pengeluaran')) {
      return TransactionType.expense;
    }
    if (lowerText.contains('pemasukkan') || lowerText.contains('pemasukan')) {
      return TransactionType.income;
    }
    return null;
  }

  double? _extractAmount(String text) {
    final match = _amountPattern.firstMatch(text);
    if (match == null) {
      return null;
    }

    final rawCurrency = match.group(1)?.toLowerCase();
    final rawAmount = match.group(2);
    if (rawAmount == null || rawCurrency == null) {
      return null;
    }

    final normalized = rawCurrency == 'rp'
        ? rawAmount.replaceAll('.', '').replaceAll(',', '.')
        : rawAmount.replaceAll(',', '');
    return double.tryParse(normalized);
  }

  String? _extractDescription(String text) {
    final match = RegExp(
      r'\b(?:untuk|di|ke|dari)\s+(.+)$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text.replaceAll('\n', ' '));
    final description = match
        ?.group(1)
        ?.replaceAll(_amountPattern, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceFirst(RegExp(r'[.!]+$'), '');
    if (description == null || description.isEmpty) {
      return null;
    }
    if (_looksSensitive(description)) {
      return null;
    }
    return description.length > 120
        ? description.substring(0, 120).trim()
        : description;
  }

  bool _looksSensitive(String value) {
    final digits = RegExp(r'\d').allMatches(value).length;
    return digits >= 8;
  }

  String _dedupeKey(
    AndroidNotificationPayload notification,
    DetectedTransaction detectedTransaction,
  ) {
    final stablePlatformKey = [
      notification.packageName.trim().toLowerCase(),
      notification.notificationKey.trim(),
      notification.notificationId?.toString() ?? '',
      notification.tag.trim(),
      (notification.postTime ?? notification.receivedAt).millisecondsSinceEpoch
          .toString(),
    ].join('|');
    if (notification.notificationKey.trim().isNotEmpty ||
        notification.notificationId != null ||
        notification.tag.trim().isNotEmpty) {
      return stablePlatformKey;
    }

    final normalized = NormalizedNotification.fromPayload(notification);
    return [
      notification.packageName.trim().toLowerCase(),
      detectedTransaction.type.firestoreValue,
      detectedTransaction.amount.toStringAsFixed(2),
      normalized.searchableText.trim().toLowerCase(),
      (notification.postTime ?? notification.receivedAt).millisecondsSinceEpoch,
    ].join('|');
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
${_redactSensitiveNumbers(notification.displayBody)}

Normalized Text
${_redactSensitiveNumbers(result.normalizedNotification.searchableText)}

Result
${result.type.logValue}

Source
${result.source.name}

Type
${result.detectedTransaction?.type.firestoreValue ?? '-'}

Amount
${result.detectedTransaction?.amount.toStringAsFixed(0) ?? '-'}
------------------------------------------------
''', name: 'NotificationFilter');
  }

  String _redactSensitiveNumbers(String value) {
    return value.replaceAll(RegExp(r'\d{4,}'), '[number]');
  }

  static final _amountPattern = RegExp(
    r'\b(IDR|Rp)\s*([0-9]{1,3}(?:(?:[.,][0-9]{3})+)(?:\.[0-9]{2})?|[0-9]+(?:\.[0-9]{2})?)\b',
    caseSensitive: false,
  );

  static const myBcaPackageName = 'com.bca.mybca.omni.android';
}

enum NotificationSource {
  myBca,
  simulator,
  unknown;

  String label(AndroidNotificationPayload notification) {
    return switch (this) {
      NotificationSource.myBca => 'myBCA',
      NotificationSource.simulator =>
        notification.appName.trim().isEmpty
            ? 'Simulator'
            : notification.appName,
      NotificationSource.unknown =>
        notification.appName.trim().isEmpty ? 'Unknown' : notification.appName,
    };
  }
}

class NormalizedNotification {
  const NormalizedNotification({
    required this.packageName,
    required this.searchableText,
    required this.lowerText,
  });

  final String packageName;
  final String searchableText;
  final String lowerText;

  factory NormalizedNotification.fromPayload(
    AndroidNotificationPayload notification,
  ) {
    final parts = <String>[
      notification.title,
      notification.body,
      notification.bigText,
      ...notification.textLines,
      notification.subText,
      notification.ticker,
      ..._interestingExtras(notification.extras),
    ];

    final seen = <String>{};
    final normalizedParts = <String>[];
    for (final part in parts) {
      final normalized = _normalizeText(part);
      if (normalized.isEmpty) {
        continue;
      }
      final comparable = normalized.toLowerCase();
      if (seen.add(comparable)) {
        normalizedParts.add(normalized);
      }
    }

    final searchableText = normalizedParts.join('\n');
    return NormalizedNotification(
      packageName: notification.packageName.trim().toLowerCase(),
      searchableText: searchableText,
      lowerText: searchableText.toLowerCase(),
    );
  }

  static Iterable<String> _interestingExtras(Map<String, String> extras) {
    const interestingKeys = {
      'android.title',
      'android.text',
      'android.bigText',
      'android.subText',
      'android.summaryText',
      'android.infoText',
      'android.textLines',
    };

    return extras.entries
        .where((entry) => interestingKeys.contains(entry.key))
        .map((entry) => entry.value);
  }

  static String _normalizeText(String value) {
    return value
        .replaceAll(RegExp(r'[\u00a0\u2000-\u200b\u202f\u205f\u3000]'), ' ')
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .join('\n')
        .trim();
  }
}
