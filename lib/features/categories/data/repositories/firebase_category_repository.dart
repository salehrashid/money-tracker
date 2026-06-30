import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/firebase_category_data_source.dart';
import '../dto/category_dto.dart';

class FirebaseCategoryRepository implements CategoryRepository {
  const FirebaseCategoryRepository({
    required FirebaseCategoryDataSource dataSource,
    FirebaseErrorMapper errorMapper = const FirebaseErrorMapper(),
  }) : _dataSource = dataSource,
       _errorMapper = errorMapper;

  final FirebaseCategoryDataSource _dataSource;
  final FirebaseErrorMapper _errorMapper;

  @override
  Stream<Result<List<Category>>> watchCategories() async* {
    try {
      await for (final dtos in _dataSource.watchCategories()) {
        final categories =
            dtos.map((dto) => dto.toDomain()).toList(growable: false)
              ..sort(_sortCategories);
        yield Success(categories);
      }
    } catch (error) {
      yield Failure(_mapError(error));
    }
  }

  @override
  Future<Result<List<Category>>> fetchCategories() async {
    try {
      final dtos = await _dataSource.fetchCategories();
      final categories = dtos.map((dto) => dto.toDomain()).toList()
        ..sort(_sortCategories);
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

      final saved = await _dataSource.saveCategory(
        CategoryDto.fromDomain(category),
      );
      return Success(saved.toDomain());
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<Category>> updateCategory(Category category) async {
    try {
      final current = await _dataSource.fetchCategory(category.id);
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

      final saved = await _dataSource.saveCategory(
        CategoryDto.fromDomain(category),
      );
      return Success(saved.toDomain());
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
      final current = await _dataSource.fetchCategory(categoryId);
      if (current == null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.notFound,
            code: 'category-not-found',
            message: 'Category not found.',
          ),
        );
      }

      final saved = await _dataSource.saveCategory(
        CategoryDto.fromDomain(
          current.toDomain().copyWith(
            isArchived: isArchived,
            updatedAt: DateTime.now().toUtc(),
          ),
        ),
      );
      return Success(saved.toDomain());
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<void>> deleteCategory(String categoryId) async {
    try {
      final current = await _dataSource.fetchCategory(categoryId);
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

      final isUsed = await _dataSource.hasTransactions(categoryId);
      if (isUsed) {
        return const Failure(
          AppFailure(
            type: AppFailureType.validation,
            code: 'category-in-use',
            message:
                'This category is used by transactions. Archive it instead.',
          ),
        );
      }

      await _dataSource.deleteCategory(categoryId);
      return const Success(null);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  Future<AppFailure?> _findDuplicateFailure(Category category) async {
    final categories = await _dataSource.fetchCategories();
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
