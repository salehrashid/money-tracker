import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'sync_status.dart';

class OfflineDatabase {
  OfflineDatabase._(this._box);

  /// Exposes an already-open box for deterministic repository tests.
  OfflineDatabase.forTesting(Box<dynamic> box) : _box = box;

  static OfflineDatabase? _instance;
  static OfflineDatabase get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('OfflineDatabase.initialize() has not completed.');
    }
    return value;
  }

  static Future<void> initialize({String? path}) async {
    if (_instance != null) return;

    if (path != null) {
      Hive.init(path);
    } else if (!kIsWeb) {
      final directory = await getApplicationSupportDirectory();
      Hive.init(directory.path);
    }

    _instance = OfflineDatabase._(await Hive.openBox<dynamic>('offline_data'));
  }

  final Box<dynamic> _box;
  final Map<String, StreamController<void>> _controllers = {};
  // Hive boxes are shared by every user and collection. Keep the records for a
  // collection in memory once they have been read so normal UI refreshes and
  // sync-state checks do not repeatedly walk every key in the box.
  final Map<String, Map<String, OfflineRecord>> _recordsByCollection = {};

  String _prefix(String userId, String collection) => '$userId::$collection::';

  String _collectionKey(String userId, String collection) =>
      '$userId::$collection';

  Map<String, OfflineRecord> _recordsFor(String userId, String collection) {
    final cacheKey = _collectionKey(userId, collection);
    return _recordsByCollection.putIfAbsent(cacheKey, () {
      final prefix = _prefix(userId, collection);
      return {
        for (final key in _box.keys.whereType<String>())
          if (key.startsWith(prefix))
            key.substring(prefix.length): OfflineRecord.fromStored(
              Map<dynamic, dynamic>.from(_box.get(key) as Map),
            ),
      };
    });
  }

  List<OfflineRecord> records(String userId, String collection) {
    return List<OfflineRecord>.unmodifiable(
      _recordsFor(userId, collection).values,
    );
  }

  List<OfflineRecord> pendingRecords(String userId, String collection) =>
      _recordsFor(userId, collection).values
          .where((record) => _isPending(record.status))
          .toList(growable: false);

  bool hasPendingRecords(String userId, String collection) => _recordsFor(
    userId,
    collection,
  ).values.any((record) => _isPending(record.status));

  bool _isPending(SyncStatus status) => switch (status) {
    SyncStatus.synced || SyncStatus.syncedDelete => false,
    _ => true,
  };

  Stream<void> watch(String userId, String collection) async* {
    yield null;
    yield* (_controllers['$userId::$collection'] ??=
            StreamController<void>.broadcast())
        .stream;
  }

  String _key(String userId, String collection, String id) =>
      '${_prefix(userId, collection)}$id';

  Future<void> putRecord({
    required String userId,
    required String collection,
    required String id,
    required Map<String, dynamic> data,
    required SyncStatus status,
    DateTime? queuedAt,
    bool notify = true,
  }) async {
    final storedQueuedAt = (queuedAt ?? DateTime.now().toUtc())
        .toIso8601String();
    await _box.put(_key(userId, collection, id), {
      'id': id,
      'data': data,
      'status': status.name,
      'queuedAt': storedQueuedAt,
    });
    final cached = _recordsByCollection[_collectionKey(userId, collection)];
    cached?[id] = OfflineRecord(
      id: id,
      data: Map<String, dynamic>.from(data),
      status: status,
      queuedAt: DateTime.parse(storedQueuedAt),
    );
    if (notify) _notify(userId, collection);
  }

  Future<void> remove(String userId, String collection, String id) async {
    await _box.delete(_key(userId, collection, id));
    _recordsByCollection[_collectionKey(userId, collection)]?.remove(id);
    _notify(userId, collection);
  }

  /// Removes every locally cached record owned by [userId].
  Future<void> clearUser(String userId) async {
    final prefix = '$userId::';
    final keys = _box.keys
        .whereType<String>()
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    final collections = keys
        .map((key) => key.substring(prefix.length).split('::').first)
        .toSet();

    await _box.deleteAll(keys);
    _recordsByCollection.removeWhere((key, _) => key.startsWith('$userId::'));
    for (final collection in collections) {
      _notify(userId, collection);
    }
  }

  /// Commits a validated backup import in one Hive batch. Imported records are
  /// deliberately marked pending so the existing offline sync pipeline uploads
  /// them when connectivity is available.
  Future<void> commitImport({
    required String userId,
    required Map<String, List<Map<String, dynamic>>> collections,
    required bool replace,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final writes = <String, dynamic>{};

    for (final entry in collections.entries) {
      final existing = {
        for (final record in records(userId, entry.key)) record.id: record,
      };
      final incomingIds = entry.value
          .map((item) => item['id'] as String)
          .toSet();
      if (replace) {
        for (final record in existing.values.where(
          (item) => !incomingIds.contains(item.id),
        )) {
          writes[_key(userId, entry.key, record.id)] = {
            'id': record.id,
            'data': record.data,
            'status': SyncStatus.pendingDelete.name,
            'queuedAt': now,
          };
        }
      }
      for (final data in entry.value) {
        final id = data['id'] as String;
        writes[_key(userId, entry.key, id)] = {
          'id': id,
          'data': data,
          'status': existing.containsKey(id)
              ? SyncStatus.pendingUpdate.name
              : SyncStatus.pendingCreate.name,
          'queuedAt': now,
        };
      }
    }

    await _box.putAll(writes);
    for (final collection in collections.keys) {
      final cached = _recordsByCollection[_collectionKey(userId, collection)];
      if (cached == null) continue;
      final prefix = _prefix(userId, collection);
      for (final entry in writes.entries.where(
        (entry) => entry.key.startsWith(prefix),
      )) {
        cached[entry.key.substring(prefix.length)] = OfflineRecord.fromStored(
          Map<dynamic, dynamic>.from(entry.value as Map),
        );
      }
    }
    for (final collection in collections.keys) {
      _notify(userId, collection);
    }
  }

  Future<void> mergeRemote({
    required String userId,
    required String collection,
    required Iterable<Map<String, dynamic>> remote,
  }) async {
    final local = _recordsFor(userId, collection);
    final writes = <String, dynamic>{};
    final updated = <String, OfflineRecord>{};
    var processed = 0;
    for (final data in remote) {
      processed++;
      final id = data['id'] as String?;
      if (id == null || id.isEmpty) continue;
      final current = local[id];
      if (current != null && current.status != SyncStatus.synced) continue;
      final remoteUpdated = _date(data['updatedAt']);
      final localUpdated = current == null
          ? null
          : _date(current.data['updatedAt']);
      final status = data['_syncDeletedAt'] == null
          ? SyncStatus.synced
          : SyncStatus.syncedDelete;
      if (localUpdated != null &&
          remoteUpdated != null &&
          localUpdated.isAfter(remoteUpdated)) {
        continue;
      }
      // `updatedAt` is the document version used by every synced model. An
      // equal version is already represented locally, so rewriting it would
      // only trigger a list rebuild for an unchanged Firestore snapshot.
      if (localUpdated != null &&
          localUpdated == remoteUpdated &&
          current?.status == status) {
        continue;
      }
      final queuedAt = DateTime.now().toUtc();
      writes[_key(userId, collection, id)] = {
        'id': id,
        'data': data,
        'status': status.name,
        'queuedAt': queuedAt.toIso8601String(),
      };
      updated[id] = OfflineRecord(
        id: id,
        data: Map<String, dynamic>.from(data),
        status: status,
        queuedAt: queuedAt,
      );
      // Hive itself remains on this isolate. Yielding while preparing a large
      // changed snapshot lets rendering and input run before the single,
      // atomic Hive batch is committed.
      if (processed % 50 == 0) await Future<void>.delayed(Duration.zero);
    }
    if (writes.isEmpty) return;
    await _box.putAll(writes);
    local.addAll(updated);
    _notify(userId, collection);
  }

  DateTime? _date(Object? value) => switch (value) {
    DateTime date => date.isUtc ? date : date.toUtc(),
    String text => DateTime.tryParse(text)?.toUtc(),
    _ => null,
  };

  void _notify(String userId, String collection) {
    _controllers['$userId::$collection']?.add(null);
  }

  /// Coalesces a group of writes that deliberately suppressed notifications.
  void notifyCollection(String userId, String collection) =>
      _notify(userId, collection);
}

class OfflineRecord {
  const OfflineRecord({
    required this.id,
    required this.data,
    required this.status,
    required this.queuedAt,
  });

  factory OfflineRecord.fromStored(Map<dynamic, dynamic> value) {
    return OfflineRecord(
      id: value['id'] as String,
      data: Map<String, dynamic>.from(value['data'] as Map),
      status: SyncStatus.values.byName(value['status'] as String),
      queuedAt: DateTime.parse(value['queuedAt'] as String).toUtc(),
    );
  }

  final String id;
  final Map<String, dynamic> data;
  final SyncStatus status;
  final DateTime queuedAt;
}
