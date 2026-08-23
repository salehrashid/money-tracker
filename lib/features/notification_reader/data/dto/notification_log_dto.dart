import 'package:firedart/firedart.dart';

import '../../../../core/firebase/firestore_model_converters.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/notification_log.dart';

class NotificationLogDto {
  const NotificationLogDto({
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

  factory NotificationLogDto.fromDomain(NotificationLog log) {
    return NotificationLogDto(
      id: log.id,
      appName: log.appName,
      packageName: log.packageName,
      title: log.title,
      body: log.body,
      detectedType: log.detectedType,
      detectedAmount: log.detectedAmount,
      status: log.status,
      dedupeHash: log.dedupeHash,
      receivedAt: log.receivedAt,
      createdAt: log.createdAt,
      isRead: log.isRead,
      transactionId: log.transactionId,
      deletedAt: log.deletedAt,
    );
  }

  factory NotificationLogDto.fromFirestore(Document snapshot) {
    return NotificationLogDto.fromMap(snapshot.map, documentId: snapshot.id);
  }

  factory NotificationLogDto.fromMap(
    Map<String, dynamic> data, {
    String? documentId,
  }) {
    return NotificationLogDto(
      id: optionalString(data, 'id') ?? documentId ?? '',
      appName: requiredString(data, 'appName'),
      packageName: requiredString(data, 'packageName'),
      title: requiredString(data, 'title'),
      body: requiredString(data, 'body'),
      detectedType: DetectedTransactionType.fromFirestore(
        requiredString(data, 'detectedType'),
      ),
      detectedAmount: optionalDouble(data, 'detectedAmount'),
      status: NotificationLogStatus.fromFirestore(
        requiredString(data, 'status'),
      ),
      dedupeHash: requiredString(data, 'dedupeHash'),
      receivedAt: requiredDateTime(data, 'receivedAt'),
      createdAt: requiredDateTime(data, 'createdAt'),
      isRead: optionalBool(data, 'isRead') ?? false,
      transactionId: optionalString(data, 'transactionId'),
      deletedAt: optionalDateTime(data, 'deletedAt'),
    );
  }

  NotificationLog toDomain() {
    return NotificationLog(
      id: id,
      appName: appName,
      packageName: packageName,
      title: title,
      body: body,
      detectedType: detectedType,
      detectedAmount: detectedAmount,
      status: status,
      dedupeHash: dedupeHash,
      receivedAt: receivedAt,
      createdAt: createdAt,
      isRead: isRead,
      transactionId: transactionId,
      deletedAt: deletedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'appName': appName,
      'packageName': packageName,
      'title': title,
      'body': body,
      'detectedType': detectedType.firestoreValue,
      'detectedAmount': detectedAmount,
      'status': status.firestoreValue,
      'dedupeHash': dedupeHash,
      'receivedAt': timestampFromDate(receivedAt),
      'createdAt': timestampFromDate(createdAt),
      'isRead': isRead,
      'transactionId': transactionId,
      'deletedAt': deletedAt == null ? null : timestampFromDate(deletedAt!),
    };
  }
}
