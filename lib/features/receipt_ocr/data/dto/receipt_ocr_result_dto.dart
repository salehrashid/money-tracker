import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_model_converters.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/receipt_ocr_result.dart';

class ReceiptOcrResultDto {
  const ReceiptOcrResultDto({
    required this.id,
    required this.imageStoragePath,
    required this.rawText,
    required this.status,
    required this.confidence,
    required this.createdAt,
    required this.updatedAt,
    this.merchantName,
    this.detectedAmount,
    this.detectedCurrency,
    this.receiptDate,
    this.transactionDraftId,
    this.errorMessage,
  });

  final String id;
  final String imageStoragePath;
  final String rawText;
  final ReceiptOcrStatus status;
  final String? merchantName;
  final double? detectedAmount;
  final String? detectedCurrency;
  final DateTime? receiptDate;
  final String? transactionDraftId;
  final String? errorMessage;
  final double confidence;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ReceiptOcrResultDto.fromDomain(ReceiptOcrResult result) {
    return ReceiptOcrResultDto(
      id: result.id,
      imageStoragePath: result.imageStoragePath,
      rawText: result.rawText,
      status: result.status,
      merchantName: result.merchantName,
      detectedAmount: result.detectedAmount,
      detectedCurrency: result.detectedCurrency,
      receiptDate: result.receiptDate,
      transactionDraftId: result.transactionDraftId,
      errorMessage: result.errorMessage,
      confidence: result.confidence,
      createdAt: result.createdAt,
      updatedAt: result.updatedAt,
    );
  }

  factory ReceiptOcrResultDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return ReceiptOcrResultDto.fromMap(
      snapshot.data() ?? const {},
      documentId: snapshot.id,
    );
  }

  factory ReceiptOcrResultDto.fromMap(
    Map<String, dynamic> data, {
    String? documentId,
  }) {
    return ReceiptOcrResultDto(
      id: optionalString(data, 'id') ?? documentId ?? '',
      imageStoragePath: requiredString(data, 'imageStoragePath'),
      rawText: requiredString(data, 'rawText'),
      status: ReceiptOcrStatus.fromFirestore(requiredString(data, 'status')),
      merchantName: optionalString(data, 'merchantName'),
      detectedAmount: optionalDouble(data, 'detectedAmount'),
      detectedCurrency: optionalString(data, 'detectedCurrency'),
      receiptDate: optionalDateTime(data, 'receiptDate'),
      transactionDraftId: optionalString(data, 'transactionDraftId'),
      errorMessage: optionalString(data, 'errorMessage'),
      confidence: requiredDouble(data, 'confidence'),
      createdAt: requiredDateTime(data, 'createdAt'),
      updatedAt: requiredDateTime(data, 'updatedAt'),
    );
  }

  ReceiptOcrResult toDomain() {
    return ReceiptOcrResult(
      id: id,
      imageStoragePath: imageStoragePath,
      rawText: rawText,
      status: status,
      merchantName: merchantName,
      detectedAmount: detectedAmount,
      detectedCurrency: detectedCurrency,
      receiptDate: receiptDate,
      transactionDraftId: transactionDraftId,
      errorMessage: errorMessage,
      confidence: confidence,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'imageStoragePath': imageStoragePath,
      'rawText': rawText,
      'status': status.firestoreValue,
      'merchantName': merchantName,
      'detectedAmount': detectedAmount,
      'detectedCurrency': detectedCurrency,
      'receiptDate': receiptDate == null
          ? null
          : timestampFromDate(receiptDate!),
      'transactionDraftId': transactionDraftId,
      'errorMessage': errorMessage,
      'confidence': confidence,
      'createdAt': timestampFromDate(createdAt),
      'updatedAt': timestampFromDate(updatedAt),
    };
  }
}
