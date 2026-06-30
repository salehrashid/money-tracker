import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreUserCollections {
  const FirestoreUserCollections({
    required FirebaseFirestore firestore,
    required String userId,
  }) : _firestore = firestore,
       _userId = userId;

  final FirebaseFirestore _firestore;
  final String _userId;

  DocumentReference<Map<String, dynamic>> get userDocument {
    return _firestore.collection('users').doc(_userId);
  }

  CollectionReference<Map<String, dynamic>> collection(String collectionId) {
    return userDocument.collection(collectionId);
  }

  CollectionReference<Map<String, dynamic>> get accounts {
    return collection('accounts');
  }

  CollectionReference<Map<String, dynamic>> get categories {
    return collection('categories');
  }

  CollectionReference<Map<String, dynamic>> get transactions {
    return collection('transactions');
  }

  CollectionReference<Map<String, dynamic>> get transactionDrafts {
    return collection('transaction_drafts');
  }

  CollectionReference<Map<String, dynamic>> get debts {
    return collection('debts');
  }

  CollectionReference<Map<String, dynamic>> get receiptOcrResults {
    return collection('receipt_ocr_results');
  }

  CollectionReference<Map<String, dynamic>> get notificationLogs {
    return collection('notification_logs');
  }

  CollectionReference<Map<String, dynamic>> get csvImportBatches {
    return collection('csv_import_batches');
  }

  DocumentReference<Map<String, dynamic>> get appSettings {
    return userDocument.collection('settings').doc('app');
  }
}
