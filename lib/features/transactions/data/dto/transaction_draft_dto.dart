import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_model_converters.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/transaction_draft.dart';

class TransactionDraftDto {
  const TransactionDraftDto({
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

  factory TransactionDraftDto.fromDomain(TransactionDraft draft) {
    return TransactionDraftDto(
      id: draft.id,
      draftType: draft.draftType,
      detectedType: draft.detectedType,
      detectedAmount: draft.detectedAmount,
      detectedCurrency: draft.detectedCurrency,
      detectedText: draft.detectedText,
      suggestedCategoryId: draft.suggestedCategoryId,
      status: draft.status,
      confidence: draft.confidence,
      createdAt: draft.createdAt,
      updatedAt: draft.updatedAt,
    );
  }

  factory TransactionDraftDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return TransactionDraftDto.fromMap(
      snapshot.data() ?? const {},
      documentId: snapshot.id,
    );
  }

  factory TransactionDraftDto.fromMap(
    Map<String, dynamic> data, {
    String? documentId,
  }) {
    return TransactionDraftDto(
      id: optionalString(data, 'id') ?? documentId ?? '',
      draftType: TransactionDraftType.fromFirestore(
        requiredString(data, 'draftType'),
      ),
      detectedType: TransactionType.fromFirestore(
        requiredString(data, 'detectedType'),
      ),
      detectedAmount: requiredDouble(data, 'detectedAmount'),
      detectedCurrency: requiredString(data, 'detectedCurrency'),
      detectedText: requiredString(data, 'detectedText'),
      suggestedCategoryId: optionalString(data, 'suggestedCategoryId'),
      status: TransactionDraftStatus.fromFirestore(
        requiredString(data, 'status'),
      ),
      confidence: requiredDouble(data, 'confidence'),
      createdAt: requiredDateTime(data, 'createdAt'),
      updatedAt: requiredDateTime(data, 'updatedAt'),
    );
  }

  TransactionDraft toDomain() {
    return TransactionDraft(
      id: id,
      draftType: draftType,
      detectedType: detectedType,
      detectedAmount: detectedAmount,
      detectedCurrency: detectedCurrency,
      detectedText: detectedText,
      suggestedCategoryId: suggestedCategoryId,
      status: status,
      confidence: confidence,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'draftType': draftType.firestoreValue,
      'detectedType': detectedType.firestoreValue,
      'detectedAmount': detectedAmount,
      'detectedCurrency': detectedCurrency,
      'detectedText': detectedText,
      'suggestedCategoryId': suggestedCategoryId,
      'status': status.firestoreValue,
      'confidence': confidence,
      'createdAt': timestampFromDate(createdAt),
      'updatedAt': timestampFromDate(updatedAt),
    };
  }
}
