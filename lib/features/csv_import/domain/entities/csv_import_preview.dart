import '../../../../shared/models/finance_enums.dart';

class CsvImportPreview {
  const CsvImportPreview({
    required this.fileName,
    required this.rows,
    required this.createdAt,
  });

  final String fileName;
  final List<CsvImportPreviewRow> rows;
  final DateTime createdAt;

  int get totalRows => rows.length;

  int get validRows =>
      rows.where((row) => row.status == CsvImportRowStatus.valid).length;

  int get invalidRows =>
      rows.where((row) => row.status == CsvImportRowStatus.invalid).length;

  int get duplicateRows =>
      rows.where((row) => row.status == CsvImportRowStatus.duplicate).length;

  bool get hasImportableRows => validRows > 0;
}

class CsvImportPreviewRow {
  const CsvImportPreviewRow({
    required this.rowNumber,
    required this.rawData,
    required this.status,
    this.type,
    this.amount,
    this.transactionDate,
    this.note = '',
    this.errorMessage,
  });

  final int rowNumber;
  final Map<String, String> rawData;
  final CsvImportRowStatus status;
  final TransactionType? type;
  final double? amount;
  final DateTime? transactionDate;
  final String note;
  final String? errorMessage;

  bool get canImport =>
      status == CsvImportRowStatus.valid &&
      type != null &&
      amount != null &&
      transactionDate != null;

  CsvImportPreviewRow copyWith({
    int? rowNumber,
    Map<String, String>? rawData,
    CsvImportRowStatus? status,
    TransactionType? type,
    double? amount,
    DateTime? transactionDate,
    String? note,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return CsvImportPreviewRow(
      rowNumber: rowNumber ?? this.rowNumber,
      rawData: rawData ?? this.rawData,
      status: status ?? this.status,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      transactionDate: transactionDate ?? this.transactionDate,
      note: note ?? this.note,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
