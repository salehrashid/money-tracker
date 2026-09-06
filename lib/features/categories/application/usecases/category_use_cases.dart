import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import 'category_commands.dart';

class WatchCategoriesUseCase {
  const WatchCategoriesUseCase(this._repository);

  final CategoryRepository _repository;

  Stream<Result<List<Category>>> execute() {
    return _repository.watchCategories();
  }
}

class CreateCategoryUseCase {
  const CreateCategoryUseCase(this._repository);

  final CategoryRepository _repository;

  Future<Result<Category>> execute(SaveCategoryCommand command) async {
    final failure = _validate(command);
    if (failure != null) {
      return Failure(failure);
    }

    final hierarchyFailure = await _validateHierarchy(_repository, command);
    if (hierarchyFailure != null) return Failure(hierarchyFailure);

    final now = DateTime.now().toUtc();
    return _repository.createCategory(
      Category(
        id: '',
        name: command.name.trim(),
        type: command.type,
        icon: command.icon.trim(),
        color: command.color.trim(),
        isDefault: false,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
        parentCategoryId: _normalizedParent(command.parentCategoryId),
      ),
    );
  }
}

class UpdateCategoryUseCase {
  const UpdateCategoryUseCase(this._repository);

  final CategoryRepository _repository;

  Future<Result<Category>> execute({
    required Category category,
    required SaveCategoryCommand command,
  }) {
    if (category.isDefault) {
      return Future.value(
        const Failure(
          AppFailure(
            type: AppFailureType.validation,
            code: 'default-category-edit',
            message: 'Default categories cannot be edited.',
          ),
        ),
      );
    }

    final failure = _validate(command);
    if (failure != null) {
      return Future.value(Failure(failure));
    }

    return _update(category, command);
  }

  Future<Result<Category>> _update(
    Category category,
    SaveCategoryCommand command,
  ) async {
    final hierarchyFailure = await _validateHierarchy(
      _repository,
      command,
      category: category,
    );
    if (hierarchyFailure != null) return Failure(hierarchyFailure);
    return _repository.updateCategory(
      category.copyWith(
        name: command.name.trim(),
        type: command.type,
        icon: command.icon.trim(),
        color: command.color.trim(),
        updatedAt: DateTime.now().toUtc(),
        parentCategoryId: _normalizedParent(command.parentCategoryId),
      ),
    );
  }
}

String? _normalizedParent(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

Future<AppFailure?> _validateHierarchy(
  CategoryRepository repository,
  SaveCategoryCommand command, {
  Category? category,
}) async {
  final parentId = _normalizedParent(command.parentCategoryId);
  if (parentId == null) return null;
  if (parentId == category?.id) {
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'category-self-parent',
      message: 'A category cannot be its own parent.',
    );
  }
  final result = await repository.fetchCategories();
  if (result case Failure<List<Category>>(:final failure)) return failure;
  final categories = (result as Success<List<Category>>).value;
  final parent = categories.where((item) => item.id == parentId).firstOrNull;
  if (parent == null || !parent.isRoot) {
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'invalid-category-parent',
      message: 'Choose a valid root category.',
    );
  }
  if (parent.type != command.type) {
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'category-parent-type-mismatch',
      message: 'The parent category must have the same transaction type.',
    );
  }
  if (category != null &&
      category.isRoot &&
      categories.any((item) => item.parentCategoryId == category.id)) {
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'category-has-children',
      message:
          'This category contains sub-categories. Move or remove them before changing its parent.',
    );
  }
  return null;
}

class SetCategoryArchivedUseCase {
  const SetCategoryArchivedUseCase(this._repository);

  final CategoryRepository _repository;

  Future<Result<Category>> execute({
    required String categoryId,
    required bool isArchived,
  }) {
    if (categoryId.trim().isEmpty) {
      return Future.value(
        const Failure(
          AppFailure(
            type: AppFailureType.validation,
            code: 'missing-category-id',
            message: 'Choose a category first.',
          ),
        ),
      );
    }

    return _repository.setArchived(
      categoryId: categoryId,
      isArchived: isArchived,
    );
  }
}

class DeleteCategoryUseCase {
  const DeleteCategoryUseCase(this._repository);

  final CategoryRepository _repository;

