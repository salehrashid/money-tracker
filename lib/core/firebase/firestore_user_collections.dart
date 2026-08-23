import 'package:firedart/firedart.dart';

class FirestoreUserCollections {
  const FirestoreUserCollections({
    required Firestore firestore,
    required String userId,
  }) : _firestore = firestore,
       _userId = userId;

  final Firestore _firestore;
  final String _userId;

  String get _validUserId {
    final userId = _userId.trim();
    if (userId.isEmpty) {
      throw StateError('Firestore user collections require a Firebase UID.');
    }
    return userId;
  }

  DocumentReference get userDocument {
    return _firestore.collection('users').document(_validUserId);
  }

  CollectionReference collection(String collectionId) {
    return userDocument.collection(collectionId);
  }

  CollectionReference get accounts {
    return collection('accounts');
  }

  CollectionReference get categories {
    return collection('categories');
  }

  CollectionReference get transactions {
    return collection('transactions');
  }

  CollectionReference get transactionDrafts {
    return collection('transaction_drafts');
  }

  CollectionReference get debts {
    return collection('debts');
  }

  CollectionReference get receiptOcrResults {
    return collection('receipt_ocr_results');
  }

  CollectionReference get notificationLogs {
    return collection('notification_logs');
  }

  CollectionReference get csvImportBatches {
    return collection('csv_import_batches');
  }

  DocumentReference get appSettings {
    return userDocument.collection('settings').document('app');
  }
}
