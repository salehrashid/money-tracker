import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_page.dart';
import '../domain/backup_models.dart';
import 'backup_providers.dart';

class BackupDataPage extends ConsumerStatefulWidget {
  const BackupDataPage({required this.userId, super.key});
  final String userId;

  @override
  ConsumerState<BackupDataPage> createState() => _BackupDataPageState();
}

class _BackupDataPageState extends ConsumerState<BackupDataPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(
        title: 'Backup & Data',
        subtitle: 'Private, local data portability',
        showBackButton: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _Section(
                title: 'Backup & Restore',
                children: [
                  _Action(
                    icon: Icons.backup_outlined,
                    title: 'Create Backup',
                    subtitle: 'Complete Fleeca backup (.xlsx)',
                    onTap: _busy ? null : () => _export(BackupFileFormat.xlsx),
                  ),
                  _Action(
                    icon: Icons.restore,
                    title: 'Restore Backup',
                    subtitle: 'Preview and restore a Fleeca backup',
                    onTap: _busy ? null : _restore,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _Section(
                title: 'Export',
                children: [
                  _Action(
                    icon: Icons.table_view_outlined,
                    title: 'Export All Data (.xlsx)',
                    subtitle: 'One workbook with related datasets',
                    onTap: _busy ? null : () => _export(BackupFileFormat.xlsx),
                  ),
                  _Action(
                    icon: Icons.folder_zip_outlined,
                    title: 'Export All Data (.csv.zip)',
                    subtitle: 'CSV datasets in a ZIP archive',
                    onTap: _busy
                        ? null
                        : () => _export(BackupFileFormat.csvZip),
                  ),
                  _Action(
                    icon: Icons.receipt_long_outlined,
                    title: 'Export Transactions Only',
                    subtitle: 'Readable spreadsheet for analysis',
                    onTap: _busy ? null : _exportTransactions,
                  ),
                ],
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export(BackupFileFormat format) async {
    await _run(() async {
      final backup = ref
          .read(backupServiceProvider(widget.userId))
          .createBackup(widget.userId);
      final extension = format == BackupFileFormat.xlsx ? 'xlsx' : 'zip';
      final name = 'fleeca_backup_${_stamp(DateTime.now())}.$extension';
      final path = await ref
          .read(backupFileServiceProvider)
          .save(
            ref
                .read(backupServiceProvider(widget.userId))
                .encode(backup, format),
            name,
            extension,
          );
      if (path != null && mounted)
        _message('Backup created: $name (${backup.totalRecords} records).');
    });
  }

  Future<void> _exportTransactions() async {
    await _run(() async {
      final service = ref.read(backupServiceProvider(widget.userId));
      final backup = service.createBackup(widget.userId);
      final name = 'fleeca_transactions_${_stamp(DateTime.now())}.xlsx';
      final path = await ref
          .read(backupFileServiceProvider)
          .save(service.encodeTransactions(backup), name, 'xlsx');
      if (path != null && mounted)
        _message('Transaction export created: $name.');
    });
  }

  Future<void> _restore() async {
    await _run(() async {
      final picked = await ref.read(backupFileServiceProvider).pickBackup();
      if (picked == null || !mounted) return;
      final preview = ref
          .read(backupServiceProvider(widget.userId))
          .preview(picked.bytes, picked.name);
      final mode = await showDialog<ImportMode>(
        context: context,
        builder: (_) => _PreviewDialog(fileName: picked.name, preview: preview),
      );
      if (mode == null || !mounted) return;
      if (mode == ImportMode.replace) {
        final confirmed =
            await showDialog<bool>(
              context: context,
              builder: (_) => const _ReplaceDialog(),
            ) ??
            false;
        if (!confirmed) return;
      }
      final result = await ref
          .read(backupServiceProvider(widget.userId))
          .import(widget.userId, preview.backup, mode);
      if (mounted)
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            icon: const Icon(Icons.check_circle_outline),
            title: const Text('Import Complete'),
            content: Text(
              'Inserted ${result.inserted}\nUpdated ${result.updated}\nSkipped ${result.skipped}\n\nChanges are stored locally and will sync when a connection is available.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on BackupException catch (error) {
      if (mounted) _message(error.message, error: true);
    } catch (_) {
      if (mounted)
        _message(
          'The operation could not be completed. No data was changed.',
          error: true,
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );

  String _stamp(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}_${date.hour.toString().padLeft(2, '0')}${date.minute.toString().padLeft(2, '0')}${date.second.toString().padLeft(2, '0')}';
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ...children,
        ],
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _PreviewDialog extends StatefulWidget {
  const _PreviewDialog({required this.fileName, required this.preview});
  final String fileName;
  final BackupPreview preview;
  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  ImportMode mode = ImportMode.merge;
  @override
  Widget build(BuildContext context) {
    final entries = widget.preview.backup.datasets.entries.where(
      (entry) => entry.value.isNotEmpty,
    );
    return AlertDialog(
      title: const Text('Import Fleeca Data'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.fileName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(_label(entry.key))),
                      Text('${entry.value.length}'),
                    ],
                  ),
                ),
              const Divider(),
              Text(
                'Total records: ${widget.preview.backup.totalRecords}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final warning in widget.preview.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(warning),
                ),
              const SizedBox(height: 12),
              RadioGroup<ImportMode>(
                groupValue: mode,
                onChanged: (value) => setState(() => mode = value!),
                child: const Column(
                  children: [
                    RadioListTile(
                      value: ImportMode.merge,
                      title: Text('Merge with existing data'),
                      subtitle: Text(
                        'Newer records win; existing IDs are not duplicated',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile(
                      value: ImportMode.replace,
                      title: Text('Replace all existing data'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, mode),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  String _label(String value) => value
      .split('_')
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _ReplaceDialog extends StatelessWidget {
  const _ReplaceDialog();
  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: Icon(
      Icons.warning_amber_rounded,
      color: Theme.of(context).colorScheme.error,
    ),
    title: const Text('Replace Existing Data?'),
    content: const Text(
      'This will replace your current accounts, categories, transactions, debts, loans, and settings with the selected backup.\n\nThis cannot be undone unless you have another backup.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Replace & Import'),
      ),
    ],
  );
}
