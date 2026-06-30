import '../../../../shared/models/finance_enums.dart';

class TransactionDraft {
  const TransactionDraft({
    required this.id,
    required this.draftType,
    required this.detectedType,
    required this.detectedAmount,
    required this.detectedCurrency,
    required this.detectedText,
    required this.status,
    required this.confidence,
    required this.createdAt,
    required this.updatedAt,
    this.suggestedCategoryId,
  });

  final String id;
  final TransactionDraftType draftType;
  final TransactionType detectedType;
  final double detectedAmount;
  final String detectedCurrency;
  final String detectedText;
  final String? suggestedCategoryId;
  final TransactionDraftStatus status;
  final double confidence;
  final DateTime createdAt;
  final DateTime updatedAt;

  TransactionDraft copyWith({
    String? id,
    TransactionDraftType? draftType,
    TransactionType? detectedType,
    double? detectedAmount,
    String? detectedCurrency,
    String? detectedText,
    String? suggestedCategoryId,
    TransactionDraftStatus? status,
    double? confidence,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearSuggestedCategoryId = false,
  }) {
    return TransactionDraft(
      id: id ?? this.id,
      draftType: draftType ?? this.draftType,
      detectedType: detectedType ?? this.detectedType,
      detectedAmount: detectedAmount ?? this.detectedAmount,
      detectedCurrency: detectedCurrency ?? this.detectedCurrency,
      detectedText: detectedText ?? this.detectedText,
      suggestedCategoryId: clearSuggestedCategoryId
          ? null
          : suggestedCategoryId ?? this.suggestedCategoryId,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
