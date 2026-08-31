import 'package:flutter/material.dart';

import '../../../../shared/models/finance_enums.dart';
import '../../../../shared/widgets/responsive_controls.dart';
import '../../application/usecases/category_commands.dart';
import '../../domain/entities/category.dart';
import 'category_color.dart';
import 'category_icon_mapper.dart';

class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog({this.category, super.key});

  final Category? category;

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late TransactionType _type;
  late String _icon;
  late String _color;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    _type = category?.type ?? TransactionType.expense;
    _icon = category?.icon ?? categoryIconOptions.first;
    _color = category?.color ?? categoryColorOptions.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final dialogWidth = responsiveDialogWidth(context);

    return AlertDialog(
      constraints: BoxConstraints(minWidth: dialogWidth, maxWidth: dialogWidth),
      title: Text(category == null ? 'Add category' : 'Edit category'),
      content: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 48,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter a category name'
                      : null,
                ),
                const SizedBox(height: 12),
                ResponsiveSegmentedButton<TransactionType>(
                  segments: const [
                    ResponsiveSegment(
                      value: TransactionType.expense,
                      icon: Icons.remove_circle_outline,
                      label: 'Expense',
                    ),
                    ResponsiveSegment(
                      value: TransactionType.income,
                      icon: Icons.add_circle_outline,
                      label: 'Income',
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (values) {
                    setState(() => _type = values.first);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: categoryIconOptions.contains(_icon)
                      ? _icon
                      : categoryIconOptions.last,
                  decoration: const InputDecoration(labelText: 'Icon'),
                  items: categoryIconOptions
                      .map((icon) {
                        return DropdownMenuItem(
                          value: icon,
                          child: Row(
                            children: [
                              Icon(categoryIconData(icon)),
                              const SizedBox(width: 12),
                              Text(categoryIconLabel(icon)),
                            ],
                          ),
                        );
                      })
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _icon = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categoryColorOptions
                      .map((color) {
                        final isSelected = color == _color;
                        return Tooltip(
                          message: color,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => setState(() => _color = color),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: categoryColor(color),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white)
                                  : null,
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            Navigator.of(context).pop(
              SaveCategoryCommand(
                name: _nameController.text,
                type: _type,
                icon: _icon,
                color: _color,
              ),
            );
          },
          icon: const Icon(Icons.check),
          label: const Text('Save'),
        ),
      ],
    );
  }
}
