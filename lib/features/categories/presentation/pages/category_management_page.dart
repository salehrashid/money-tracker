import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/undo_delete/pending_delete_controller.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../../../shared/widgets/responsive_controls.dart';
import '../../../../shared/widgets/undo_delete_snackbar.dart';
import '../../application/usecases/category_commands.dart';
import '../../application/usecases/category_use_cases.dart';
import '../../domain/entities/category.dart';
import '../providers/category_providers.dart';
import '../widgets/category_color.dart';
import '../widgets/category_form_dialog.dart';
import '../widgets/category_icon_mapper.dart';

final _categoryTypeFilterProvider =
    NotifierProvider.autoDispose<_CategoryTypeFilterNotifier, TransactionType?>(
      _CategoryTypeFilterNotifier.new,
    );

final _categoryArchiveFilterProvider =
    NotifierProvider.autoDispose<_CategoryArchiveFilterNotifier, bool>(
      _CategoryArchiveFilterNotifier.new,
    );

final _collapsedCategoryIdsProvider =
    NotifierProvider.autoDispose<_CollapsedCategoryIdsNotifier, Set<String>>(
      _CollapsedCategoryIdsNotifier.new,
    );

class _CollapsedCategoryIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};
  void toggle(String id) =>
      state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
}

class _CategoryTypeFilterNotifier extends Notifier<TransactionType?> {
  @override
  TransactionType? build() {
    return null;
  }

  void set(TransactionType? type) {
    state = type;
  }
}

class _CategoryArchiveFilterNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  void set(bool value) {
    state = value;
  }
}

class CategoryManagementPage extends ConsumerWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _CenteredProgress(),
      error: (_, _) => const _MessageState(
        icon: Icons.error_outline,
        title: 'Unable to check sign-in status',
        message: 'Please restart the app and try again.',
      ),
      data: (result) {
        return result.when(
          failure: (failure) => _MessageState(
            icon: Icons.error_outline,
            title: 'Unable to check sign-in status',
            message: failure.message,
          ),
          success: (user) {
            if (user == null) {
              return const _MessageState(
                icon: Icons.lock_outline,
                title: 'Sign in required',
                message: 'Sign in to manage your categories.',
              );
            }

            return _CategoryContent(userId: user.id);
          },
        );
      },
    );
  }
}

