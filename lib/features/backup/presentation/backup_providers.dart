import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/offline_providers.dart';
import '../application/backup_service.dart';

final backupServiceProvider = Provider.family<BackupService, String>((
  ref,
  userId,
) {
  return BackupService(
    database: ref.watch(offlineDatabaseProvider),
    requestSync: ref.watch(syncCoordinatorProvider(userId)).synchronize,
  );
});

final backupFileServiceProvider = Provider<BackupFileService>((ref) {
  return const BackupFileService();
});
