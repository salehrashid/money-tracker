import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/utils/result.dart';
import '../../application/usecases/category_use_cases.dart';
import '../../data/datasources/firebase_category_data_source.dart';
import '../../data/repositories/firebase_category_repository.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';

final categoryDataSourceProvider =
    Provider.family<FirebaseCategoryDataSource, String>((ref, userId) {
      return FirebaseCategoryDataSource(
        ref.watch(firestoreUserCollectionsProvider(userId)),
      );
    });

final categoryRepositoryProvider = Provider.family<CategoryRepository, String>((
  ref,
  userId,
) {
  return FirebaseCategoryRepository(
    dataSource: ref.watch(categoryDataSourceProvider(userId)),
  );
});

final watchCategoriesUseCaseProvider =
    Provider.family<WatchCategoriesUseCase, String>((ref, userId) {
      return WatchCategoriesUseCase(
        ref.watch(categoryRepositoryProvider(userId)),
      );
    });

final createCategoryUseCaseProvider =
    Provider.family<CreateCategoryUseCase, String>((ref, userId) {
      return CreateCategoryUseCase(
        ref.watch(categoryRepositoryProvider(userId)),
      );
    });

final updateCategoryUseCaseProvider =
    Provider.family<UpdateCategoryUseCase, String>((ref, userId) {
      return UpdateCategoryUseCase(
        ref.watch(categoryRepositoryProvider(userId)),
      );
    });

final setCategoryArchivedUseCaseProvider =
    Provider.family<SetCategoryArchivedUseCase, String>((ref, userId) {
      return SetCategoryArchivedUseCase(
        ref.watch(categoryRepositoryProvider(userId)),
      );
    });

final deleteCategoryUseCaseProvider =
    Provider.family<DeleteCategoryUseCase, String>((ref, userId) {
      return DeleteCategoryUseCase(
        ref.watch(categoryRepositoryProvider(userId)),
      );
    });

final seedDefaultCategoriesUseCaseProvider =
    Provider.family<SeedDefaultCategoriesUseCase, String>((ref, userId) {
      return SeedDefaultCategoriesUseCase(
        ref.watch(categoryRepositoryProvider(userId)),
      );
    });

final categoryListProvider =
    StreamProvider.family<Result<List<Category>>, String>((ref, userId) {
      return ref.watch(watchCategoriesUseCaseProvider(userId)).execute();
    });

final categoryOperationStateProvider =
    NotifierProvider.autoDispose<CategoryOperationNotifier, AsyncValue<void>>(
      CategoryOperationNotifier.new,
    );

class CategoryOperationNotifier extends Notifier<AsyncValue<void>> {
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
