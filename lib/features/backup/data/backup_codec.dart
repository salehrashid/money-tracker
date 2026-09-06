import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../domain/backup_models.dart';
import '../domain/backup_schema.dart';

class BackupCodec {
  const BackupCodec();

  Uint8List encodeXlsx(FleecaBackup backup) {
    final book = Excel.createExcel();
    final defaultSheet = book.getDefaultSheet();
    if (defaultSheet != null) book.rename(defaultSheet, 'metadata');
    _writeMetadata(book['metadata'], backup.metadata, backup.datasets);
    for (final schema in backupDatasets) {
      _writeDataset(
        book[schema.name],
        schema,
        backup.datasets[schema.name] ?? const [],
      );
    }
    return Uint8List.fromList(book.encode()!);
  }

  Uint8List encodeCsvZip(FleecaBackup backup) {
    final archive = Archive();
    void add(String name, List<List<dynamic>> rows) {
      final bytes = utf8.encode(const ListToCsvConverter().convert(rows));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add('metadata.csv', _metadataRows(backup.metadata, backup.datasets));
    for (final schema in backupDatasets) {
      add(
        '${schema.name}.csv',
        _datasetRows(schema, backup.datasets[schema.name] ?? const []),
      );
    }
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  Uint8List encodeTransactions(FleecaBackup backup) {
    final book = Excel.createExcel();
    final defaultSheet = book.getDefaultSheet();
    if (defaultSheet != null) book.rename(defaultSheet, 'transactions');
    final sheet = book['transactions'];
    sheet.appendRow(
      [
        'Date',
        'Type',
        'Amount',
        'Currency',
        'Account',
        'Category',
        'Subcategory',
        'Description',
      ].map(_cell).toList(),
    );
    final accounts = {
      for (final row in backup.datasets['accounts'] ?? const [])
        row['id']: row['name'],
    };
    final categories = {
      for (final row in backup.datasets['categories'] ?? const [])
        row['id']: row['name'],
    };
    final subcategories = {
      for (final row in backup.datasets['subcategories'] ?? const [])
        row['id']: row['name'],
    };
    for (final row in backup.datasets['transactions'] ?? const []) {
      final categoryId = row['categoryId'];
      sheet.appendRow(
        [
          _externalValue(row['transactionDate'], BackupValueType.date),
          row['type'],
          row['amount'],
          row['currency'],
          accounts[row['accountId']] ?? '',
          categories[categoryId] ??
              categories[_parentOf(categoryId, backup)] ??
              '',
          subcategories[categoryId] ?? '',
          row['note'] ?? '',
        ].map(_cell).toList(),
      );
    }
    return Uint8List.fromList(book.encode()!);
  }

  Object? _parentOf(Object? categoryId, FleecaBackup backup) {
    for (final row in backup.datasets['subcategories'] ?? const []) {
      if (row['id'] == categoryId) return row['parentCategoryId'];
    }
    return null;
  }

  FleecaBackup decodeXlsx(Uint8List bytes) {
    try {
      final book = Excel.decodeBytes(bytes);
      final metadata = _parseMetadata(_xlsxRows(book.tables['metadata']));
      return FleecaBackup(
        metadata: metadata,
        datasets: {
          for (final schema in backupDatasets)
            schema.name: _parseDataset(
              schema,
              _xlsxRows(book.tables[schema.name]),
            ),
        },
      );
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException(
        'The selected XLSX file is damaged or is not a Fleeca backup.',
      );
    }
  }

  FleecaBackup decodeCsvZip(Uint8List bytes) {
    try {
      final files = <String, List<List<dynamic>>>{};
      for (final file
          in ZipDecoder()
              .decodeBytes(bytes)
              .files
              .where((item) => item.isFile)) {
        final content = utf8.decode(file.content as List<int>);
        files[file.name.split('/').last] = const CsvToListConverter(
          shouldParseNumbers: false,
        ).convert(content);
      }
      final metadata = _parseMetadata(files['metadata.csv']);
      return FleecaBackup(
        metadata: metadata,
        datasets: {
          for (final schema in backupDatasets)
            schema.name: _parseDataset(schema, files['${schema.name}.csv']),
        },
      );
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException(
        'The selected ZIP file is damaged or is not a Fleeca CSV backup.',
      );
    }
  }

  void _writeMetadata(
    Sheet sheet,
    BackupMetadata metadata,
    Map<String, List<Map<String, dynamic>>> datasets,
  ) {
    for (final row in _metadataRows(metadata, datasets)) {
      sheet.appendRow(row.map(_cell).toList());
    }
  }

  List<List<dynamic>> _metadataRows(
    BackupMetadata metadata,
    Map<String, List<Map<String, dynamic>>> datasets,
  ) => [
    ['key', 'value'],
    ['app_name', metadata.appName],
    ['backup_format', metadata.format],
    ['schema_version', metadata.schemaVersion],
    ['app_version', metadata.appVersion],
    ['exported_at', metadata.exportedAt.toIso8601String()],
    ['platform', metadata.platform],
    for (final entry in datasets.entries)
      ['count_${entry.key}', entry.value.length],
  ];

  void _writeDataset(
    Sheet sheet,
    BackupDataset schema,
    List<Map<String, dynamic>> records,
  ) {
    for (final row in _datasetRows(schema, records)) {
      sheet.appendRow(row.map(_cell).toList());
    }
  }

  List<List<dynamic>> _datasetRows(
    BackupDataset schema,
    List<Map<String, dynamic>> records,
  ) => [
    schema.fields.map((field) => field.column).toList(),
    for (final record in records)
      schema.fields
          .map((field) => _externalValue(record[field.key], field.type))
          .toList(),
  ];

  dynamic _externalValue(Object? value, BackupValueType type) {
    if (value == null) return '';
    if (type == BackupValueType.date && value is DateTime) {
      return value.toIso8601String();
    }
    return value;
  }

  CellValue? _cell(dynamic value) => switch (value) {
    null => null,
    int value => IntCellValue(value),
    double value => DoubleCellValue(value),
    bool value => BoolCellValue(value),
    _ => TextCellValue(value.toString()),
  };

  List<List<dynamic>>? _xlsxRows(Sheet? sheet) => sheet?.rows
      .map((row) => row.map((cell) => _rawCell(cell?.value)).toList())
      .toList();

  dynamic _rawCell(CellValue? cell) => switch (cell) {
    null => '',
    IntCellValue(:final value) => value,
    DoubleCellValue(:final value) => value,
    BoolCellValue(:final value) => value,
    _ => cell.toString(),
  };

  BackupMetadata _parseMetadata(List<List<dynamic>>? rows) {
    if (rows == null || rows.length < 2) {
      throw const BackupException(
        'This file does not contain Fleeca backup metadata.',
      );
    }
    final values = <String, String>{
      for (final row in rows.skip(1).where((row) => row.length >= 2))
        row[0].toString(): row[1].toString(),
    };
    if (values['backup_format'] != BackupMetadata.formatIdentifier ||
        values['app_name'] != 'Fleeca') {
      throw const BackupException('The selected file is not a Fleeca backup.');
    }
    final version = int.tryParse(values['schema_version'] ?? '');
    if (version == null)
      throw const BackupException('The backup schema version is invalid.');
    if (version > BackupMetadata.currentSchemaVersion) {
      throw const BackupException(
        'This backup was created by a newer Fleeca version. Update Fleeca before importing it.',
      );
    }
    final exportedAt = DateTime.tryParse(values['exported_at'] ?? '');
    if (exportedAt == null)
      throw const BackupException('The backup export date is invalid.');
    return BackupMetadata(
      appName: 'Fleeca',
      format: BackupMetadata.formatIdentifier,
      schemaVersion: version,
      appVersion: values['app_version'] ?? 'unknown',
      exportedAt: exportedAt,
      platform: values['platform'] ?? 'unknown',
    );
  }

  List<Map<String, dynamic>> _parseDataset(
    BackupDataset schema,
    List<List<dynamic>>? rows,
  ) {
    if (rows == null || rows.isEmpty) {
      throw BackupException(
        'The backup is missing the required ${schema.name} dataset.',
      );
    }
    final headers = rows.first.map((value) => value.toString().trim()).toList();
    for (final field in schema.fields.where((item) => item.required)) {
      if (!headers.contains(field.column)) {
        throw BackupException(
          'The ${schema.name} dataset is missing the required ${field.column} column.',
        );
      }
    }
    final output = <Map<String, dynamic>>[];
    for (var index = 1; index < rows.length; index++) {
      if (rows[index].every((value) => value.toString().trim().isEmpty))
        continue;
      final record = <String, dynamic>{};
      for (final field in schema.fields) {
        final position = headers.indexOf(field.column);
        final raw = position >= 0 && position < rows[index].length
            ? rows[index][position]
            : '';
        record[field.key] = _parseValue(raw, field, schema.name, index + 1);
      }
      output.add(record);
    }
    return output;
  }

  dynamic _parseValue(dynamic raw, BackupField field, String dataset, int row) {
    if (raw == null || raw.toString().trim().isEmpty) {
      if (field.required)
        throw BackupException('$dataset row $row has no ${field.column}.');
      return null;
    }
    final value = raw.toString().trim();
    try {
      return switch (field.type) {
        BackupValueType.text => value,
        BackupValueType.number =>
          raw is num ? raw.toDouble() : double.parse(value),
        BackupValueType.integer => raw is num ? raw.toInt() : int.parse(value),
        BackupValueType.boolean => raw is bool ? raw : _parseBool(value),
        BackupValueType.date => DateTime.parse(value),
      };
    } catch (_) {
      throw BackupException(
        '$dataset row $row contains an invalid ${field.column}.',
      );
    }
  }

  bool _parseBool(String value) {
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;
    throw const FormatException();
  }
}
