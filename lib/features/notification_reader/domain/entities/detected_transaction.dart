import '../../../../shared/models/finance_enums.dart';

class DetectedTransaction {
  const DetectedTransaction({
    required this.type,
    required this.amount,
    required this.originalText,
    required this.detectedAt,
    required this.sourcePackage,
    required this.source,
    this.description,
  });

  final TransactionType type;
  final double amount;
  final String originalText;
  final DateTime detectedAt;
  final String sourcePackage;
  final String source;
  final String? description;

  String get typeValue => type.firestoreValue;

  Map<String, Object?> toNotificationPayload() {
    return {
      'action': 'add_transaction',
      'source': 'mybca_notification',
      'transactionType': type.firestoreValue,
      'amount': amount,
      'description': description,
      'detectedAtMillis': detectedAt.millisecondsSinceEpoch,
      'sourcePackage': sourcePackage,
      'sourceApplication': source,
      'originalText': originalText,
    }..removeWhere((_, value) => value == null);
  }

  factory DetectedTransaction.fromNotificationPayload(
    Map<Object?, Object?> map,
  ) {
    if (map['action'] != 'add_transaction' ||
        map['source'] != 'mybca_notification') {
      throw const FormatException('Unsupported notification action.');
    }

    final transactionType = _readString(map, 'transactionType');
    final amount = _readDouble(map, 'amount');
    final detectedAtMillis = _readInt(map, 'detectedAtMillis');
    if (transactionType.isEmpty || amount == null || amount <= 0) {
      throw const FormatException('Invalid transaction payload.');
    }

    return DetectedTransaction(
      type: TransactionType.fromFirestore(transactionType),
      amount: amount,
      description: _readNullableString(map, 'description'),
      originalText: _readString(map, 'originalText'),
      detectedAt: DateTime.fromMillisecondsSinceEpoch(
        detectedAtMillis ?? DateTime.now().millisecondsSinceEpoch,
      ),
      sourcePackage: _readString(map, 'sourcePackage'),
      source: _readString(map, 'sourceApplication').ifBlank('myBCA'),
    );
  }

  static String _readString(Map<Object?, Object?> map, String key) {
    final value = map[key];
    return value is String ? value : value?.toString() ?? '';
  }

  static String? _readNullableString(Map<Object?, Object?> map, String key) {
    final value = _readString(map, key).trim();
    return value.isEmpty ? null : value;
  }

  static double? _readDouble(Map<Object?, Object?> map, String key) {
    final value = map[key];
    return switch (value) {
      double() => value,
      int() => value.toDouble(),
      String() => double.tryParse(value),
      _ => null,
    };
  }

  static int? _readInt(Map<Object?, Object?> map, String key) {
    final value = map[key];
    return switch (value) {
      int() => value,
      double() => value.toInt(),
      String() => int.tryParse(value),
      _ => null,
    };
  }
}

extension on String {
  String ifBlank(String fallback) => trim().isEmpty ? fallback : this;
}
