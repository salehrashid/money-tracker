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

  String _prefix(String userId, String collection) => '$userId::$collection::';

  List<OfflineRecord> records(String userId, String collection) {
    final prefix = _prefix(userId, collection);
    return _box.keys
        .whereType<String>()
        .where((key) => key.startsWith(prefix))
        .map(
          (key) => OfflineRecord.fromStored(
            Map<dynamic, dynamic>.from(_box.get(key) as Map),
          ),
        )
        .toList(growable: false);
  }

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
  }) async {
    await _box.put(_key(userId, collection, id), {
      'id': id,
      'data': data,
      'status': status.name,
      'queuedAt': (queuedAt ?? DateTime.now().toUtc()).toIso8601String(),
    });
    _notify(userId, collection);
  }

  Future<void> remove(String userId, String collection, String id) async {
    await _box.delete(_key(userId, collection, id));
    _notify(userId, collection);
  }

  Future<void> mergeRemote({
    required String userId,
    required String collection,
    required Iterable<Map<String, dynamic>> remote,
  }) async {
    final local = {
      for (final item in records(userId, collection)) item.id: item,
    };
    for (final data in remote) {
      final id = data['id'] as String?;
      if (id == null || id.isEmpty) continue;
      final current = local[id];
      if (current != null && current.status != SyncStatus.synced) continue;
      final remoteUpdated = _date(data['updatedAt']);
      final localUpdated = current == null
          ? null
          : _date(current.data['updatedAt']);
      if (localUpdated != null &&
          remoteUpdated != null &&
          localUpdated.isAfter(remoteUpdated)) {
        continue;
      }
      await putRecord(
        userId: userId,
        collection: collection,
        id: id,
        data: data,
        status: data['_syncDeletedAt'] == null
            ? SyncStatus.synced
            : SyncStatus.syncedDelete,
      );
    }
  }

  DateTime? _date(Object? value) => switch (value) {
    DateTime date => date.toUtc(),
    String text => DateTime.tryParse(text)?.toUtc(),
    _ => null,
  };

  void _notify(String userId, String collection) {
    _controllers['$userId::$collection']?.add(null);
  }
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
