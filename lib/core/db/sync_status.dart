/// Local sync lifecycle for offline-written rows (Phase 17 foundation).
///
/// Phase 18 drains `pending` / retries `failed` via `POST /sync/batch`.
enum LocalSyncStatus {
  pending,
  synced,
  failed;

  String get storageValue => name.toUpperCase();

  static LocalSyncStatus fromStorage(String raw) {
    switch (raw.toUpperCase()) {
      case 'SYNCED':
        return LocalSyncStatus.synced;
      case 'FAILED':
        return LocalSyncStatus.failed;
      case 'PENDING':
      default:
        return LocalSyncStatus.pending;
    }
  }
}
