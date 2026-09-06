import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../../core/offline/offline_database.dart';
import '../../../core/offline/sync_status.dart';
import '../../accounts/data/dto/account_dto.dart';
import '../../categories/data/dto/category_dto.dart';
import '../../debt_loan/data/dto/debt_dto.dart';
import '../../settings/data/dto/financial_settings_dto.dart';
import '../../transactions/data/dto/transaction_dto.dart';
import '../data/backup_codec.dart';
import '../domain/backup_models.dart';

class BackupService {
  BackupService({
    required OfflineDatabase database,
    BackupCodec codec = const BackupCodec(),
    Future<void> Function()? requestSync,
  }) : _database = database,
       _codec = codec,
       _requestSync = requestSync;

  static const appVersion = '1.6.0+4';
  final OfflineDatabase _database;
  final BackupCodec _codec;
  final Future<void> Function()? _requestSync;

  FleecaBackup createBackup(String userId, {DateTime? now}) {
    final accounts = _active(userId, 'accounts').map(_accountMap).toList();
    final allCategories = _active(
      userId,
      'categories',
    ).map(_categoryMap).toList();
    final allDebts = _active(userId, 'debts').map(_debtMap).toList();
    return FleecaBackup(
      metadata: BackupMetadata(
        appName: 'Fleeca',
        format: BackupMetadata.formatIdentifier,
        schemaVersion: BackupMetadata.currentSchemaVersion,
        appVersion: appVersion,
        exportedAt: (now ?? DateTime.now()).toUtc(),
        platform: Platform.operatingSystem,
      ),
      datasets: {
        'accounts': accounts,
        'categories': allCategories
            .where((row) => row['parentCategoryId'] == null)
            .toList(),
        'subcategories': allCategories
            .where((row) => row['parentCategoryId'] != null)
            .toList(),
        'transactions': _active(
          userId,
          'transactions',
        ).map(_transactionMap).toList(),
        'debts': allDebts.where((row) => row['kind'] == 'debt').toList(),
        'loans': allDebts.where((row) => row['kind'] == 'receivable').toList(),
        'settings': _active(userId, 'settings').map(_settingsMap).toList(),
      },
    );
  }

  Uint8List encode(FleecaBackup backup, BackupFileFormat format) =>
      switch (format) {
        BackupFileFormat.xlsx => _codec.encodeXlsx(backup),
        BackupFileFormat.csvZip => _codec.encodeCsvZip(backup),
      };

  Uint8List encodeTransactions(FleecaBackup backup) =>
      _codec.encodeTransactions(backup);

  BackupPreview preview(Uint8List bytes, String fileName) {
    final lower = fileName.toLowerCase();
    final backup = lower.endsWith('.xlsx')
        ? _codec.decodeXlsx(bytes)
        : lower.endsWith('.zip')
        ? _codec.decodeCsvZip(bytes)
        : throw const BackupException(
            'Choose a Fleeca .xlsx or .zip backup file.',
          );
    _validate(backup);
    final warnings = <String>[];
    if (backup.metadata.schemaVersion < BackupMetadata.currentSchemaVersion) {
      warnings.add(
        'This backup uses an older schema and will be migrated during import.',
      );
    }
    return BackupPreview(backup: backup, warnings: warnings);
  }

  Future<ImportResult> import(
    String userId,
    FleecaBackup backup,
    ImportMode mode,
  ) async {
    _validate(backup);
    final incoming = _collections(backup);
    var inserted = 0;
    var updated = 0;
    var skipped = 0;
    final planned = <String, List<Map<String, dynamic>>>{};
    for (final entry in incoming.entries) {
      final existing = {
        for (final row in _active(userId, entry.key)) row.id: row,
      };
      final rows = <Map<String, dynamic>>[];
      for (final row in entry.value) {
        final current = existing[row['id']];
        if (current == null) {
          inserted++;
          rows.add(row);
        } else if (mode == ImportMode.replace ||
            _isImportedNewer(row, current.data)) {
          updated++;
          rows.add(row);
        } else {
          skipped++;
        }
      }
      planned[entry.key] = rows;
    }
    await _database.commitImport(
      userId: userId,
      collections: planned,
      replace: mode == ImportMode.replace,
    );
    final requestSync = _requestSync;
    if (requestSync != null) {
      unawaited(requestSync());
    }
    return ImportResult(inserted: inserted, updated: updated, skipped: skipped);
  }

