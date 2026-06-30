import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_model_converters.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/category.dart';

class CategoryDto {
  const CategoryDto({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.isDefault,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final TransactionType type;
  final String icon;
  final String color;
  final bool isDefault;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CategoryDto.fromDomain(Category category) {
    return CategoryDto(
      id: category.id,
      name: category.name,
      type: category.type,
      icon: category.icon,
      color: category.color,
      isDefault: category.isDefault,
      isArchived: category.isArchived,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
    );
  }

  factory CategoryDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return CategoryDto.fromMap(
      snapshot.data() ?? const {},
      documentId: snapshot.id,
    );
  }

  factory CategoryDto.fromMap(Map<String, dynamic> data, {String? documentId}) {
    return CategoryDto(
      id: optionalString(data, 'id') ?? documentId ?? '',
      name: requiredString(data, 'name'),
      type: TransactionType.fromFirestore(requiredString(data, 'type')),
      icon: requiredString(data, 'icon'),
      color: requiredString(data, 'color'),
      isDefault: requiredBool(data, 'isDefault'),
      isArchived: requiredBool(data, 'isArchived'),
      createdAt: requiredDateTime(data, 'createdAt'),
      updatedAt: requiredDateTime(data, 'updatedAt'),
    );
  }

  Category toDomain() {
    return Category(
      id: id,
      name: name,
      type: type,
      icon: icon,
      color: color,
      isDefault: isDefault,
      isArchived: isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'type': type.firestoreValue,
      'icon': icon,
      'color': color,
      'isDefault': isDefault,
      'isArchived': isArchived,
      'createdAt': timestampFromDate(createdAt),
      'updatedAt': timestampFromDate(updatedAt),
    };
  }
}
