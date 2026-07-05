import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../application/services/csv_import_service.dart';
import '../../application/usecases/csv_import_use_cases.dart';
import '../../domain/entities/csv_import_preview.dart';

final csvImportServiceProvider = Provider<CsvImportService>((ref) {
  return const CsvImportService();
});

final confirmCsvImportUseCaseProvider =
    Provider.family<ConfirmCsvImportUseCase, String>((ref, userId) {
      return ConfirmCsvImportUseCase(
        ref.watch(transactionRepositoryProvider(userId)),
      );
    });

final csvImportControllerProvider =
    NotifierProvider.autoDispose<CsvImportController, CsvImportState>(
      CsvImportController.new,
    );

class CsvImportState {
  const CsvImportState({
    this.preview,
    this.operation = const AsyncData(null),
    this.result,
  });

  final CsvImportPreview? preview;
  final AsyncValue<void> operation;
  final CsvImportConfirmationResult? result;

  CsvImportState copyWith({
    CsvImportPreview? preview,
    AsyncValue<void>? operation,
    CsvImportConfirmationResult? result,
    bool clearPreview = false,
    bool clearResult = false,
  }) {
    return CsvImportState(
      preview: clearPreview ? null : preview ?? this.preview,
      operation: operation ?? this.operation,
      result: clearResult ? null : result ?? this.result,
    );
  }
}

class CsvImportController extends Notifier<CsvImportState> {
  @override
  CsvImportState build() {
    return const CsvImportState();
  }

  Future<void> pickAndPreview({
    required List<TransactionEntity> existingTransactions,
  }) async {
    state = state.copyWith(operation: const AsyncLoading(), clearResult: true);

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        state = state.copyWith(operation: const AsyncData(null));
        return;
      }

      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw const AppFailure(
          type: AppFailureType.validation,
          code: 'csv-file-not-readable',
          message: 'Unable to read this CSV file.',
        );
      }

      final content = utf8.decode(bytes, allowMalformed: true);
      final result = ref
          .read(csvImportServiceProvider)
          .buildPreview(
            fileName: file.name,
            content: content,
            existingTransactions: existingTransactions,
          );

      result.when(
        success: (preview) {
          state = state.copyWith(
            preview: preview,
            operation: const AsyncData(null),
          );
        },
        failure: (failure) {
          state = state.copyWith(
            operation: AsyncError(failure, StackTrace.current),
          );
        },
      );
    } catch (error, stackTrace) {
      state = state.copyWith(operation: AsyncError(error, stackTrace));
    }
  }

  Future<void> confirm({
    required String userId,
    required String accountId,
    required String expenseCategoryId,
    required String incomeCategoryId,
  }) async {
    final preview = state.preview;
    if (preview == null) {
      state = state.copyWith(
        operation: AsyncError(
          const AppFailure(
            type: AppFailureType.validation,
            code: 'missing-csv-preview',
            message: 'Preview a CSV file before importing.',
          ),
          StackTrace.current,
        ),
      );
      return;
    }

    state = state.copyWith(operation: const AsyncLoading(), clearResult: true);
    final result = await ref
        .read(confirmCsvImportUseCaseProvider(userId))
        .execute(
          ConfirmCsvImportCommand(
            preview: preview,
            accountId: accountId,
            expenseCategoryId: expenseCategoryId,
            incomeCategoryId: incomeCategoryId,
          ),
        );

    result.when(
      success: (value) {
        state = CsvImportState(result: value);
        ref.invalidate(transactionListProvider(userId));
      },
      failure: (failure) {
        state = state.copyWith(
          operation: AsyncError(failure, StackTrace.current),
        );
      },
    );
  }

  void clear() {
    state = const CsvImportState();
  }
}
