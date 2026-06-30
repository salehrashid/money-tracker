import '../../../../shared/models/finance_enums.dart';

class SaveCategoryCommand {
  const SaveCategoryCommand({
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });

  final String name;
  final TransactionType type;
  final String icon;
  final String color;
}
