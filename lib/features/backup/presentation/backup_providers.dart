import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/offline/offline_providers.dart';
import '../application/backup_service.dart';
import '../application/format_all_data_service.dart';

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

final formatAllDataServiceProvider =
    Provider.family<FormatAllDataService, String>((ref, userId) {
      return FormatAllDataService(
        database: ref.watch(offlineDatabaseProvider),
        collections: ref.watch(firestoreUserCollectionsProvider(userId)),
      );
    });
