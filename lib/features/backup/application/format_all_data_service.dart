import '../../../core/firebase/firestore_user_collections.dart';
import '../../../core/offline/offline_database.dart';

class FormatAllDataService {
  const FormatAllDataService({
    required OfflineDatabase database,
    required FirestoreUserCollections collections,
  }) : _database = database,
       _collections = collections;

  final OfflineDatabase _database;
  final FirestoreUserCollections _collections;

  static const collectionIds = <String>[
    'accounts',
    'categories',
    'transactions',
    'transaction_drafts',
    'debts',
    'receipt_ocr_results',
    'notification_logs',
    'csv_import_batches',
    'settings',
  ];

  Future<void> format(String userId) async {
    for (final collectionId in collectionIds) {
      final collection = _collections.collection(collectionId);
      final documents = await collection.get();
      for (final document in documents) {
        await collection.document(document.id).delete();
      }
    }

    await _collections.userDocument.delete();
    await _database.clearUser(userId);
  }
}
