import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:money_tracker/core/offline/offline_database.dart';
import 'package:money_tracker/core/offline/sync_status.dart';
import 'package:money_tracker/features/backup/application/backup_service.dart';
import 'package:money_tracker/features/backup/domain/backup_models.dart';

void main() {
  late Box<dynamic> box;
  late OfflineDatabase database;
  late BackupService service;

  setUp(() async {
    Hive.init(
      '${Directory.systemTemp.path}/fleeca_backup_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    box = await Hive.openBox<dynamic>('backup_test');
    database = OfflineDatabase.forTesting(box);
    service = BackupService(database: database);
  });

  tearDown(() async {
    await box.close();
  });

  test('XLSX round trip preserves IDs, values, and relationships', () async {
    await _seed(database, 'source');
    final original = service.createBackup(
      'source',
      now: DateTime.utc(2026, 9, 5),
    );
    final decoded = service
        .preview(service.encode(original, BackupFileFormat.xlsx), 'backup.xlsx')
        .backup;

    expect(decoded.metadata.format, BackupMetadata.formatIdentifier);
    expect(decoded.datasets['accounts']!.single['id'], 'account-1');
    expect(decoded.datasets['transactions']!.single['accountId'], 'account-1');
    expect(
      decoded.datasets['transactions']!.single['categoryId'],
      'subcategory-1',
    );
    expect(decoded.datasets['transactions']!.single['amount'], 12500.0);
  });

  test(
    'CSV ZIP round trip restores logical records and is idempotent',
    () async {
      await _seed(database, 'source');
      final original = service.createBackup('source');
      final decoded = service
          .preview(
            service.encode(original, BackupFileFormat.csvZip),
            'backup.zip',
          )
          .backup;

      final first = await service.import('target', decoded, ImportMode.merge);
      final second = await service.import('target', decoded, ImportMode.merge);

      expect(first.inserted, 6);
      expect(second.skipped, 6);
      expect(
        database.records('target', 'transactions').single.data['categoryId'],
        'subcategory-1',
      );
      expect(
        database.records('target', 'accounts').single.status,
        SyncStatus.pendingCreate,
      );
    },
  );

  test('invalid relationship is rejected before local data changes', () async {
    await _seed(database, 'source');
    final backup = service.createBackup('source');
    backup.datasets['transactions']!.single['categoryId'] = 'missing';

    expect(
      () => service.preview(
        service.encode(backup, BackupFileFormat.xlsx),
        'backup.xlsx',
      ),
      throwsA(isA<BackupException>()),
    );
    expect(database.records('target', 'transactions'), isEmpty);
  });

  test(
    'orphaned account reference is warned about and safely cleared',
    () async {
      await _seed(database, 'source');
      final backup = service.createBackup('source');
      backup.datasets['transactions']!.single['accountId'] = 'deleted-account';

      final decoded = service.preview(
        service.encode(backup, BackupFileFormat.xlsx),
        'backup.xlsx',
      );
      expect(decoded.warnings.single, contains('missing account'));

      await service.import('target', decoded.backup, ImportMode.merge);
      expect(
        database.records('target', 'transactions').single.data['accountId'],
        isNull,
      );
    },
  );

  test('replace creates tombstones for records absent from backup', () async {
    await _seed(database, 'source');
    await _seed(database, 'target');
    await database.putRecord(
      userId: 'target',
      collection: 'transactions',
      id: 'old',
      data: {
        ...database.records('target', 'transactions').single.data,
        'id': 'old',
      },
      status: SyncStatus.synced,
    );

    await service.import(
      'target',
      service.createBackup('source'),
      ImportMode.replace,
    );

    expect(
      database
          .records('target', 'transactions')
          .firstWhere((row) => row.id == 'old')
          .status,
      SyncStatus.pendingDelete,
    );
  });

  test('legacy loans use createdAt when transactionDate is absent', () async {
    final created = DateTime.utc(2025, 7, 2);
    await database.putRecord(
      userId: 'source',
      collection: 'debts',
      id: 'legacy-loan',
      data: {
        'id': 'legacy-loan',
        'kind': 'receivable',
        'personName': 'B',
        'amount': 75000.0,
        'currency': 'IDR',
        'status': 'open',
        'note': '',
        'transferProofBase64': null,
        'createdAt': created,
        'updatedAt': created,
      },
      status: SyncStatus.synced,
    );

    final backup = service.createBackup('source');
    final decoded = service
        .preview(service.encode(backup, BackupFileFormat.xlsx), 'legacy.xlsx')
        .backup;

    expect(decoded.datasets['loans']!.single['transactionDate'], created);
  });
}

Future<void> _seed(OfflineDatabase database, String userId) async {
  final created = DateTime.utc(2026, 1, 1);
  Future<void> put(String collection, String id, Map<String, dynamic> data) =>
      database.putRecord(
        userId: userId,
        collection: collection,
        id: id,
        data: {'id': id, ...data},
        status: SyncStatus.synced,
      );
  await put('accounts', 'account-1', {
    'name': 'Cash',
    'type': 'cash',
    'currency': 'IDR',
    'initialBalance': 100000.0,
    'openingBalance': 100000.0,
    'isArchived': false,
    'parentAccountId': null,
    'sortOrder': 0,
    'createdAt': created,
    'updatedAt': created,
  });
  await put('categories', 'category-1', {
    'name': 'Food',
    'type': 'expense',
    'icon': 'restaurant',
    'color': 'green',
    'isDefault': false,
    'isArchived': false,
    'parentCategoryId': null,
    'createdAt': created,
    'updatedAt': created,
  });
  await put('categories', 'subcategory-1', {
    'name': 'Lunch',
    'type': 'expense',
    'icon': 'restaurant',
    'color': 'green',
    'isDefault': false,
    'isArchived': false,
    'parentCategoryId': 'category-1',
    'createdAt': created,
    'updatedAt': created,
  });
  await put('transactions', 'transaction-1', {
    'type': 'expense',
    'amount': 12500.0,
    'currency': 'IDR',
    'categoryId': 'subcategory-1',
    'accountId': 'account-1',
    'note': '',
    'source': 'manual',
    'transactionDate': created,
    'createdAt': created,
    'updatedAt': created,
    'deletedAt': null,
  });
  await put('debts', 'debt-1', {
    'kind': 'debt',
    'personName': 'A',
    'amount': 50000.0,
    'currency': 'IDR',
    'status': 'open',
    'transactionDate': created,
    'note': '',
    'transferProofBase64': null,
    'createdAt': created,
    'updatedAt': created,
  });
  await put('settings', 'app', {'financialCycleDay': 25, 'isDarkMode': false});
}
