import 'dart:async';

import 'package:firedart/firedart.dart';

import '../errors/app_failure.dart';
import '../errors/firebase_error_mapper.dart';
import '../firebase/firestore_user_collections.dart';
import 'connectivity_watcher.dart';
import 'offline_database.dart';
import 'sync_status.dart';

class SyncCoordinator {
  SyncCoordinator({
    required this.userId,
    required OfflineDatabase database,
    required FirestoreUserCollections collections,
    FirebaseErrorMapper errorMapper = const FirebaseErrorMapper(),
  }) : _database = database,
       _collections = collections,
       _errorMapper = errorMapper {
    _connectivity = ConnectivityWatcher.forFirestore(
      onUnavailable: _handleUnavailable,
      onAvailable: synchronize,
    )..start();
  }

  final String userId;
  final OfflineDatabase _database;
  final FirestoreUserCollections _collections;
  final FirebaseErrorMapper _errorMapper;
  late final ConnectivityWatcher _connectivity;
  final _state = StreamController<RemoteSyncState>.broadcast();
  final Set<String> _registered = {};
  RemoteSyncState currentState = RemoteSyncState.online;
  bool _running = false;
  bool _rerun = false;
  bool _disposed = false;
  int _failures = 0;
  Timer? _retry;
  final Map<String, StreamSubscription<List<Document>>> _remoteSubscriptions =
      {};
  final Map<String, Timer> _listenerRetries = {};

  Stream<RemoteSyncState> get states async* {
    yield currentState;
    yield* _state.stream;
  }

  void register(String collection) {
    if (_registered.add(collection)) {
      _startRemoteListener(collection);
      unawaited(synchronize());
    }
  }

  Future<void> synchronize() async {
    if (_disposed) return;
    if (_running) {
      _rerun = true;
      return;
    }
    _running = true;
    _setState(RemoteSyncState.syncing);
    try {
      do {
        _rerun = false;
        for (final collection in _registered.toList()..sort()) {
          await _syncCollection(collection);
        }
      } while (_rerun);
      _failures = 0;
      _retry?.cancel();
      _setState(RemoteSyncState.online);
      _ensureRemoteListeners();
    } catch (error) {
      _handleRemoteError(error);
    } finally {
      _running = false;
    }
  }

  Future<void> _syncCollection(String collection) async {
    final reference = _collections.collection(collection);
    final documents = await reference.get();
    await _database.mergeRemote(
      userId: userId,
      collection: collection,
      remote: documents.map(
        (document) => {
          ...document.map,
          'id': document.map['id'] ?? document.id,
        },
      ),
    );
    final pending =
        _database
            .records(userId, collection)
            .where((record) => record.status.isPending)
            .toList()
          ..sort((a, b) {
            final time = a.queuedAt.compareTo(b.queuedAt);
            return time != 0 ? time : a.id.compareTo(b.id);
          });
    for (final record in pending) {
      final document = reference.document(record.id);
      if (record.status == SyncStatus.pendingDelete) {
        final deletedAt = DateTime.now().toUtc();
        final tombstone = {
          ...record.data,
          'id': record.id,
          '_syncDeletedAt': deletedAt,
          'serverUpdatedAt': deletedAt,
        };
        await document.set(tombstone);
        await _database.putRecord(
          userId: userId,
          collection: collection,
          id: record.id,
          data: tombstone,
          status: SyncStatus.syncedDelete,
        );
      } else {
        await document.set({
          ...record.data,
          'id': record.id,
          '_syncDeletedAt': null,
          'serverUpdatedAt': DateTime.now().toUtc(),
        });
        await _database.putRecord(
          userId: userId,
          collection: collection,
          id: record.id,
          data: record.data,
          status: SyncStatus.synced,
        );
      }
    }
  }

  void _ensureRemoteListeners() {
    if (_disposed ||
        currentState == RemoteSyncState.offline ||
        currentState == RemoteSyncState.blocked) {
      return;
    }
    for (final collection in _registered) {
      _startRemoteListener(collection);
    }
  }

  void _startRemoteListener(String collection) {
    if (_disposed ||
        currentState == RemoteSyncState.offline ||
        currentState == RemoteSyncState.blocked ||
        _remoteSubscriptions.containsKey(collection)) {
      return;
    }
    _listenerRetries.remove(collection)?.cancel();
    final stream = _collections.collection(collection).stream;
    _remoteSubscriptions[collection] = stream.listen(
      (documents) => unawaited(_handleRemoteSnapshot(collection, documents)),
      onError: (Object error, StackTrace stackTrace) {
        _handleRemoteError(error);
      },
      onDone: () => _remoteListenerDone(collection),
      cancelOnError: false,
    );
  }

