import 'package:csv/csv.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../domain/entities/csv_import_preview.dart';

class CsvImportService {
  const CsvImportService();

  Result<CsvImportPreview> buildPreview({
    required String fileName,
    required String content,
    required List<TransactionEntity> existingTransactions,
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const Failure(
        AppFailure(
          type: AppFailureType.validation,
          code: 'empty-csv-file',
          message: 'Choose a CSV file with at least one transaction row.',
        ),
      );
    }

    final table = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(trimmed);
    if (table.length < 2) {
      return const Failure(
        AppFailure(
          type: AppFailureType.validation,
          code: 'missing-csv-rows',
          message: 'The CSV file needs a header and at least one data row.',
        ),
      );
    }

    final headers = table.first.map((value) => value.toString()).toList();
    final normalizedHeaders = headers.map(_normalizeHeader).toList();
    if (!_hasAny(normalizedHeaders, _dateHeaders) ||
        !_hasAny(normalizedHeaders, _amountHeaders)) {
      return const Failure(
        AppFailure(
          type: AppFailureType.validation,
          code: 'missing-required-csv-columns',
          message: 'CSV must include date and amount columns.',
        ),
      );
    }

    final existingKeys = existingTransactions.map(_transactionKey).toSet();
    final seenKeys = <String>{};
    final rows = <CsvImportPreviewRow>[];

    for (var index = 1; index < table.length; index++) {
      final values = table[index];
      if (values.every((value) => value.toString().trim().isEmpty)) {
        continue;
      }

      final rawData = <String, String>{};
      for (var headerIndex = 0; headerIndex < headers.length; headerIndex++) {
        rawData[headers[headerIndex]] = headerIndex < values.length
            ? values[headerIndex].toString().trim()
            : '';
      }

      final row = _parseRow(index + 1, rawData, normalizedHeaders, headers);
      if (!row.canImport) {
        rows.add(row);
        continue;
      }

      final key = _previewKey(row);
      if (existingKeys.contains(key) || seenKeys.contains(key)) {
        rows.add(
          row.copyWith(
            status: CsvImportRowStatus.duplicate,
            errorMessage:
                'This transaction already exists or repeats in the file.',
          ),
        );
        continue;
      }

      seenKeys.add(key);
      rows.add(row);
    }

    if (rows.isEmpty) {
      return const Failure(
        AppFailure(
          type: AppFailureType.validation,
          code: 'empty-csv-data',
          message: 'No transaction rows were found in the CSV file.',
        ),
      );
    }

    return Success(
      CsvImportPreview(
        fileName: fileName,
        rows: rows,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  CsvImportPreviewRow _parseRow(
    int rowNumber,
    Map<String, String> rawData,
    List<String> normalizedHeaders,
    List<String> headers,
  ) {
    final dateText = _valueFor(
      rawData,
      normalizedHeaders,
      headers,
      _dateHeaders,
    );
    final amountText = _valueFor(
      rawData,
      normalizedHeaders,
      headers,
      _amountHeaders,
    );
    final typeText = _valueFor(
      rawData,
      normalizedHeaders,
      headers,
      _typeHeaders,
    );
    final note = _valueFor(rawData, normalizedHeaders, headers, _noteHeaders);

    final date = _parseDate(dateText);
    final amount = _parseAmount(amountText);
    final type = _parseType(typeText, amount);

    if (date == null) {
      return CsvImportPreviewRow(
        rowNumber: rowNumber,
        rawData: rawData,
        status: CsvImportRowStatus.invalid,
        amount: amount?.abs(),
        type: type,
        note: note,
        errorMessage: 'Enter a valid date.',
      );
    }
    if (amount == null || amount == 0) {
      return CsvImportPreviewRow(
        rowNumber: rowNumber,
        rawData: rawData,
        status: CsvImportRowStatus.invalid,
        transactionDate: date,
        type: type,
        note: note,
        errorMessage: 'Enter a valid amount.',
      );
    }
    if (type == null) {
      return CsvImportPreviewRow(
        rowNumber: rowNumber,
        rawData: rawData,
        status: CsvImportRowStatus.invalid,
        transactionDate: date,
        amount: amount.abs(),
        note: note,
        errorMessage: 'Enter income or expense in the type column.',
      );
    }

    return CsvImportPreviewRow(
      rowNumber: rowNumber,
      rawData: rawData,
      status: CsvImportRowStatus.valid,
      type: type,
      amount: amount.abs(),
      transactionDate: date,
      note: note,
    );
  }
}

const _dateHeaders = {'date', 'transactiondate', 'tanggal', 'waktu'};
const _amountHeaders = {'amount', 'nominal', 'jumlah', 'value'};
const _typeHeaders = {'type', 'transactiontype', 'jenis'};
const _noteHeaders = {'note', 'description', 'memo', 'keterangan', 'desc'};

bool _hasAny(List<String> headers, Set<String> candidates) {
  return headers.any(candidates.contains);
}

String _valueFor(
  Map<String, String> rawData,
  List<String> normalizedHeaders,
  List<String> headers,
  Set<String> candidates,
) {
  final index = normalizedHeaders.indexWhere(candidates.contains);
  if (index == -1) {
    return '';
  }

  return rawData[headers[index]]?.trim() ?? '';
}

String _normalizeHeader(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

DateTime? _parseDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final isoDate = DateTime.tryParse(trimmed);
  if (isoDate != null) {
    return DateTime.utc(isoDate.year, isoDate.month, isoDate.day);
  }

  final parts = trimmed.split(RegExp(r'[-/.]'));
  if (parts.length != 3) {
    return null;
  }

  final first = int.tryParse(parts[0]);
  final second = int.tryParse(parts[1]);
  final third = int.tryParse(parts[2]);
  if (first == null || second == null || third == null) {
    return null;
  }

  final year = parts[0].length == 4 ? first : third;
  final month = parts[0].length == 4 ? second : second;
  final day = parts[0].length == 4 ? third : first;
  if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }

  return DateTime.utc(year, month, day);
}

double? _parseAmount(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final cleaned = trimmed
      .replaceAll(RegExp(r'[^0-9,.\-]'), '')
      .replaceAll('.', '')
      .replaceAll(',', '.');
  return double.tryParse(cleaned);
}

TransactionType? _parseType(String value, double? amount) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty && amount != null) {
    return amount < 0 ? TransactionType.expense : TransactionType.income;
  }

  return switch (normalized) {
    'income' || 'credit' || 'kredit' || 'masuk' => TransactionType.income,
    'expense' || 'debit' || 'debet' || 'keluar' => TransactionType.expense,
    _ => null,
  };
}

String _transactionKey(TransactionEntity transaction) {
  final date = transaction.transactionDate.toUtc();
  return [
    date.year,
    date.month,
    date.day,
    transaction.type.firestoreValue,
    transaction.amount.abs().toStringAsFixed(2),
    transaction.note.trim().toLowerCase(),
  ].join('|');
}

String _previewKey(CsvImportPreviewRow row) {
  final date = row.transactionDate!.toUtc();
  return [
    date.year,
    date.month,
    date.day,
    row.type!.firestoreValue,
    row.amount!.abs().toStringAsFixed(2),
    row.note.trim().toLowerCase(),
  ].join('|');
}
