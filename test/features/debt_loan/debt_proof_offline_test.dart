import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:money_tracker/core/offline/offline_database.dart';
import 'package:money_tracker/core/offline/sync_coordinator.dart';
import 'package:money_tracker/core/offline/sync_status.dart';
import 'package:money_tracker/features/debt_loan/data/dto/debt_dto.dart';
import 'package:money_tracker/features/debt_loan/domain/entities/debt.dart';
import 'package:money_tracker/shared/models/finance_enums.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late OfflineDatabase database;
  late LocalFirstCollection<Debt> debts;

  Future<void> openDatabase() async {
    box = await Hive.openBox<dynamic>('debt_records');
    database = OfflineDatabase.forTesting(box);
    debts = LocalFirstCollection<Debt>(
      userId: 'user-a',
      collection: 'debts',
      database: database,
      coordinator: _OfflineSyncCoordinator(),
      fromMap: (map) => DebtDto.fromMap(map).toDomain(),
      toMap: (debt) => DebtDto.fromDomain(debt).toFirestore(),
      idOf: (debt) => debt.id,
      isDeleted: (_) => false,
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('debt_proof_test_');
    Hive.init(directory.path);
    await openDatabase();
  });

  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  test(
    'transfer proof and its pending removal survive offline restart',
    () async {
      final now = DateTime.utc(2026, 9, 1);
      final proof = base64Encode(Uint8List(debtTransferProofMaxBytes));
      final original = Debt(
        id: 'debt-1',
        kind: DebtKind.debt,
        personName: 'Ari',
        amount: 100000,
        currency: 'IDR',
        status: DebtStatus.open,
        note: '',
        createdAt: now,
        updatedAt: now,
        transactionDate: now,
        transferProofBase64: proof,
      );
      await debts.save(original, isCreate: true);

      await box.close();
      await openDatabase();

      expect(debts.current.single.transferProofBase64, proof);
      expect(
        database.records('user-a', 'debts').single.status,
        SyncStatus.pendingCreate,
      );

      await debts.save(
        debts.current.single.copyWith(
          clearTransferProof: true,
          updatedAt: now.add(const Duration(hours: 1)),
        ),
        isCreate: false,
      );
      await database.mergeRemote(
        userId: 'user-a',
        collection: 'debts',
        remote: [DebtDto.fromDomain(original).toFirestore()],
      );

      await box.close();
      await openDatabase();

      final record = database.records('user-a', 'debts').single;
      expect(debts.current.single.transferProofBase64, isNull);
      expect(record.status, SyncStatus.pendingUpdate);
      expect(record.data.containsKey('transferProofBase64'), isTrue);
      expect(record.data['transferProofBase64'], isNull);
    },
  );
}

class _OfflineSyncCoordinator extends Fake implements SyncCoordinator {
  @override
  void register(String collection) {}

  @override
  Future<void> synchronize() async {}
}
