import '../../../../shared/models/finance_enums.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.isDefault,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.parentCategoryId,
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
  final String? parentCategoryId;

  bool get isRoot => parentCategoryId == null;

  Category copyWith({
    String? id,
    String? name,
    TransactionType? type,
    String? icon,
    String? color,
    bool? isDefault,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? parentCategoryId = _unchanged,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentCategoryId: identical(parentCategoryId, _unchanged)
          ? this.parentCategoryId
          : parentCategoryId as String?,
    );
  }
}

const Object _unchanged = Object();
