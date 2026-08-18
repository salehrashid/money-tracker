import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/notification_listener_status.dart';
import '../../domain/services/notification_filter.dart';
import '../providers/notification_listener_providers.dart';

class NotificationDebugPage extends ConsumerWidget {
  const NotificationDebugPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final state = ref.watch(notificationDebugControllerProvider);
    final notifier = ref.read(notificationDebugControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Debug'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: notifier.refresh,
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.clear_all),
            onPressed: notifier.clearNotifications,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PermissionPanel(
              status: state.status,
              message: state.message,
              onOpenSettings: notifier.openNotificationAccessSettings,
              onRequestPostPermission:
                  notifier.requestConfirmationNotificationPermission,
            ),
            const SizedBox(height: 16),
            Text(
              'Received notifications (${state.results.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (state.results.isEmpty)
              const _EmptyNotifications()
            else
              for (final result in state.results)
                _NotificationDebugCard(result: result),
          ],
        ),
      ),
    );
  }
}

class _PermissionPanel extends StatelessWidget {
  const _PermissionPanel({
    required this.status,
    required this.onOpenSettings,
    required this.onRequestPostPermission,
    this.message,
  });

  final AsyncValue<Result<NotificationListenerStatus>> status;
  final String? message;
  final VoidCallback onOpenSettings;
  final VoidCallback onRequestPostPermission;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: status.when(
          loading: () => const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Checking notification access...'),
            ],
          ),
          error: (_, _) => _PermissionContent(
            title: 'Unable to check notification access',
            message:
                'Open Android Notification Access and enable Fleeca.',
            color: colorScheme.error,
            onOpenSettings: onOpenSettings,
            onRequestPostPermission: onRequestPostPermission,
            detail: message,
          ),
          data: (result) => result.when(
            success: (value) => _PermissionContent(
              title: value.isListenerEnabled
                  ? 'Notification Access enabled'
                  : 'Notification Access is off',
              message: value.isListenerEnabled
                  ? 'Waiting for posted notifications.'
                  : 'Enable Fleeca in Android Notification Access.',
              color: value.isListenerEnabled
                  ? colorScheme.primary
                  : colorScheme.error,
              onOpenSettings: onOpenSettings,
              onRequestPostPermission: onRequestPostPermission,
              detail: [
                'Supported: ${value.isSupported}',
                'Post notifications allowed: '
                    '${value.areConfirmationNotificationsAllowed}',
                'Raw listener captures all in debug: '
                    '${value.capturesAllPackagesInDebug}',
                'Monitored packages: ${value.monitoredPackages.join(', ')}',
                ?message,
              ].join('\n'),
            ),
            failure: (failure) => _PermissionContent(
              title: 'Unable to check notification access',
              message: failure.message,
              color: colorScheme.error,
              onOpenSettings: onOpenSettings,
              onRequestPostPermission: onRequestPostPermission,
              detail: message,
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionContent extends StatelessWidget {
  const _PermissionContent({
    required this.title,
    required this.message,
    required this.color,
    required this.onOpenSettings,
    required this.onRequestPostPermission,
    this.detail,
  });

  final String title;
  final String message;
  final Color color;
  final VoidCallback onOpenSettings;
  final VoidCallback onRequestPostPermission;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notifications_active_outlined, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(message),
        if (detail != null && detail!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(detail!),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Notification Access'),
            ),
            OutlinedButton.icon(
              onPressed: onRequestPostPermission,
              icon: const Icon(Icons.notification_add_outlined),
              label: const Text('Post Permission'),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No Android notifications received yet.'),
      ),
    );
  }
}

class _NotificationDebugCard extends StatelessWidget {
  const _NotificationDebugCard({required this.result});

  final NotificationFilterResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final notification = result.notification;
    final time = notification.postTime ?? notification.receivedAt;
    final transaction = result.detectedTransaction;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    result.isAccepted
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: result.isAccepted
                        ? colorScheme.primary
                        : colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.isAccepted ? 'Transaction detected' : 'Ignored',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(label: 'Classification', value: result.type.logValue),
              _Field(label: 'Source', value: result.source.name),
              _Field(
                label: 'Type',
                value: transaction?.type.firestoreValue ?? '',
              ),
              _Field(
                label: 'Amount',
                value: transaction?.amount.toStringAsFixed(0) ?? '',
              ),
              _Field(label: 'Package', value: notification.packageName),
              _Field(label: 'Application', value: notification.appName),
              _Field(
                label: 'Notification Key',
                value: notification.notificationKey,
              ),
              _Field(label: 'Title', value: notification.title),
              _Field(label: 'Body', value: notification.body),
              _Field(label: 'Sub Text', value: notification.subText),
              _Field(label: 'Big Text', value: notification.bigText),
              if (notification.textLines.isNotEmpty)
                _Field(
                  label: 'Text Lines',
                  value: notification.textLines.join('\n'),
                ),
              _Field(
                label: 'Normalized Text',
                value: result.normalizedNotification.searchableText,
              ),
              _Field(label: 'Channel ID', value: notification.channelId),
              _Field(label: 'Time', value: _formatTime(time)),
              _Field(
                label: 'Notification ID',
                value: notification.notificationId?.toString() ?? '',
              ),
              _Field(label: 'Tag', value: notification.tag),
              _Field(label: 'Ticker', value: notification.ticker),
              _Field(label: 'Result', value: notification.result),
              if (notification.extras.isNotEmpty)
                _Field(
                  label: 'Extras',
                  value: notification.extras.entries
                      .map((entry) => '${entry.key}: ${entry.value}')
                      .join('\n'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return [
      twoDigits(time.hour),
      twoDigits(time.minute),
      twoDigits(time.second),
    ].join(':');
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          SelectableText(value.trim().isEmpty ? '-' : value),
        ],
      ),
    );
  }
}