  Future<Result<void>> execute(
    String categoryId, {
    DeleteCategoryStrategy strategy = DeleteCategoryStrategy.rejectIfNotEmpty,
  }) async {
    if (categoryId.trim().isEmpty) {
      return const Failure(
        AppFailure(
          type: AppFailureType.validation,
          code: 'missing-category-id',
          message: 'Choose a category first.',
        ),
      );
    }
    final result = await _repository.fetchCategories();
    if (result case Failure<List<Category>>(:final failure)) {
      return Failure(failure);
    }
    final categories = (result as Success<List<Category>>).value;
    final children = categories
        .where((item) => item.parentCategoryId == categoryId)
        .toList();
    if (children.isNotEmpty &&
        strategy == DeleteCategoryStrategy.rejectIfNotEmpty) {
      return const Failure(
        AppFailure(
          type: AppFailureType.validation,
          code: 'category-has-children',
          message:
              'This category contains sub-categories. Move or remove them before deleting it.',
        ),
      );
    }
    if (strategy == DeleteCategoryStrategy.moveChildrenToRoot) {
      for (final child in children) {
        final update = await _repository.updateCategory(
          child.copyWith(
            parentCategoryId: null,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
        if (update case Failure<Category>(:final failure)) {
          return Failure(failure);
        }
      }
    } else if (strategy == DeleteCategoryStrategy.deleteChildren) {
      for (final child in children) {
        final deletion = await _repository.deleteCategory(child.id);
        if (deletion case Failure<void>(:final failure)) {
          return Failure(failure);
        }
      }
    }
    return _repository.deleteCategory(categoryId);
  }
}

enum DeleteCategoryStrategy {
  rejectIfNotEmpty,
  moveChildrenToRoot,
  deleteChildren,
}

class SeedDefaultCategoriesUseCase {
  const SeedDefaultCategoriesUseCase(this._repository);

  final CategoryRepository _repository;

  Future<Result<void>> execute() async {
    final existingResult = await _repository.fetchCategories();
    if (existingResult case Failure<List<Category>>(:final failure)) {
      return Failure(failure);
    }

    final existing = (existingResult as Success<List<Category>>).value;
    final existingIds = existing.map((category) => category.id).toSet();
    final existingKeys = existing.map(_categoryKey).toSet();

    for (final category in _defaultCategories()) {
      if (existingIds.contains(category.id) ||
          existingKeys.contains(_categoryKey(category))) {
        continue;
      }

      final result = await _repository.createCategory(category);
      if (result case Failure<Category>(:final failure)) {
        return Failure(failure);
      }
    }

    return const Success(null);
  }
}

String _categoryKey(Category category) {
  return '${category.type.firestoreValue}:${category.name.trim().toLowerCase()}';
}

AppFailure? _validate(SaveCategoryCommand command) {
  final name = command.name.trim();
  final icon = command.icon.trim();
  final color = command.color.trim();

  if (name.isEmpty) {
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'empty-category-name',
      message: 'Enter a category name.',
    );
  }
  if (name.length > 48) {
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'category-name-too-long',
      message: 'Category name must be 48 characters or fewer.',
    );
  }
  if (icon.isEmpty) {
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'empty-category-icon',
      message: 'Choose an icon.',
    );
  }
  if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'invalid-category-color',
      message: 'Choose a valid category color.',
    );
  }

  return null;
}

List<Category> _defaultCategories() {
  final now = DateTime.now().toUtc();

  Category item({
    required String id,
    required String name,
    required TransactionType type,
    required String icon,
    required String color,
  }) {
    return Category(
      id: id,
      name: name,
      type: type,
      icon: icon,
      color: color,
      isDefault: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  return [
    item(
      id: 'default-expense-food',
      name: 'Food',
      type: TransactionType.expense,
      icon: 'restaurant',
      color: '#2E7D32',
    ),
    item(
      id: 'default-expense-transport',
      name: 'Transport',
      type: TransactionType.expense,
      icon: 'directions_car',
      color: '#1565C0',
    ),
    item(
      id: 'default-expense-bills',
      name: 'Bills',
      type: TransactionType.expense,
      icon: 'receipt_long',
      color: '#6A1B9A',
    ),
    item(
      id: 'default-income-salary',
      name: 'Salary',
      type: TransactionType.income,
      icon: 'payments',
      color: '#00838F',
    ),
    item(
      id: 'default-income-gift',
      name: 'Gift',
      type: TransactionType.income,
      icon: 'redeem',
      color: '#AD1457',
    ),
  ];
}
