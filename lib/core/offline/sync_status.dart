enum SyncStatus {
  synced,
  pendingCreate,
  pendingUpdate,
  pendingDelete,
  syncedDelete,
  syncFailed,
}

enum RemoteSyncState { online, syncing, offline, blocked }
