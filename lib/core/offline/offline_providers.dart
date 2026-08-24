import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import 'offline_database.dart';
import 'sync_coordinator.dart';
import 'sync_status.dart';

final offlineDatabaseProvider = Provider<OfflineDatabase>((ref) {
  return OfflineDatabase.instance;
});

final syncCoordinatorProvider = Provider.family<SyncCoordinator, String>((
  ref,
  userId,
) {
  final coordinator = SyncCoordinator(
    userId: userId,
    database: ref.watch(offlineDatabaseProvider),
    collections: ref.watch(firestoreUserCollectionsProvider(userId)),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final remoteSyncStateProvider = StreamProvider.family<RemoteSyncState, String>((
  ref,
  userId,
) {
  return ref.watch(syncCoordinatorProvider(userId)).states;
});
