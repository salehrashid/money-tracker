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
    this.isRead = false,
    this.transactionId,
    this.deletedAt,
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
  final bool isRead;
  final String? transactionId;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isDetected => detectedType != DetectedTransactionType.unknown;
  bool get isProcessed => status == NotificationLogStatus.saved;

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
    bool? isRead,
    String? transactionId,
    DateTime? deletedAt,
    bool clearDetectedAmount = false,
    bool clearTransactionId = false,
    bool clearDeletedAt = false,
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
      isRead: isRead ?? this.isRead,
      transactionId: clearTransactionId
          ? null
          : transactionId ?? this.transactionId,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    );
  }
}
