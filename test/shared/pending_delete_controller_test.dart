import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/errors/app_failure.dart';
import 'package:money_tracker/core/utils/result.dart';
import 'package:money_tracker/shared/undo_delete/pending_delete_controller.dart';

void main() {
  test('undo cancels the pending persistent delete', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(pendingDeleteControllerProvider.notifier);
    var commits = 0;

    controller.begin(
      operationKey: 'transaction:user:1',
      itemKeys: {'transaction:user:1'},
      items: const ['snapshot'],
      duration: const Duration(milliseconds: 20),
      failureMessage: 'failed',
      commitDelete: () async {
        commits++;
        return const Success(null);
      },
    );
    controller.undo('transaction:user:1');
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(commits, 0);
    expect(container.read(pendingDeleteControllerProvider), isEmpty);
  });

  test('timer commits a pending delete exactly once', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(pendingDeleteControllerProvider.notifier);
    var commits = 0;

    controller.begin(
      operationKey: 'debt:user:1',
      itemKeys: {'debt:user:1'},
      items: const ['snapshot'],
      duration: const Duration(milliseconds: 10),
      failureMessage: 'failed',
      commitDelete: () async {
        commits++;
        return const Success(null);
      },
    );
    await Future.wait([
      Future<void>.delayed(const Duration(milliseconds: 25)),
      controller.commit('debt:user:1'),
    ]);

    expect(commits, 1);
    expect(container.read(pendingDeleteControllerProvider), isEmpty);
  });

  test('failed commit restores visibility and publishes safe error', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(pendingDeleteControllerProvider.notifier);

    controller.begin(
      operationKey: 'category:user:1',
      itemKeys: {'category:user:1'},
      items: const ['snapshot'],
      duration: const Duration(hours: 1),
      failureMessage: 'Could not delete category. Please try again.',
      commitDelete: () async => const Failure(
        AppFailure(
          type: AppFailureType.network,
          code: 'raw-backend-code',
          message: 'raw backend message',
        ),
      ),
    );
    await controller.commit('category:user:1');

    expect(container.read(pendingDeleteControllerProvider), isEmpty);
    expect(
      container.read(pendingDeleteFailureProvider)?.message,
      'Could not delete category. Please try again.',
    );
  });

  test('independent pending deletes do not replace each other', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(pendingDeleteControllerProvider.notifier);

    for (final id in ['1', '2', '3']) {
      controller.begin(
        operationKey: 'notification:user:$id',
        itemKeys: {'notification:user:$id'},
        items: [id],
        duration: const Duration(hours: 1),
        failureMessage: 'failed',
        commitDelete: () async => const Success(null),
      );
    }

    expect(container.read(pendingDeleteControllerProvider), hasLength(3));
    controller.undo('notification:user:2');
    expect(container.read(pendingDeleteControllerProvider).keys, {
      'notification:user:1',
      'notification:user:3',
    });
  });
}
