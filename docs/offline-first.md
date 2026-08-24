# Offline-first storage and synchronization

Fleeca treats Hive CE as the primary source for user-visible accounts,
categories, transactions, transaction drafts, debts, and notification history. Dashboard and
Statistics already derive their values from those feature streams, so local
mutations update all three surfaces immediately.

Every Hive key is namespaced by Firebase UID, collection, and stable client ID.
The stored envelope contains the entity map, its queue timestamp, and one of
`synced`, `pendingCreate`, `pendingUpdate`, `pendingDelete`, or `syncFailed`.
Pending deletes are tombstones and remain durable until Firestore confirms the
delete. Confirmed deletes remain as compact synchronized tombstones locally and
remotely so delayed snapshots cannot resurrect a record and other devices can
observe the deletion.

The per-user synchronization coordinator is a serialized worker. It refreshes
registered collections, merges remote records into Hive, then processes the
persistent outbox in queue-time and ID order. Firestore writes use the local ID
as the document ID and `set`, making retries idempotent. Network failures use
bounded exponential-backoff retries; authentication and permission failures
stop automatic retrying and are not presented as offline.

Conflicts use last-write-wins with `updatedAt` normalized to UTC. A pending
local create, update, or delete is never overwritten by a remote record. For a
synced record, remote data replaces local data only when its `updatedAt` is at
least as new. This is appropriate for Fleeca's single-user ownership model.

Firestore availability is established by an actual collection operation, not
by link-layer connectivity. The shared app bar reserves a fixed action slot and
shows a compact cloud-off or syncing icon without shifting adjacent actions.
Connectivity changes are observed while the app is running. A ten-second TCP
heartbeat to the Firestore service catches Wi-Fi connections without internet;
recovery is only confirmed after the subsequent Firestore synchronization
succeeds.

Each registered collection also keeps a Firestore listener while reachable.
Remote snapshots are merged into Hive using the same conflict rules, so changes
made on another signed-in device appear through the local stream without making
Firestore the UI source. Listeners are cancelled offline and recreated after
successful reconnection.

Firebase tokens and the last confirmed user identity are kept in platform
secure storage. On process restart, a network failure during Firedart's user
lookup falls back to that identity while the saved token remains present. This
does not apply to revoked, invalid, or explicitly cleared sessions.
