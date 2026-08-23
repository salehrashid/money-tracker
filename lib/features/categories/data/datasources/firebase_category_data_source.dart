import 'package:uuid/uuid.dart';

import '../../../../core/firebase/firestore_user_collections.dart';
import '../dto/category_dto.dart';

class FirebaseCategoryDataSource {
  const FirebaseCategoryDataSource(this._collections);

  final FirestoreUserCollections _collections;

  Stream<List<CategoryDto>> watchCategories() async* {
    yield const [];

    final initialDocuments = await _collections.categories.get();
    yield initialDocuments
        .map(CategoryDto.fromFirestore)
        .toList(growable: false);

    yield* _collections.categories.stream.map(
      (documents) =>
          documents.map(CategoryDto.fromFirestore).toList(growable: false),
    );
  }

  Future<List<CategoryDto>> fetchCategories() async {
    final documents = await _collections.categories.get();
    return documents.map(CategoryDto.fromFirestore).toList(growable: false);
  }

  Future<CategoryDto?> fetchCategory(String categoryId) async {
    final document = _collections.categories.document(categoryId);
    if (!await document.exists) return null;
    return CategoryDto.fromFirestore(await document.get());
  }

  Future<CategoryDto> saveCategory(CategoryDto category) async {
    final id = category.id.isEmpty ? const Uuid().v4() : category.id;
    final document = _collections.categories.document(id);
    final savedCategory = category.id.isEmpty
        ? CategoryDto(
            id: id,
            name: category.name,
            type: category.type,
            icon: category.icon,
            color: category.color,
            isDefault: category.isDefault,
            isArchived: category.isArchived,
            createdAt: category.createdAt,
            updatedAt: category.updatedAt,
          )
        : category;

    final exists = await document.exists;
    final now = DateTime.now().toUtc();
    final data = {
      ...savedCategory.toFirestore(),
      'serverUpdatedAt': now,
      if (!exists) 'serverCreatedAt': now,
    };
    if (exists) {
      await document.update(data);
    } else {
      await document.set(data);
    }
    return savedCategory;
  }

  Future<void> deleteCategory(String categoryId) {
    return _collections.categories.document(categoryId).delete();
  }

  Future<bool> hasTransactions(String categoryId) async {
    final documents = await _collections.transactions
        .where('categoryId', isEqualTo: categoryId)
        .limit(1)
        .get();
    return documents.isNotEmpty;
  }
}
