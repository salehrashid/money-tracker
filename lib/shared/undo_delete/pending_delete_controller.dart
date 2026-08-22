import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';

const deleteUndoDuration = Duration(seconds: 5);

enum PendingDeleteStatus { pending, committing }

class PendingDeletion {
  const PendingDeletion({
    required this.operationKey,
    required this.itemKeys,
    required this.items,
    required this.startedAt,
    required this.duration,
    this.status = PendingDeleteStatus.pending,
  });

  final String operationKey;
  final Set<String> itemKeys;
  final List<Object> items;
  final DateTime startedAt;
  final Duration duration;
  final PendingDeleteStatus status;

  PendingDeletion copyWith({PendingDeleteStatus? status}) {
    return PendingDeletion(
      operationKey: operationKey,
      itemKeys: itemKeys,
      items: items,
      startedAt: startedAt,
      duration: duration,
      status: status ?? this.status,
    );
  }
}

class PendingDeleteFailure {
  const PendingDeleteFailure({required this.serial, required this.message});

  final int serial;
  final String message;
}

final pendingDeleteFailureProvider =
    NotifierProvider<PendingDeleteFailureNotifier, PendingDeleteFailure?>(
      PendingDeleteFailureNotifier.new,
    );

class PendingDeleteFailureNotifier extends Notifier<PendingDeleteFailure?> {
  int _serial = 0;

  @override
  PendingDeleteFailure? build() => null;

  void report(String message) {
    state = PendingDeleteFailure(serial: ++_serial, message: message);
  }
}

final pendingDeleteControllerProvider =
    NotifierProvider<PendingDeleteController, Map<String, PendingDeletion>>(
      PendingDeleteController.new,
    );

class PendingDeleteController extends Notifier<Map<String, PendingDeletion>> {
  final Map<String, _PendingDeleteOperation> _operations = {};

  @override
  Map<String, PendingDeletion> build() {
    ref.onDispose(() {
      for (final operation in _operations.values) {
        operation.timer.cancel();
      }
      _operations.clear();
    });
    return const {};
  }

  bool begin({
    required String operationKey,
    required Set<String> itemKeys,
    required List<Object> items,
    required Future<Result<void>> Function() commitDelete,
    required String failureMessage,
    Duration duration = deleteUndoDuration,
  }) {
    if (_operations.containsKey(operationKey) || itemKeys.any(isItemPending)) {
      return false;
    }

    final deletion = PendingDeletion(
      operationKey: operationKey,
      itemKeys: Set.unmodifiable(itemKeys),
      items: List.unmodifiable(items),
      startedAt: DateTime.now(),
      duration: duration,
    );
    final operation = _PendingDeleteOperation(
      deletion: deletion,
      commitDelete: commitDelete,
      failureMessage: failureMessage,
    );
    operation.timer = Timer(duration, () => commit(operationKey));
    _operations[operationKey] = operation;
    state = {...state, operationKey: deletion};
    // Pending operations intentionally live only in memory. If the process is
    // terminated during the grace period, no persistent delete has been sent,
    // so the original record remains intact on the next launch.
    return true;
  }

  bool isItemPending(String itemKey) {
    return state.values.any((deletion) => deletion.itemKeys.contains(itemKey));
  }

  void undo(String operationKey) {
    final operation = _operations[operationKey];
    if (operation == null ||
        operation.deletion.status != PendingDeleteStatus.pending) {
      return;
    }

    operation.timer.cancel();
    _remove(operationKey);
  }

  Future<void> commit(String operationKey) async {
    final operation = _operations[operationKey];
    if (operation == null ||
        operation.deletion.status != PendingDeleteStatus.pending) {
      return;
    }

    operation.timer.cancel();
    operation.deletion = operation.deletion.copyWith(
      status: PendingDeleteStatus.committing,
    );
    state = {...state, operationKey: operation.deletion};

    try {
      final result = await operation.commitDelete();
      result.when(
        success: (_) => _remove(operationKey),
        failure: (failure) {
          debugPrint('Pending delete $operationKey failed: ${failure.code}');
          _remove(operationKey);
          ref
              .read(pendingDeleteFailureProvider.notifier)
              .report(operation.failureMessage);
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Pending delete $operationKey failed: $error\n$stackTrace');
      _remove(operationKey);
      ref
          .read(pendingDeleteFailureProvider.notifier)
          .report(operation.failureMessage);
    }
  }

  void _remove(String operationKey) {
    _operations.remove(operationKey);
    final next = {...state}..remove(operationKey);
    state = next;
  }
}

class _PendingDeleteOperation {
  _PendingDeleteOperation({
    required this.deletion,
    required this.commitDelete,
    required this.failureMessage,
  });

  PendingDeletion deletion;
  final Future<Result<void>> Function() commitDelete;
  final String failureMessage;
  late Timer timer;
}

String pendingDeleteItemKey(String type, String userId, String itemId) {
  return '$type:$userId:$itemId';
}
