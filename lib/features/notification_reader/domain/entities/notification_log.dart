import '../../../../shared/models/finance_enums.dart';

class NotificationLog {
  const NotificationLog({
    required this.id,
    required this.appName,
    required this.packageName,
    required this.title,
    required this.body,
    required this.detectedType,
    required this.status,
    required this.dedupeHash,
    required this.receivedAt,
    required this.createdAt,
    this.detectedAmount,
  });

  final String id;
  final String appName;
  final String packageName;
  final String title;
  final String body;
  final DetectedTransactionType detectedType;
  final double? detectedAmount;
  final NotificationLogStatus status;
  final String dedupeHash;
  final DateTime receivedAt;
  final DateTime createdAt;

  NotificationLog copyWith({
    String? id,
    String? appName,
    String? packageName,
    String? title,
    String? body,
    DetectedTransactionType? detectedType,
    double? detectedAmount,
    NotificationLogStatus? status,
    String? dedupeHash,
    DateTime? receivedAt,
    DateTime? createdAt,
    bool clearDetectedAmount = false,
  }) {
    return NotificationLog(
      id: id ?? this.id,
      appName: appName ?? this.appName,
      packageName: packageName ?? this.packageName,
      title: title ?? this.title,
      body: body ?? this.body,
      detectedType: detectedType ?? this.detectedType,
      detectedAmount: clearDetectedAmount
          ? null
          : detectedAmount ?? this.detectedAmount,
      status: status ?? this.status,
      dedupeHash: dedupeHash ?? this.dedupeHash,
      receivedAt: receivedAt ?? this.receivedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
