import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_model_converters.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/csv_import_batch.dart';

class CsvImportRowDto {
  const CsvImportRowDto({
    required this.rowNumber,
    required this.rawData,
    required this.status,
    this.transactionDraftId,
    this.errorMessage,
  });

  final int rowNumber;
  final Map<String, String> rawData;
  final CsvImportRowStatus status;
  final String? transactionDraftId;
  final String? errorMessage;

  factory CsvImportRowDto.fromDomain(CsvImportRow row) {
    return CsvImportRowDto(
      rowNumber: row.rowNumber,
      rawData: row.rawData,
      status: row.status,
      transactionDraftId: row.transactionDraftId,
      errorMessage: row.errorMessage,
    );
  }

  factory CsvImportRowDto.fromMap(Map<String, dynamic> data) {
    final rawData = data['rawData'];
    if (rawData is! Map) {
      throw const FormatException('Missing or invalid map field: rawData');
    }

    return CsvImportRowDto(
      rowNumber: requiredInt(data, 'rowNumber'),
      rawData: rawData.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      ),
      status: CsvImportRowStatus.fromFirestore(requiredString(data, 'status')),
      transactionDraftId: optionalString(data, 'transactionDraftId'),
      errorMessage: optionalString(data, 'errorMessage'),
    );
  }

  CsvImportRow toDomain() {
    return CsvImportRow(
      rowNumber: rowNumber,
      rawData: rawData,
      status: status,
      transactionDraftId: transactionDraftId,
      errorMessage: errorMessage,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'rowNumber': rowNumber,
      'rawData': rawData,
      'status': status.firestoreValue,
      'transactionDraftId': transactionDraftId,
      'errorMessage': errorMessage,
    };
  }
}

class CsvImportBatchDto {
  const CsvImportBatchDto({
    required this.id,
    required this.fileName,
    required this.status,
    required this.totalRows,
    required this.validRows,
    required this.invalidRows,
    required this.duplicateRows,
    required this.rows,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String fileName;
  final CsvImportBatchStatus status;
  final int totalRows;
  final int validRows;
  final int invalidRows;
  final int duplicateRows;
  final List<CsvImportRowDto> rows;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CsvImportBatchDto.fromDomain(CsvImportBatch batch) {
    return CsvImportBatchDto(
      id: batch.id,
      fileName: batch.fileName,
      status: batch.status,
      totalRows: batch.totalRows,
      validRows: batch.validRows,
      invalidRows: batch.invalidRows,
      duplicateRows: batch.duplicateRows,
      rows: batch.rows.map(CsvImportRowDto.fromDomain).toList(growable: false),
      createdAt: batch.createdAt,
      updatedAt: batch.updatedAt,
    );
  }

  factory CsvImportBatchDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return CsvImportBatchDto.fromMap(
      snapshot.data() ?? const {},
      documentId: snapshot.id,
    );
  }

  factory CsvImportBatchDto.fromMap(
    Map<String, dynamic> data, {
    String? documentId,
  }) {
    return CsvImportBatchDto(
      id: optionalString(data, 'id') ?? documentId ?? '',
      fileName: requiredString(data, 'fileName'),
      status: CsvImportBatchStatus.fromFirestore(
        requiredString(data, 'status'),
      ),
      totalRows: requiredInt(data, 'totalRows'),
      validRows: requiredInt(data, 'validRows'),
      invalidRows: requiredInt(data, 'invalidRows'),
      duplicateRows: requiredInt(data, 'duplicateRows'),
      rows: optionalMapList(
        data,
        'rows',
      ).map(CsvImportRowDto.fromMap).toList(growable: false),
      createdAt: requiredDateTime(data, 'createdAt'),
      updatedAt: requiredDateTime(data, 'updatedAt'),
    );
  }

  CsvImportBatch toDomain() {
    return CsvImportBatch(
      id: id,
      fileName: fileName,
      status: status,
      totalRows: totalRows,
      validRows: validRows,
      invalidRows: invalidRows,
      duplicateRows: duplicateRows,
      rows: rows.map((row) => row.toDomain()).toList(growable: false),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'fileName': fileName,
      'status': status.firestoreValue,
      'totalRows': totalRows,
      'validRows': validRows,
      'invalidRows': invalidRows,
      'duplicateRows': duplicateRows,
      'rows': rows.map((row) => row.toFirestore()).toList(growable: false),
      'createdAt': timestampFromDate(createdAt),
      'updatedAt': timestampFromDate(updatedAt),
    };
  }
}
