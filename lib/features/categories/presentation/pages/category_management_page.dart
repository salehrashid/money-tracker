import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../application/usecases/category_commands.dart';
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

    ref.listen<AsyncValue<void>>(categoryOperationStateProvider, (
      previous,
      next,
    ) {
      if (next case AsyncError(:final error)) {
        final message = error is AppFailure
            ? error.message
            : 'Something went wrong. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
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
            success: (categories) {
              final filtered = categories
                  .where((category) {
                    final matchesType =
                        selectedType == null || category.type == selectedType;
                    return matchesType && category.isArchived == showArchived;
                  })
                  .toList(growable: false);

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
                              : () => _showCreateDialog(context, ref, userId),
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
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 900,
                                ),
                                child: _CategoryTile(
                                  category: filtered[index],
                                  isBusy: operationState.isLoading,
                                  onEdit: () => _showEditDialog(
                                    context,
                                    ref,
                                    userId,
                                    filtered[index],
                                  ),
                                  onArchiveChanged: (isArchived) =>
                                      _setArchived(
                                        context,
                                        ref,
                                        userId,
                                        filtered[index],
                                        isArchived,
                                      ),
                                  onDelete: () => _confirmDelete(
                                    context,
                                    ref,
                                    userId,
                                    filtered[index],
                                  ),
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
    String userId,
  ) async {
    final command = await showDialog<SaveCategoryCommand>(
      context: context,
      builder: (_) => const CategoryFormDialog(),
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
  ) async {
    final command = await showDialog<SaveCategoryCommand>(
      context: context,
      builder: (_) => CategoryFormDialog(category: category),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Delete ${category.name}? Categories used by transactions cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await _runOperation(
      ref,
      () =>
          ref.read(deleteCategoryUseCaseProvider(userId)).execute(category.id),
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
        SegmentedButton<TransactionType?>(
          segments: const [
            ButtonSegment(value: null, label: Text('All')),
            ButtonSegment(
              value: TransactionType.expense,
              icon: Icon(Icons.remove_circle_outline),
              label: Text('Expense'),
            ),
            ButtonSegment(
              value: TransactionType.income,
              icon: Icon(Icons.add_circle_outline),
              label: Text('Income'),
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
  });

  final Category category;
  final bool isBusy;
  final VoidCallback onEdit;
  final ValueChanged<bool> onArchiveChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = categoryColor(category.color);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.16),
          foregroundColor: color,
          child: Icon(categoryIconData(category.icon)),
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
        trailing: Wrap(
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
    );
  }
}

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
    return const Center(child: CircularProgressIndicator());
  }
}

String _typeLabel(TransactionType type) {
  return switch (type) {
    TransactionType.income => 'Income',
    TransactionType.expense => 'Expense',
  };
}
