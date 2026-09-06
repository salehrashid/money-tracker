class BackupMetadata {
  const BackupMetadata({
    required this.appName,
    required this.format,
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.platform,
  });

  static const currentSchemaVersion = 1;
  static const formatIdentifier = 'fleeca_backup';

  final String appName;
  final String format;
  final int schemaVersion;
  final String appVersion;
  final DateTime exportedAt;
  final String platform;
}

class FleecaBackup {
  const FleecaBackup({required this.metadata, required this.datasets});

  final BackupMetadata metadata;
  final Map<String, List<Map<String, dynamic>>> datasets;

  int get totalRecords =>
      datasets.values.fold(0, (sum, rows) => sum + rows.length);
}

enum BackupFileFormat { xlsx, csvZip }

enum ImportMode { merge, replace }

class BackupPreview {
  const BackupPreview({required this.backup, required this.warnings});
  final FleecaBackup backup;
  final List<String> warnings;
}

class ImportResult {
  const ImportResult({
    required this.inserted,
    required this.updated,
    required this.skipped,
  });
  final int inserted;
  final int updated;
  final int skipped;
  int get total => inserted + updated + skipped;
}

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class BackupMigration {
  int get fromVersion;
  int get toVersion;
  FleecaBackup migrate(FleecaBackup backup);
}
