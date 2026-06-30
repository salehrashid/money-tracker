import '../../../../shared/models/finance_enums.dart';

class ReceiptOcrResult {
  const ReceiptOcrResult({
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

  ReceiptOcrResult copyWith({
    String? id,
    String? imageStoragePath,
    String? rawText,
    ReceiptOcrStatus? status,
    String? merchantName,
    double? detectedAmount,
    String? detectedCurrency,
    DateTime? receiptDate,
    String? transactionDraftId,
    String? errorMessage,
    double? confidence,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearMerchantName = false,
    bool clearDetectedAmount = false,
    bool clearDetectedCurrency = false,
    bool clearReceiptDate = false,
    bool clearTransactionDraftId = false,
    bool clearErrorMessage = false,
  }) {
    return ReceiptOcrResult(
      id: id ?? this.id,
      imageStoragePath: imageStoragePath ?? this.imageStoragePath,
      rawText: rawText ?? this.rawText,
      status: status ?? this.status,
      merchantName: clearMerchantName
          ? null
          : merchantName ?? this.merchantName,
      detectedAmount: clearDetectedAmount
          ? null
          : detectedAmount ?? this.detectedAmount,
      detectedCurrency: clearDetectedCurrency
          ? null
          : detectedCurrency ?? this.detectedCurrency,
      receiptDate: clearReceiptDate ? null : receiptDate ?? this.receiptDate,
      transactionDraftId: clearTransactionDraftId
          ? null
          : transactionDraftId ?? this.transactionDraftId,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