class _CategoryContent extends ConsumerWidget {
  const _CategoryContent({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesState = ref.watch(categoryListProvider(userId));
    final operationState = ref.watch(categoryOperationStateProvider);
    final selectedType = ref.watch(_categoryTypeFilterProvider);
    final showArchived = ref.watch(_categoryArchiveFilterProvider);
    final pendingDeletions = ref.watch(pendingDeleteControllerProvider);
    final collapsedIds = ref.watch(_collapsedCategoryIdsProvider);
    final isDesktop = AppBreakpoints.isDesktop(context);

    ref.listen<AsyncValue<void>>(categoryOperationStateProvider, (
      previous,
      next,
    ) {
      if (previous?.isLoading == true && next.hasValue) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Categories updated')));
      }
      if (next case AsyncError(:final error)) {
        final message = error is AppFailure
            ? error.message
            : 'Something went wrong. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    });
    ref.listen<AsyncValue<Result<List<Category>>>>(
      categoryListProvider(userId),
      (previous, next) {
        final operationState = ref.read(categoryOperationStateProvider);
        if (!operationState.isLoading || !next.hasValue) {
          return;
        }

        next.value?.when(
          success: (_) =>
              ref.read(categoryOperationStateProvider.notifier).setSuccess(),
          failure: (_) {},
        );
      },
    );

    return Scaffold(
      appBar: AppTopBar(
        title: 'Categories',
        subtitle: 'Organize your income and expenses.',
        actions: isDesktop
            ? const []
            : [
                IconButton(
                  tooltip: 'Add category',
                  onPressed: operationState.isLoading
                      ? null
                      : () => _showCreateDialog(context, ref, userId),
                  icon: const Icon(Icons.add),
                ),
              ],
      ),
      body: categoriesState.when(
        loading: () => const _CenteredProgress(),
        error: (_, _) => const _MessageState(
          icon: Icons.error_outline,
          title: 'Unable to load categories',
          message: 'Please try again.',
        ),
        data: (result) {
          return result.when(
            failure: (failure) => _MessageState(
              icon: Icons.error_outline,
              title: 'Unable to load categories',
              message: failure.message,
            ),
            success: (allCategories) {
              final categories = allCategories
                  .where(
                    (category) => !pendingDeletions.values.any(
                      (pending) => pending.itemKeys.contains(
                        pendingDeleteItemKey('category', userId, category.id),
                      ),
                    ),
                  )
                  .toList(growable: false);
              final filtered = categories.where((category) {
                final matchesType =
                    selectedType == null || category.type == selectedType;
                return matchesType && category.isArchived == showArchived;
              }).toList();
              final filteredIds = filtered.map((item) => item.id).toSet();
              final roots =
                  filtered
                      .where(
                        (item) =>
                            item.parentCategoryId == null ||
                            !filteredIds.contains(item.parentCategoryId),
                      )
                      .toList()
                    ..sort(_categoryUiSort);
              final ordered = <Category>[];
              for (final root in roots) {
                ordered.add(root);
                if (!collapsedIds.contains(root.id)) {
                  ordered.addAll(
                    filtered
                        .where((item) => item.parentCategoryId == root.id)
                        .toList()
                      ..sort(_categoryUiSort),
                  );
                }
              }

              return RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(categoryListProvider(userId)),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: _CategoryToolbar(
                              selectedType: selectedType,
                              showArchived: showArchived,
                              onTypeChanged: (type) => ref
                                  .read(_categoryTypeFilterProvider.notifier)
                                  .set(type),
                              onArchiveChanged: (value) => ref
                                  .read(_categoryArchiveFilterProvider.notifier)
                                  .set(value),
                              onSeedDefaults: operationState.isLoading
                                  ? null
                                  : () => _seedDefaults(context, ref, userId),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (operationState.isLoading)
                      const SliverToBoxAdapter(
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (categories.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyCategories(
                          onSeedDefaults: operationState.isLoading
                              ? null
                              : () => _seedDefaults(context, ref, userId),
                          onCreate: operationState.isLoading
                              ? null
                              : () => _showCreateDialog(
                                  context,
                                  ref,
                                  userId,
                                  categories,
                                ),
                        ),
                      )
                    else if (filtered.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _MessageState(
                          icon: Icons.filter_alt_off,
                          title: 'No matching categories',
                          message: 'Adjust the filters to see more categories.',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        sliver: SliverList.separated(
                          itemCount: ordered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 900,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (index == 0 ||
                                        ordered[index - 1].type !=
                                            ordered[index].type) ...[
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          AppSpacing.xxs,
                                          AppSpacing.sm,
                                          AppSpacing.xxs,
                                          AppSpacing.xs,
                                        ),
                                        child: Text(
                                          '${_typeLabel(ordered[index].type)} categories',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
                                    ],
                                    _CategoryTile(
                                      category: ordered[index],
                                      isChild:
                                          ordered[index].parentCategoryId !=
                                              null &&
                                          filteredIds.contains(
                                            ordered[index].parentCategoryId,
                                          ),
                                      hasChildren: filtered.any(
                                        (item) =>
                                            item.parentCategoryId ==
                                            ordered[index].id,
                                      ),
                                      isCollapsed: collapsedIds.contains(
                                        ordered[index].id,
                                      ),
                                      onToggle: () => ref
                                          .read(
                                            _collapsedCategoryIdsProvider
                                                .notifier,
                                          )
                                          .toggle(ordered[index].id),
                                      isBusy: operationState.isLoading,
                                      onEdit: () => _showEditDialog(
                                        context,
                                        ref,
                                        userId,
                                        ordered[index],
                                        categories,
                                      ),
                                      onArchiveChanged: (isArchived) =>
                                          _setArchived(
                                            context,
                                            ref,
                                            userId,
                                            ordered[index],
                                            isArchived,
                                          ),
                                      onDelete: () => _confirmDelete(
                                        context,
                                        ref,
                                        userId,
                                        ordered[index],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'categories-fab',
        onPressed: operationState.isLoading
            ? null
            : () => _showCreateDialog(context, ref, userId),
        icon: const Icon(Icons.add),
        label: const Text('Category'),
      ),
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    WidgetRef ref,
    String userId, [
    List<Category> categories = const [],
  ]) async {
    final command = await showDialog<SaveCategoryCommand>(
      context: context,
      builder: (_) => CategoryFormDialog(
        categories: categories.isNotEmpty
            ? categories
            : _categoriesFrom(ref, userId),
      ),
    );
    if (command == null || !context.mounted) {
      return;
    }

    await _runOperation(
      ref,
      () => ref.read(createCategoryUseCaseProvider(userId)).execute(command),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
    Category category,
    List<Category> categories,
  ) async {
    final command = await showDialog<SaveCategoryCommand>(
      context: context,
      builder: (_) =>
          CategoryFormDialog(category: category, categories: categories),
    );
    if (command == null || !context.mounted) {
      return;
    }

    await _runOperation(
      ref,
      () => ref
          .read(updateCategoryUseCaseProvider(userId))
          .execute(category: category, command: command),
    );
  }

  Future<void> _setArchived(
    BuildContext context,
    WidgetRef ref,
    String userId,
    Category category,
    bool isArchived,
  ) async {
    await _runOperation(
      ref,
      () => ref
          .read(setCategoryArchivedUseCaseProvider(userId))
          .execute(categoryId: category.id, isArchived: isArchived),
    );
  }

  Future<void> _seedDefaults(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    await _runOperation(
      ref,
      () => ref.read(seedDefaultCategoriesUseCaseProvider(userId)).execute(),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String userId,
    Category category,
  ) async {
    final children = _categoriesFrom(
      ref,
      userId,
    ).where((item) => item.parentCategoryId == category.id).toList();
    if (children.isNotEmpty) {
      final strategy = await showDialog<DeleteCategoryStrategy>(
        context: context,
        builder: (_) => _DeleteParentCategoryDialog(
          categoryName: category.name,
          childCount: children.length,
        ),
      );
      if (strategy == null || !context.mounted) return;
      final useCase = ref.read(deleteCategoryUseCaseProvider(userId));
      final affectedCategories =
          strategy == DeleteCategoryStrategy.deleteChildren
          ? [category, ...children]
          : [category];
      final itemKeys = affectedCategories
          .map((item) => pendingDeleteItemKey('category', userId, item.id))
          .toSet();
      final operationKey =
          '${pendingDeleteItemKey('category', userId, category.id)}:${strategy.name}';
      scheduleUndoDelete<Category>(
        context: context,
        ref: ref,
        operationKey: operationKey,
        itemKeys: itemKeys,
        items: affectedCategories,
        message: strategy == DeleteCategoryStrategy.moveChildrenToRoot
            ? 'Category deleted; sub-categories moved to root'
            : 'Category and sub-categories deleted',
        failureMessage: 'Could not update categories. Please try again.',
        commitDelete: () => useCase.execute(category.id, strategy: strategy),
      );
      return;
    }
    final confirmed = await showAppDeleteConfirmation(
      context: context,
      title: 'Delete category?',
      message:
          '${category.name} will be permanently deleted. Categories used by transactions cannot be deleted.',
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final useCase = ref.read(deleteCategoryUseCaseProvider(userId));
    final itemKey = pendingDeleteItemKey('category', userId, category.id);
    scheduleUndoDelete<Category>(
      context: context,
      ref: ref,
      operationKey: itemKey,
      itemKeys: {itemKey},
      items: [category],
      message: 'Category deleted',
      failureMessage: 'Could not delete category. Please try again.',
      commitDelete: () => useCase.execute(category.id),
    );
  }

  Future<void> _runOperation<T>(
    WidgetRef ref,
    Future<Result<T>> Function() action,
  ) async {
    final notifier = ref.read(categoryOperationStateProvider.notifier);
    notifier.setLoading();
    final result = await action();
    result.when(
      success: (_) => notifier.setSuccess(),
      failure: (failure) => notifier.setFailure(failure, StackTrace.current),
    );
  }
}

class _DeleteParentCategoryDialog extends StatefulWidget {
  const _DeleteParentCategoryDialog({
    required this.categoryName,
    required this.childCount,
  });

  final String categoryName;
  final int childCount;

  @override
  State<_DeleteParentCategoryDialog> createState() =>
      _DeleteParentCategoryDialogState();
}

class _DeleteParentCategoryDialogState
    extends State<_DeleteParentCategoryDialog> {
  DeleteCategoryStrategy _strategy = DeleteCategoryStrategy.moveChildrenToRoot;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final childLabel = widget.childCount == 1
        ? 'sub-category'
        : 'sub-categories';

    return AlertDialog(
      title: Text('Delete "${widget.categoryName}"?'),
      content: SizedBox(
        width: responsiveDialogWidth(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This category contains ${widget.childCount} $childLabel.\n'
              'Transactions will not be deleted.',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'What should happen to its sub-categories?',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<DeleteCategoryStrategy>(
              groupValue: _strategy,
              onChanged: (value) {
                if (value != null) setState(() => _strategy = value);
              },
              child: Column(
                children: [
                  _DeleteCategoryOption(
                    value: DeleteCategoryStrategy.moveChildrenToRoot,
                    selected:
                        _strategy == DeleteCategoryStrategy.moveChildrenToRoot,
                    title: 'Move to root',
                    subtitle: 'Keep ${widget.childCount} $childLabel',
                    icon: Icons.call_split_outlined,
                    color: colors.primary,
                    onTap: () => setState(
                      () =>
                          _strategy = DeleteCategoryStrategy.moveChildrenToRoot,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DeleteCategoryOption(
                    value: DeleteCategoryStrategy.deleteChildren,
                    selected:
                        _strategy == DeleteCategoryStrategy.deleteChildren,
                    title: 'Delete sub-categories',
                    subtitle:
                        'Delete this category and its ${widget.childCount} $childLabel',
                    icon: Icons.delete_outline,
                    color: colors.error,
                    onTap: () => setState(
                      () => _strategy = DeleteCategoryStrategy.deleteChildren,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.pop(context, _strategy),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete category'),
        ),
      ],
    );
  }
}

class _DeleteCategoryOption extends StatelessWidget {
  const _DeleteCategoryOption({
    required this.value,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final DeleteCategoryStrategy value;
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? color.withValues(alpha: 0.08) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? color : colors.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            children: [
              Radio<DeleteCategoryStrategy>(value: value, activeColor: color),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryToolbar extends StatelessWidget {
  const _CategoryToolbar({
    required this.selectedType,
    required this.showArchived,
    required this.onTypeChanged,
    required this.onArchiveChanged,
    required this.onSeedDefaults,
  });

  final TransactionType? selectedType;
  final bool showArchived;
  final ValueChanged<TransactionType?> onTypeChanged;
  final ValueChanged<bool> onArchiveChanged;
  final VoidCallback? onSeedDefaults;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ResponsiveSegmentedButton<TransactionType?>(
          segments: const [
            ResponsiveSegment(value: null, label: 'All'),
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
          selected: {selectedType},
          onSelectionChanged: (values) => onTypeChanged(values.first),
        ),
        FilterChip(
          selected: showArchived,
          avatar: const Icon(Icons.archive_outlined),
          label: const Text('Archived'),
          onSelected: onArchiveChanged,
        ),
        OutlinedButton.icon(
          onPressed: onSeedDefaults,
          icon: const Icon(Icons.playlist_add_check),
          label: const Text('Defaults'),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.isBusy,
    required this.onEdit,
    required this.onArchiveChanged,
    required this.onDelete,
    required this.isChild,
    required this.hasChildren,
    required this.isCollapsed,
    required this.onToggle,
  });

  final Category category;
  final bool isBusy;
  final VoidCallback onEdit;
  final ValueChanged<bool> onArchiveChanged;
  final VoidCallback onDelete;
  final bool isChild;
  final bool hasChildren;
  final bool isCollapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = categoryColor(category.color);

    return Padding(
      padding: EdgeInsets.only(left: isChild ? 28 : 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasChildren)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: isCollapsed
                      ? 'Expand sub-categories'
                      : 'Collapse sub-categories',
                  onPressed: onToggle,
                  icon: Icon(
                    isCollapsed ? Icons.chevron_right : Icons.expand_more,
                  ),
                ),
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.16),
                foregroundColor: color,
                child: Icon(categoryIconData(category.icon)),
              ),
            ],
          ),
          title: Text(
            category.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(_typeLabel(category.type)),
              if (category.isDefault)
                Text('Default', style: TextStyle(color: colorScheme.primary)),
              if (category.isArchived)
                Text('Archived', style: TextStyle(color: colorScheme.error)),
            ],
          ),
          trailing: AppBreakpoints.isMobile(context)
              ? PopupMenuButton<_CategoryAction>(
                  tooltip: 'Category actions',
                  onSelected: (action) {
                    switch (action) {
                      case _CategoryAction.edit:
                        onEdit();
                      case _CategoryAction.archive:
                        onArchiveChanged(!category.isArchived);
                      case _CategoryAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _CategoryAction.edit,
                      enabled: !isBusy && !category.isDefault,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _CategoryAction.archive,
                      enabled: !isBusy,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          category.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                        ),
                        title: Text(
                          category.isArchived ? 'Unarchive' : 'Archive',
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: _CategoryAction.delete,
                      enabled: !isBusy && !category.isDefault,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete'),
                      ),
                    ),
                  ],
                )
              : Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: isBusy || category.isDefault ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: category.isArchived ? 'Unarchive' : 'Archive',
                      onPressed: isBusy
                          ? null
                          : () => onArchiveChanged(!category.isArchived),
                      icon: Icon(
                        category.isArchived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: isBusy || category.isDefault ? null : onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

int _categoryUiSort(Category a, Category b) {
  final type = a.type.index.compareTo(b.type.index);
  return type != 0
      ? type
      : a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

List<Category> _categoriesFrom(WidgetRef ref, String userId) {
  final value = ref.read(categoryListProvider(userId)).value;
  return switch (value) {
    Success<List<Category>>(:final value) => value,
    _ => const [],
  };
}

enum _CategoryAction { edit, archive, delete }

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories({
    required this.onSeedDefaults,
    required this.onCreate,
  });

  final VoidCallback? onSeedDefaults;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No categories yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add default categories or create your own.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onSeedDefaults,
                  icon: const Icon(Icons.playlist_add_check),
                  label: const Text('Add defaults'),
                ),
                OutlinedButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CenteredProgress extends StatelessWidget {
  const _CenteredProgress();

  @override
  Widget build(BuildContext context) {
    return const AppLoadingState();
  }
}

String _typeLabel(TransactionType type) {
  return switch (type) {
    TransactionType.income => 'Income',
    TransactionType.expense => 'Expense',
  };
}
