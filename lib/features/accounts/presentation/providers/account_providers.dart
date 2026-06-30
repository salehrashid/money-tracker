import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/utils/result.dart';
import '../../application/usecases/account_use_cases.dart';
import '../../data/datasources/firebase_account_data_source.dart';
import '../../data/repositories/firebase_account_repository.dart';
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
