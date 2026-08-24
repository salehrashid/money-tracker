import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/offline/sync_coordinator.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/firebase_category_data_source.dart';
import 'package:uuid/uuid.dart';

class FirebaseCategoryRepository implements CategoryRepository {
  FirebaseCategoryRepository({
    required FirebaseCategoryDataSource dataSource,
    required LocalFirstCollection<Category> local,
    FirebaseErrorMapper errorMapper = const FirebaseErrorMapper(),
  }) : _errorMapper = errorMapper,
       _local = local;

  final FirebaseErrorMapper _errorMapper;
  final LocalFirstCollection<Category> _local;

  @override
  Stream<Result<List<Category>>> watchCategories() async* {
    await for (final categories in _local.watch()) {
      categories.sort(_sortCategories);
      yield Success(categories);
    }
  }

  @override
  Future<Result<List<Category>>> fetchCategories() async {
    try {
      final categories = _local.current..sort(_sortCategories);
      return Success(categories);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<Category>> createCategory(Category category) async {
    try {
      final duplicateFailure = await _findDuplicateFailure(category);
      if (duplicateFailure != null) {
        return Failure(duplicateFailure);
      }

      final saved = category.id.isEmpty
          ? category.copyWith(id: const Uuid().v4())
          : category;
      await _local.save(saved, isCreate: true);
      return Success(saved);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<Category>> updateCategory(Category category) async {
    try {
      final current = _local.current
          .where((item) => item.id == category.id)
          .firstOrNull;
      if (current == null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.notFound,
            code: 'category-not-found',
            message: 'Category not found.',
          ),
        );
      }
      if (current.isDefault) {
        return const Failure(
          AppFailure(
            type: AppFailureType.validation,
            code: 'default-category-edit',
            message: 'Default categories cannot be edited.',
          ),
        );
      }

      final duplicateFailure = await _findDuplicateFailure(category);
      if (duplicateFailure != null) {
        return Failure(duplicateFailure);
      }

      await _local.save(category, isCreate: false);
      return Success(category);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<Category>> setArchived({
    required String categoryId,
    required bool isArchived,
  }) async {
    try {
      final current = _local.current
          .where((item) => item.id == categoryId)
          .firstOrNull;
      if (current == null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.notFound,
            code: 'category-not-found',
            message: 'Category not found.',
          ),
        );
      }

      final saved = current.copyWith(
        isArchived: isArchived,
        updatedAt: DateTime.now().toUtc(),
      );
      await _local.save(saved, isCreate: false);
      return Success(saved);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<void>> deleteCategory(String categoryId) async {
    try {
      final current = _local.current
          .where((item) => item.id == categoryId)
          .firstOrNull;
      if (current == null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.notFound,
            code: 'category-not-found',
            message: 'Category not found.',
          ),
        );
      }
      if (current.isDefault) {
        return const Failure(
          AppFailure(
            type: AppFailureType.validation,
            code: 'default-category-delete',
            message: 'Default categories cannot be deleted.',
          ),
        );
      }

      await _local.delete(current);
      return const Success(null);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  Future<AppFailure?> _findDuplicateFailure(Category category) async {
    final categories = _local.current;
    final normalizedName = category.name.trim().toLowerCase();
    final hasDuplicate = categories.any((existing) {
      return existing.id != category.id &&
          existing.type == category.type &&
          existing.name.trim().toLowerCase() == normalizedName;
    });

    if (!hasDuplicate) {
      return null;
    }

    return const AppFailure(
      type: AppFailureType.validation,
      code: 'duplicate-category',
      message: 'A category with this name already exists for this type.',
    );
  }

  AppFailure _mapError(Object error) {
    if (error is FormatException) {
      return AppFailure(
        type: AppFailureType.validation,
        code: 'invalid-category-data',
        message: 'Category data is invalid. Please try again.',
        details: error,
      );
    }

    return _errorMapper.map(error);
  }
}

int _sortCategories(Category first, Category second) {
  final archiveCompare = first.isArchived.toString().compareTo(
    second.isArchived.toString(),
  );
  if (archiveCompare != 0) {
    return archiveCompare;
  }

  final typeCompare = first.type.firestoreValue.compareTo(
    second.type.firestoreValue,
  );
  if (typeCompare != 0) {
    return typeCompare;
  }

  return first.name.toLowerCase().compareTo(second.name.toLowerCase());
}
