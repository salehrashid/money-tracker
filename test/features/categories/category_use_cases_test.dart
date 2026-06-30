import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/errors/app_failure.dart';
import 'package:money_tracker/core/utils/result.dart';
import 'package:money_tracker/features/categories/application/usecases/category_commands.dart';
import 'package:money_tracker/features/categories/application/usecases/category_use_cases.dart';
import 'package:money_tracker/features/categories/domain/entities/category.dart';
import 'package:money_tracker/features/categories/domain/repositories/category_repository.dart';
import 'package:money_tracker/shared/models/finance_enums.dart';

void main() {
  group('CreateCategoryUseCase', () {
    test('returns validation failure for an empty name', () async {
      final repository = _FakeCategoryRepository();
      final useCase = CreateCategoryUseCase(repository);

      final result = await useCase.execute(
        const SaveCategoryCommand(
          name: ' ',
          type: TransactionType.expense,
          icon: 'restaurant',
          color: '#2E7D32',
        ),
      );

      expect(result, isA<Failure<Category>>());
      expect(repository.categories, isEmpty);
    });

    test('creates a custom category with normalized text values', () async {
      final repository = _FakeCategoryRepository();
      final useCase = CreateCategoryUseCase(repository);

      final result = await useCase.execute(
        const SaveCategoryCommand(
          name: '  Groceries  ',
          type: TransactionType.expense,
          icon: 'restaurant',
          color: '#2E7D32',
        ),
      );

      final category = (result as Success<Category>).value;
      expect(category.name, 'Groceries');
      expect(category.isDefault, isFalse);
      expect(repository.categories.single.name, 'Groceries');
    });
  });

  group('UpdateCategoryUseCase', () {
    test('does not edit default categories', () async {
      final category = _category(id: 'default-food', isDefault: true);
      final repository = _FakeCategoryRepository([category]);
      final useCase = UpdateCategoryUseCase(repository);

      final result = await useCase.execute(
        category: category,
        command: const SaveCategoryCommand(
          name: 'Meals',
          type: TransactionType.expense,
          icon: 'restaurant',
          color: '#2E7D32',
        ),
      );

      expect(result, isA<Failure<Category>>());
      expect(repository.categories.single.name, 'Food');
    });
  });

  group('SeedDefaultCategoriesUseCase', () {
    test('adds defaults and skips existing category names by type', () async {
      final repository = _FakeCategoryRepository([
        _category(id: 'custom-food', name: 'Food'),
      ]);
      final useCase = SeedDefaultCategoriesUseCase(repository);

      final result = await useCase.execute();

      expect(result, isA<Success<void>>());
      expect(
        repository.categories
            .where(
              (category) =>
                  category.name == 'Food' &&
                  category.type == TransactionType.expense,
            )
            .length,
        1,
      );
      expect(
        repository.categories.any((category) => category.name == 'Salary'),
        isTrue,
      );
    });
  });
}

class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository([List<Category>? categories])
    : categories = [...?categories];

  final List<Category> categories;

  @override
  Stream<Result<List<Category>>> watchCategories() {
    return Stream.value(Success(categories));
  }

  @override
  Future<Result<List<Category>>> fetchCategories() async {
    return Success(categories);
  }

  @override
  Future<Result<Category>> createCategory(Category category) async {
    final saved = category.copyWith(
      id: category.id.isEmpty
          ? 'category-${categories.length + 1}'
          : category.id,
    );
    categories.add(saved);
    return Success(saved);
  }

  @override
  Future<Result<Category>> updateCategory(Category category) async {
    final index = categories.indexWhere((item) => item.id == category.id);
    if (index == -1) {
      return const Failure(
        AppFailure(
          type: AppFailureType.notFound,
          message: 'Category not found.',
        ),
      );
    }
    categories[index] = category;
    return Success(category);
  }

  @override
  Future<Result<Category>> setArchived({
    required String categoryId,
    required bool isArchived,
  }) async {
    final index = categories.indexWhere((item) => item.id == categoryId);
    if (index == -1) {
      return const Failure(
        AppFailure(
          type: AppFailureType.notFound,
          message: 'Category not found.',
        ),
      );
    }
    categories[index] = categories[index].copyWith(isArchived: isArchived);
    return Success(categories[index]);
  }

  @override
  Future<Result<void>> deleteCategory(String categoryId) async {
    categories.removeWhere((category) => category.id == categoryId);
    return const Success(null);
  }
}

Category _category({
  required String id,
  String name = 'Food',
  TransactionType type = TransactionType.expense,
  bool isDefault = false,
}) {
  final now = DateTime.utc(2026);
  return Category(
    id: id,
    name: name,
    type: type,
    icon: 'restaurant',
    color: '#2E7D32',
    isDefault: isDefault,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}
