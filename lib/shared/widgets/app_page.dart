import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:light_dark_theme_toggle/light_dark_theme_toggle.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/offline/sync_status.dart';
import '../../features/auth/domain/entities/auth_user.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/settings/presentation/providers/financial_settings_providers.dart';
import '../../core/utils/result.dart';

import '../theme/app_theme.dart';

class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopBar({
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.showBackButton = false,
    this.onBackPressed,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  @override
  Size get preferredSize => const Size.fromHeight(88);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawerScope = AppDrawerScope.maybeOf(context);
    final auth = ref.watch(authStateProvider).value;
    final user = switch (auth) {
      Success<AuthUser?>(:final value) => value,
      _ => null,
    };
    final syncState = user == null
        ? RemoteSyncState.online
        : ref.watch(remoteSyncStateProvider(user.id)).value ??
              RemoteSyncState.online;
    return AppBar(
      toolbarHeight: preferredSize.height,
      leading: showBackButton && (onBackPressed != null || drawerScope != null)
          ? IconButton(
              tooltip: 'Back to dashboard',
              icon: const Icon(Icons.arrow_back),
              onPressed: onBackPressed ?? drawerScope!.goToDashboard,
            )
          : drawerScope == null
          ? null
          : IconButton(
              tooltip: 'Open navigation menu',
              icon: const Icon(Icons.menu),
              onPressed: drawerScope.openDrawer,
            ),
      titleSpacing: AppBreakpoints.isMobile(context)
          ? AppSpacing.md
          : AppSpacing.xxl,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        OfflineSyncStatusAction(state: syncState),
        ...actions,
      ],
    );
  }
}

class AppThemeToggle extends ConsumerStatefulWidget {
  const AppThemeToggle({this.size = 32, super.key});

  final double size;

  @override
  ConsumerState<AppThemeToggle> createState() => _AppThemeToggleState();
}

class _AppThemeToggleState extends ConsumerState<AppThemeToggle> {
  var _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider).value;
    final user = switch (auth) {
      Success<AuthUser?>(:final value) => value,
      _ => null,
    };
    if (user == null) {
      return const SizedBox.shrink();
    }

    final settingsResult = ref.watch(financialSettingsProvider(user.id)).value;
    final isDarkMode =
        settingsResult?.when(
          success: (settings) => settings?.isDarkMode ?? false,
          failure: (_) => false,
        ) ??
        false;
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 52,
      height: 48,
      child: Center(
        child: LightDarkThemeToggle(
          size: widget.size,
          // The package uses true for light mode and false for dark mode.
          value: !isDarkMode,
          onChanged: _isSaving || settingsResult == null
              ? (_) {}
              : (value) => _setTheme(user.id, value),
          themeIconType: ThemeIconType.expand,
          color: colorScheme.onSurfaceVariant,
          hoverColor: colorScheme.primaryContainer,
          highlightColor: colorScheme.primaryContainer,
          padding: const EdgeInsets.all(4),
          tooltip: isDarkMode ? 'Switch to light mode' : 'Switch to night mode',
        ),
      ),
    );
  }

  Future<void> _setTheme(String userId, bool isLightMode) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final result = await ref.read(saveDarkModeProvider(userId))(!isLightMode);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result case Failure(:final failure)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class AppDrawerScope extends InheritedWidget {
  const AppDrawerScope({
    required this.openDrawer,
    required this.goToDashboard,
    required super.child,
    super.key,
  });

  final VoidCallback openDrawer;
  final VoidCallback goToDashboard;

  static AppDrawerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppDrawerScope>();
  }

  @override
  bool updateShouldNotify(AppDrawerScope oldWidget) =>
      openDrawer != oldWidget.openDrawer ||
      goToDashboard != oldWidget.goToDashboard;
}

class OfflineSyncStatusAction extends StatelessWidget {
  const OfflineSyncStatusAction({required this.state, super.key});

  static const _offlineMessage = 'Offline — changes will sync when connected';
  final RemoteSyncState state;

  @override
  Widget build(BuildContext context) {
    final visible =
        state == RemoteSyncState.offline || state == RemoteSyncState.syncing;
    final syncing = state == RemoteSyncState.syncing;
    return SizedBox(
      width: 40,
      child: visible
          ? Semantics(
              label: syncing ? 'Synchronizing changes' : _offlineMessage,
              button: true,
              child: Tooltip(
                message: syncing ? 'Synchronizing changes' : _offlineMessage,
                child: IconButton(
                  iconSize: 21,
                  visualDensity: VisualDensity.compact,
                  onPressed: syncing
                      ? null
                      : () => ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          const SnackBar(
                            content: Text(_offlineMessage),
                            behavior: SnackBarBehavior.floating,
                          ),
                        ),
                  icon: Icon(
                    syncing
                        ? Icons.cloud_sync_outlined
                        : Icons.cloud_off_outlined,
                    color: syncing
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class AppPage extends StatelessWidget {
  const AppPage({
    required this.title,
    required this.subtitle,
    required this.slivers,
    this.action,
    this.maxWidth = 1100,
    this.bottomPadding = 24,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? action;
  final List<Widget> slivers;
  final double maxWidth;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.sizeOf(context).width >= 720
        ? AppSpacing.xxl
        : AppSpacing.md;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.xl,
            horizontalPadding,
            AppSpacing.md,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: PageHeader(
                  title: title,
                  subtitle: subtitle,
                  action: action,
                ),
              ),
            ),
          ),
        ),
        ...slivers,
        SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
      ],
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    required this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 640;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );

    if (action == null) {
      return text;
    }

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text,
          const SizedBox(height: AppSpacing.md),
          Align(alignment: Alignment.centerLeft, child: action),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: text),
        const SizedBox(width: AppSpacing.md),
        action!,
      ],
    );
  }
}

class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null || trailing != null) ...[
              Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    )
                  else
                    const Spacer(),
                  ?trailing,
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class AppMessageState extends StatelessWidget {
  const AppMessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.contained = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool contained;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colorScheme.primary, size: 34),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          ?action == null ? null : const SizedBox(height: AppSpacing.lg),
          ?action,
        ],
      ),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: contained ? AppSectionCard(child: content) : content,
      ),
    );
  }
}

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Loading your finances…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> showAppDeleteConfirmation({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.expense,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete'),
        ),
      ],
    ),
  );

  return confirmed == true;
}
