import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:money_tracker/core/offline/offline_database.dart';
import 'package:money_tracker/core/offline/sync_status.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late OfflineDatabase database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fleeca_offline_test_');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('records');
    database = OfflineDatabase.forTesting(box);
  });

  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  test(
    'cached records and pending edits survive reopening the database',
    () async {
      await database.putRecord(
        userId: 'user-a',
        collection: 'transactions',
        id: 'transaction-1',
        data: {
          'id': 'transaction-1',
          'updatedAt': DateTime.utc(2026, 8, 23, 10),
          'amount': 42000.0,
        },
        status: SyncStatus.pendingUpdate,
      );

      await box.close();
      box = await Hive.openBox<dynamic>('records');
      database = OfflineDatabase.forTesting(box);

      final restored = database.records('user-a', 'transactions').single;
      expect(restored.data['amount'], 42000.0);
      expect(restored.status, SyncStatus.pendingUpdate);
    },
  );

  test('clearUser removes only records owned by that user', () async {
    await database.putRecord(
      userId: 'user-a',
      collection: 'transactions',
      id: 'transaction-a',
      data: const {'id': 'transaction-a'},
      status: SyncStatus.synced,
    );
    await database.putRecord(
      userId: 'user-b',
      collection: 'transactions',
      id: 'transaction-b',
      data: const {'id': 'transaction-b'},
      status: SyncStatus.synced,
    );

    await database.clearUser('user-a');

    expect(database.records('user-a', 'transactions'), isEmpty);
    expect(database.records('user-b', 'transactions'), hasLength(1));
  });

  test('older remote data cannot replace a newer pending local edit', () async {
    await database.putRecord(
      userId: 'user-a',
      collection: 'transactions',
      id: 'transaction-1',
      data: {
        'id': 'transaction-1',
        'updatedAt': DateTime.utc(2026, 8, 23, 12),
        'amount': 90000.0,
      },
      status: SyncStatus.pendingUpdate,
    );

    await database.mergeRemote(
      userId: 'user-a',
      collection: 'transactions',
      remote: [
        {
          'id': 'transaction-1',
          'updatedAt': DateTime.utc(2026, 8, 23, 9),
          'amount': 10000.0,
        },
      ],
    );

    final record = database.records('user-a', 'transactions').single;
    expect(record.data['amount'], 90000.0);
    expect(record.status, SyncStatus.pendingUpdate);
  });

  test('a pending delete is retained as a durable tombstone', () async {
    await database.putRecord(
      userId: 'user-a',
      collection: 'debts',
      id: 'debt-1',
      data: {'id': 'debt-1', 'updatedAt': DateTime.utc(2026, 8, 23)},
      status: SyncStatus.pendingDelete,
    );

    await database.mergeRemote(
      userId: 'user-a',
      collection: 'debts',
      remote: [
        {'id': 'debt-1', 'updatedAt': DateTime.utc(2026, 8, 22)},
      ],
    );

    expect(
      database.records('user-a', 'debts').single.status,
      SyncStatus.pendingDelete,
    );
  });

  test(
    'a confirmed delete cannot be resurrected by a stale snapshot',
    () async {
      await database.putRecord(
        userId: 'user-a',
        collection: 'transactions',
        id: 'transaction-1',
        data: {
          'id': 'transaction-1',
          'updatedAt': DateTime.utc(2026, 8, 23, 12),
          '_syncDeletedAt': DateTime.utc(2026, 8, 23, 12),
        },
        status: SyncStatus.syncedDelete,
      );

      await database.mergeRemote(
        userId: 'user-a',
        collection: 'transactions',
        remote: [
          {
            'id': 'transaction-1',
            'updatedAt': DateTime.utc(2026, 8, 23, 11),
            'amount': 10000.0,
          },
        ],
      );

      final record = database.records('user-a', 'transactions').single;
      expect(record.status, SyncStatus.syncedDelete);
      expect(record.data['_syncDeletedAt'], isNotNull);
    },
  );

  test('a remote tombstone hides a record on another device', () async {
    await database.mergeRemote(
      userId: 'user-a',
      collection: 'transactions',
      remote: [
        {
          'id': 'transaction-1',
          'updatedAt': DateTime.utc(2026, 8, 23, 12),
          '_syncDeletedAt': DateTime.utc(2026, 8, 23, 12),
        },
      ],
    );

    expect(
      database.records('user-a', 'transactions').single.status,
      SyncStatus.syncedDelete,
    );
  });

  test('records are isolated by Firebase UID', () async {
    for (final user in ['user-a', 'user-b']) {
      await database.putRecord(
        userId: user,
        collection: 'categories',
        id: 'same-id',
        data: {'id': 'same-id', 'name': user},
        status: SyncStatus.synced,
      );
    }

    expect(
      database.records('user-a', 'categories').single.data['name'],
      'user-a',
    );
    expect(
      database.records('user-b', 'categories').single.data['name'],
      'user-b',
    );
  });

  test('pending queries only return unsynchronised records', () async {
    await database.putRecord(
      userId: 'user-a',
      collection: 'transactions',
      id: 'synced',
      data: const {'id': 'synced'},
      status: SyncStatus.synced,
    );
    await database.putRecord(
      userId: 'user-a',
      collection: 'transactions',
      id: 'pending',
      data: const {'id': 'pending'},
      status: SyncStatus.pendingUpdate,
    );

    expect(database.hasPendingRecords('user-a', 'transactions'), isTrue);
    expect(
      database
          .pendingRecords('user-a', 'transactions')
          .map((record) => record.id),
      ['pending'],
    );
  });

  test('merging a remote snapshot emits one collection update', () async {
    var updates = 0;
    final subscription = database
        .watch('user-a', 'transactions')
        .skip(1)
        .listen((_) => updates++);
    await Future<void>.delayed(Duration.zero);

    await database.mergeRemote(
      userId: 'user-a',
      collection: 'transactions',
      remote: [
        {'id': 'one', 'updatedAt': DateTime.utc(2026, 8, 23)},
        {'id': 'two', 'updatedAt': DateTime.utc(2026, 8, 23)},
      ],
    );
    await Future<void>.delayed(Duration.zero);

    expect(updates, 1);
    await subscription.cancel();
  });

  test(
    'an unchanged remote snapshot does not notify local listeners',
    () async {
      final record = {
        'id': 'transaction-1',
        'updatedAt': DateTime.utc(2026, 8, 23),
        'amount': 42000.0,
      };
      await database.mergeRemote(
        userId: 'user-a',
        collection: 'transactions',
        remote: [record],
      );

      var updates = 0;
      final subscription = database
          .watch('user-a', 'transactions')
          .skip(1)
          .listen((_) => updates++);
      await Future<void>.delayed(Duration.zero);

      await database.mergeRemote(
        userId: 'user-a',
        collection: 'transactions',
        remote: [record],
      );
      await Future<void>.delayed(Duration.zero);

      expect(updates, 0);
      await subscription.cancel();
    },
  );

  test('pending queries retain all records in a large queue', () async {
    final queuedAt = DateTime.utc(2026, 8, 23).toIso8601String();
    await box.putAll({
      for (var index = 0; index < 500; index++)
        'user-a::transactions::$index': {
          'id': '$index',
          'data': {'id': '$index'},
          'status': SyncStatus.pendingUpdate.name,
          'queuedAt': queuedAt,
        },
    });

    expect(database.hasPendingRecords('user-a', 'transactions'), isTrue);
    expect(database.pendingRecords('user-a', 'transactions'), hasLength(500));
    // A second lookup uses the collection cache rather than re-reading Hive.
    expect(database.pendingRecords('user-a', 'transactions'), hasLength(500));
  });
}
