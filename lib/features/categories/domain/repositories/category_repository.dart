import '../../../../core/utils/result.dart';
import '../entities/category.dart';

abstract interface class CategoryRepository {
  Stream<Result<List<Category>>> watchCategories();

  Future<Result<List<Category>>> fetchCategories();

  Future<Result<Category>> createCategory(Category category);

  Future<Result<Category>> updateCategory(Category category);

  Future<Result<Category>> setArchived({
    required String categoryId,
    required bool isArchived,
  });

  Future<Result<void>> deleteCategory(String categoryId);
}
