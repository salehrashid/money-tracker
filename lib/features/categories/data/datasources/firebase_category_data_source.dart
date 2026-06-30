import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_user_collections.dart';
import '../dto/category_dto.dart';

class FirebaseCategoryDataSource {
  const FirebaseCategoryDataSource(this._collections);

  final FirestoreUserCollections _collections;

  Stream<List<CategoryDto>> watchCategories() {
    return _collections.categories.snapshots().map(
      (snapshot) =>
          snapshot.docs.map(CategoryDto.fromFirestore).toList(growable: false),
    );
  }

  Future<List<CategoryDto>> fetchCategories() async {
    final snapshot = await _collections.categories.get();
    return snapshot.docs.map(CategoryDto.fromFirestore).toList(growable: false);
  }

  Future<CategoryDto?> fetchCategory(String categoryId) async {
    final snapshot = await _collections.categories.doc(categoryId).get();
    if (!snapshot.exists) {
      return null;
    }

    return CategoryDto.fromFirestore(snapshot);
  }

  Future<CategoryDto> saveCategory(CategoryDto category) async {
    final document = category.id.isEmpty
        ? _collections.categories.doc()
        : _collections.categories.doc(category.id);
    final savedCategory = category.id.isEmpty
        ? CategoryDto(
            id: document.id,
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

    await document.set(savedCategory.toFirestore(), SetOptions(merge: true));
    return savedCategory;
  }

  Future<void> deleteCategory(String categoryId) {
    return _collections.categories.doc(categoryId).delete();
  }

  Future<bool> hasTransactions(String categoryId) async {
    final snapshot = await _collections.transactions
        .where('categoryId', isEqualTo: categoryId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }
}