  Future<void> _handleRemoteSnapshot(
    String collection,
    List<Document> documents,
  ) async {
    if (_disposed) return;
    await _database.mergeRemote(
      userId: userId,
      collection: collection,
      remote: documents.map(
        (document) => {
          ...document.map,
          'id': document.map['id'] ?? document.id,
        },
      ),
    );
    _failures = 0;
    if (_hasPendingOperations) {
      unawaited(synchronize());
    } else {
      _setState(RemoteSyncState.online);
    }
  }

  bool get _hasPendingOperations => _registered.any(
    (collection) => _database
        .records(userId, collection)
        .any((record) => record.status.isPending),
  );

  void _remoteListenerDone(String collection) {
    _remoteSubscriptions.remove(collection);
    if (_disposed ||
        currentState == RemoteSyncState.offline ||
        currentState == RemoteSyncState.blocked) {
      return;
    }
    _listenerRetries[collection]?.cancel();
    _listenerRetries[collection] = Timer(
      const Duration(seconds: 2),
      () => _startRemoteListener(collection),
    );
  }

  void _handleRemoteError(Object error) {
    if (_disposed) return;
    final failure = _errorMapper.map(error);
    if (failure.type == AppFailureType.network ||
        failure.type == AppFailureType.unavailable) {
      _handleUnavailable();
      _scheduleRetry();
    } else {
      _stopRemoteListeners();
      _setState(RemoteSyncState.blocked);
    }
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _failures++;
    final seconds = (1 << (_failures.clamp(1, 8) - 1)).clamp(2, 300);
    _retry?.cancel();
    _retry = Timer(Duration(seconds: seconds), synchronize);
  }

  void _setState(RemoteSyncState value) {
    if (_disposed || currentState == value) return;
    currentState = value;
    _state.add(value);
  }

  void _handleUnavailable() {
    _retry?.cancel();
    _stopRemoteListeners();
    _setState(RemoteSyncState.offline);
  }

  void _stopRemoteListeners() {
    for (final timer in _listenerRetries.values) {
      timer.cancel();
    }
    _listenerRetries.clear();
    final subscriptions = _remoteSubscriptions.values.toList();
    _remoteSubscriptions.clear();
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _retry?.cancel();
    _stopRemoteListeners();
    unawaited(_connectivity.dispose());
    _state.close();
  }
}

class LocalFirstCollection<T> {
  LocalFirstCollection({
    required this.userId,
    required this.collection,
    required OfflineDatabase database,
    required SyncCoordinator coordinator,
    required this.fromMap,
    required this.toMap,
    required this.idOf,
    required this.isDeleted,
  }) : _database = database,
       _coordinator = coordinator {
    coordinator.register(collection);
  }

  final String userId;
  final String collection;
  final OfflineDatabase _database;
  final SyncCoordinator _coordinator;
  final T Function(Map<String, dynamic>) fromMap;
  final Map<String, dynamic> Function(T) toMap;
  final String Function(T) idOf;
  final bool Function(T) isDeleted;

  List<T> get current => _database
      .records(userId, collection)
      .where(
        (record) =>
            record.status != SyncStatus.pendingDelete &&
            record.status != SyncStatus.syncedDelete,
      )
      .map((record) => fromMap(record.data))
      .where((value) => !isDeleted(value))
      .toList();

  Stream<List<T>> watch() =>
      _database.watch(userId, collection).map((_) => current);

  Future<void> save(T value, {required bool isCreate}) async {
    final id = idOf(value);
    await _database.putRecord(
      userId: userId,
      collection: collection,
      id: id,
      data: toMap(value),
      status: isCreate ? SyncStatus.pendingCreate : SyncStatus.pendingUpdate,
    );
    unawaited(_coordinator.synchronize());
  }

  Future<void> delete(T value) async {
    await _database.putRecord(
      userId: userId,
      collection: collection,
      id: idOf(value),
      data: toMap(value),
      status: SyncStatus.pendingDelete,
    );
    unawaited(_coordinator.synchronize());
  }
}

extension on SyncStatus {
  bool get isPending => switch (this) {
    SyncStatus.synced || SyncStatus.syncedDelete => false,
    _ => true,
  };
}
