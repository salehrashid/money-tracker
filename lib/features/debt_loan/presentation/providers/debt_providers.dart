import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/utils/result.dart';
import '../../application/usecases/debt_use_cases.dart';
import '../../data/datasources/firebase_debt_data_source.dart';
import '../../data/repositories/firebase_debt_repository.dart';
import '../../domain/entities/debt.dart';
import '../../domain/repositories/debt_repository.dart';

final debtDataSourceProvider = Provider.family<FirebaseDebtDataSource, String>((
  ref,
  userId,
) {
  return FirebaseDebtDataSource(
    ref.watch(firestoreUserCollectionsProvider(userId)),
  );
});

final debtRepositoryProvider = Provider.family<DebtRepository, String>((
  ref,
  userId,
) {
  return FirebaseDebtRepository(
    dataSource: ref.watch(debtDataSourceProvider(userId)),
  );
});

final watchDebtsUseCaseProvider = Provider.family<WatchDebtsUseCase, String>((
  ref,
  userId,
) {
  return WatchDebtsUseCase(ref.watch(debtRepositoryProvider(userId)));
});

final createDebtUseCaseProvider = Provider.family<CreateDebtUseCase, String>((
  ref,
  userId,
) {
  return CreateDebtUseCase(ref.watch(debtRepositoryProvider(userId)));
});

final updateDebtUseCaseProvider = Provider.family<UpdateDebtUseCase, String>((
  ref,
  userId,
) {
  return UpdateDebtUseCase(ref.watch(debtRepositoryProvider(userId)));
});

final setDebtStatusUseCaseProvider =
    Provider.family<SetDebtStatusUseCase, String>((ref, userId) {
      return SetDebtStatusUseCase(ref.watch(debtRepositoryProvider(userId)));
    });

final deleteDebtUseCaseProvider = Provider.family<DeleteDebtUseCase, String>((
  ref,
  userId,
) {
  return DeleteDebtUseCase(ref.watch(debtRepositoryProvider(userId)));
});

final debtListProvider = StreamProvider.family<Result<List<Debt>>, String>((
  ref,
  userId,
) {
  return ref.watch(watchDebtsUseCaseProvider(userId)).execute();
});

final debtOperationStateProvider =
    NotifierProvider.autoDispose<DebtOperationNotifier, AsyncValue<void>>(
      DebtOperationNotifier.new,
    );

class DebtOperationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  void setLoading() {
    state = const AsyncLoading();
  }

  void setSuccess() {
    state = const AsyncData(null);
  }

  void setFailure(Object error, StackTrace stackTrace) {
    state = AsyncError(error, stackTrace);
  }
}
