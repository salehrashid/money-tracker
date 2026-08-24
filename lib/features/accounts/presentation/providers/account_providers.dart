import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/offline/offline_providers.dart';
import '../../../../core/offline/sync_coordinator.dart';
import '../../application/usecases/account_use_cases.dart';
import '../../application/usecases/ensure_default_account_use_case.dart';
import '../../data/datasources/firebase_account_data_source.dart';
import '../../data/repositories/firebase_account_repository.dart';
import '../../data/dto/account_dto.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';

final accountDataSourceProvider =
    Provider.family<FirebaseAccountDataSource, String>((ref, userId) {
      return FirebaseAccountDataSource(
        ref.watch(firestoreUserCollectionsProvider(userId)),
      );
    });

final accountRepositoryProvider = Provider.family<AccountRepository, String>((
  ref,
  userId,
) {
  return FirebaseAccountRepository(
    dataSource: ref.watch(accountDataSourceProvider(userId)),
    local: LocalFirstCollection<Account>(
      userId: userId,
      collection: 'accounts',
      database: ref.watch(offlineDatabaseProvider),
      coordinator: ref.watch(syncCoordinatorProvider(userId)),
      fromMap: (map) => AccountDto.fromMap(map).toDomain(),
      toMap: (value) => AccountDto.fromDomain(value).toFirestore(),
      idOf: (value) => value.id,
      isDeleted: (_) => false,
    ),
  );
});

final watchAccountsUseCaseProvider =
    Provider.family<WatchAccountsUseCase, String>((ref, userId) {
      return WatchAccountsUseCase(ref.watch(accountRepositoryProvider(userId)));
    });

final accountListProvider =
    StreamProvider.family<Result<List<Account>>, String>((ref, userId) {
      return ref.watch(watchAccountsUseCaseProvider(userId)).execute();
    });

final ensureDefaultAccountUseCaseProvider =
    Provider.family<EnsureDefaultAccountUseCase, String>((ref, userId) {
      return EnsureDefaultAccountUseCase(
        ref.watch(accountRepositoryProvider(userId)),
      );
    });
