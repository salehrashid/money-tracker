import '../../../../shared/models/finance_enums.dart';

class CsvImportRow {
  const CsvImportRow({
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

  CsvImportRow copyWith({
    int? rowNumber,
    Map<String, String>? rawData,
    CsvImportRowStatus? status,
    String? transactionDraftId,
    String? errorMessage,
    bool clearTransactionDraftId = false,
    bool clearErrorMessage = false,
  }) {
    return CsvImportRow(
      rowNumber: rowNumber ?? this.rowNumber,
      rawData: rawData ?? this.rawData,
      status: status ?? this.status,
      transactionDraftId: clearTransactionDraftId
          ? null
          : transactionDraftId ?? this.transactionDraftId,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}

class CsvImportBatch {
  const CsvImportBatch({
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
  final List<CsvImportRow> rows;
  final DateTime createdAt;
  final DateTime updatedAt;

  CsvImportBatch copyWith({
    String? id,
    String? fileName,
    CsvImportBatchStatus? status,
    int? totalRows,
    int? validRows,
    int? invalidRows,
    int? duplicateRows,
    List<CsvImportRow>? rows,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CsvImportBatch(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      status: status ?? this.status,
      totalRows: totalRows ?? this.totalRows,
      validRows: validRows ?? this.validRows,
      invalidRows: invalidRows ?? this.invalidRows,
      duplicateRows: duplicateRows ?? this.duplicateRows,
      rows: rows ?? this.rows,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