  List<OfflineRecord> _active(String userId, String collection) => _database
      .records(userId, collection)
      .where(
        (row) =>
            row.status != SyncStatus.pendingDelete &&
            row.status != SyncStatus.syncedDelete,
      )
      .toList();

  Map<String, List<Map<String, dynamic>>> _collections(FleecaBackup backup) => {
    'accounts': [...?backup.datasets['accounts']],
    'categories': [
      ...?backup.datasets['categories'],
      ...?backup.datasets['subcategories'],
    ],
    'debts': [...?backup.datasets['debts'], ...?backup.datasets['loans']],
    'transactions': [...?backup.datasets['transactions']],
    'settings': [...?backup.datasets['settings']],
  };

  bool _isImportedNewer(
    Map<String, dynamic> imported,
    Map<String, dynamic> local,
  ) {
    final importedAt = imported['updatedAt'];
    final localAt = local['updatedAt'];
    if (importedAt is DateTime && localAt is DateTime)
      return importedAt.isAfter(localAt);
    return false;
  }

  void _validate(FleecaBackup backup) {
    final collections = _collections(backup);
    for (final entry in collections.entries) {
      final ids = <String>{};
      for (final row in entry.value) {
        final id = row['id'];
        if (id is! String || id.trim().isEmpty)
          throw BackupException(
            '${entry.key} contains a record without an ID.',
          );
        if (!ids.add(id))
          throw BackupException(
            '${entry.key} contains the duplicate ID "$id".',
          );
        try {
          switch (entry.key) {
            case 'accounts':
              AccountDto.fromMap(row);
              break;
            case 'categories':
              CategoryDto.fromMap(row);
              break;
            case 'transactions':
              TransactionDto.fromMap(row);
              break;
            case 'debts':
              DebtDto.fromMap(row);
              break;
            case 'settings':
              FinancialSettingsDto.fromMap(row);
              break;
          }
        } catch (_) {
          throw BackupException(
            '${entry.key} contains an invalid record ($id). No data has been changed.',
          );
        }
      }
    }
    final accountIds = collections['accounts']!.map((row) => row['id']).toSet();
    final categoryIds = collections['categories']!
        .map((row) => row['id'])
        .toSet();
    for (final account in collections['accounts']!) {
      final parent = account['parentAccountId'];
      if (parent != null && !accountIds.contains(parent))
        throw BackupException(
          'Account ${account['id']} references a missing parent account.',
        );
    }
    for (final category in collections['categories']!) {
      final parent = category['parentCategoryId'];
      if (parent != null && !categoryIds.contains(parent))
        throw BackupException(
          'Subcategory ${category['id']} references a missing category.',
        );
    }
    for (final transaction in collections['transactions']!) {
      final account = transaction['accountId'];
      if (account != null && !accountIds.contains(account))
        throw BackupException(
          'Transaction ${transaction['id']} references a missing account.',
        );
      if (!categoryIds.contains(transaction['categoryId']))
        throw BackupException(
          'Transaction ${transaction['id']} references a missing category.',
        );
    }
  }

  Map<String, dynamic> _accountMap(OfflineRecord row) {
    final result = Map<String, dynamic>.from(row.data);
    result['id'] = row.id;
    result['initialBalance'] =
        result['initialBalance'] ?? result['openingBalance'] ?? 0.0;
    return result;
  }

  Map<String, dynamic> _categoryMap(OfflineRecord row) => {
    ...row.data,
    'id': row.id,
  };
  Map<String, dynamic> _transactionMap(OfflineRecord row) => {
    ...row.data,
    'id': row.id,
  };
  Map<String, dynamic> _debtMap(OfflineRecord row) {
    // Debt records created before transactionDate was introduced use
    // createdAt as their domain-level fallback. Materialize that fallback in
    // the backup so the required, stable schema remains valid.
    final result = Map<String, dynamic>.from(row.data);
    result['id'] = row.id;
    result['transactionDate'] =
        result['transactionDate'] ?? result['createdAt'];
    return result;
  }

  Map<String, dynamic> _settingsMap(OfflineRecord row) => {
    ...row.data,
    'id': row.id,
  };
}

class BackupFileService {
  const BackupFileService();

  Future<String?> save(
    Uint8List bytes,
    String fileName,
    String extension,
  ) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Fleeca data',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );
    if (path != null && !Platform.isAndroid && !Platform.isIOS)
      await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<({Uint8List bytes, String name})?> pickBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'zip'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return null;
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null)
      throw const BackupException('Unable to read the selected backup file.');
    return (bytes: bytes, name: file.name);
  }
}
