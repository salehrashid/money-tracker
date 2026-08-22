import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../application/usecases/notification_log_use_cases.dart';
import '../../application/usecases/notification_listener_use_cases.dart';
import '../../data/datasources/firebase_notification_log_data_source.dart';
import '../../data/datasources/notification_listener_method_channel_data_source.dart';
import '../../data/repositories/firebase_notification_log_repository.dart';
import '../../data/repositories/platform_notification_listener_repository.dart';
import '../../domain/entities/android_notification_payload.dart';
import '../../domain/entities/detected_transaction.dart';
import '../../domain/entities/notification_listener_status.dart';
import '../../domain/entities/notification_log.dart';
import '../../domain/repositories/notification_log_repository.dart';
import '../../domain/repositories/notification_listener_repository.dart';
import '../../domain/services/notification_filter.dart';

final notificationListenerDataSourceProvider =
    Provider<NotificationListenerMethodChannelDataSource>((ref) {
      final dataSource = NotificationListenerMethodChannelDataSource();
      ref.onDispose(dataSource.dispose);
      return dataSource;
    });

final notificationListenerRepositoryProvider =
    Provider<NotificationListenerRepository>((ref) {
      return PlatformNotificationListenerRepository(
        dataSource: ref.watch(notificationListenerDataSourceProvider),
        isSupported: PlatformNotificationListenerRepository.isAndroidSupported,
      );
    });

final notificationLogDataSourceProvider =
    Provider.family<FirebaseNotificationLogDataSource, String>((ref, userId) {
      return FirebaseNotificationLogDataSource(
        ref.watch(firestoreUserCollectionsProvider(userId)),
      );
    });

final notificationLogRepositoryProvider =
    Provider.family<NotificationLogRepository, String>((ref, userId) {
      return FirebaseNotificationLogRepository(
        dataSource: ref.watch(notificationLogDataSourceProvider(userId)),
      );
    });

final watchAndroidNotificationsUseCaseProvider =
    Provider<WatchAndroidNotificationsUseCase>((ref) {
      return WatchAndroidNotificationsUseCase(
        ref.watch(notificationListenerRepositoryProvider),
      );
    });

final getNotificationListenerStatusUseCaseProvider =
    Provider<GetNotificationListenerStatusUseCase>((ref) {
      return GetNotificationListenerStatusUseCase(
        ref.watch(notificationListenerRepositoryProvider),
      );
    });

final getRecentAndroidNotificationsUseCaseProvider =
    Provider<GetRecentAndroidNotificationsUseCase>((ref) {
      return GetRecentAndroidNotificationsUseCase(
        ref.watch(notificationListenerRepositoryProvider),
      );
    });

final openNotificationListenerSettingsUseCaseProvider =
    Provider<OpenNotificationListenerSettingsUseCase>((ref) {
      return OpenNotificationListenerSettingsUseCase(
        ref.watch(notificationListenerRepositoryProvider),
      );
    });

final requestConfirmationNotificationPermissionUseCaseProvider =
    Provider<RequestConfirmationNotificationPermissionUseCase>((ref) {
      return RequestConfirmationNotificationPermissionUseCase(
        ref.watch(notificationListenerRepositoryProvider),
      );
    });

final setMonitoredNotificationPackagesUseCaseProvider =
    Provider<SetMonitoredNotificationPackagesUseCase>((ref) {
      return SetMonitoredNotificationPackagesUseCase(
        ref.watch(notificationListenerRepositoryProvider),
      );
    });

final showNotificationReviewConfirmationUseCaseProvider =
    Provider<ShowNotificationReviewConfirmationUseCase>((ref) {
      return ShowNotificationReviewConfirmationUseCase(
        ref.watch(notificationListenerRepositoryProvider),
      );
    });

final getInitialTransactionReviewRequestUseCaseProvider =
    Provider<GetInitialTransactionReviewRequestUseCase>((ref) {
      return GetInitialTransactionReviewRequestUseCase(
        ref.watch(notificationListenerRepositoryProvider),
      );
    });

final watchTransactionReviewRequestsUseCaseProvider =
    Provider<WatchTransactionReviewRequestsUseCase>((ref) {
      return WatchTransactionReviewRequestsUseCase(
        ref.watch(notificationListenerRepositoryProvider),
      );
    });

final watchNotificationLogsUseCaseProvider =
    Provider.family<WatchNotificationLogsUseCase, String>((ref, userId) {
      return WatchNotificationLogsUseCase(
        ref.watch(notificationLogRepositoryProvider(userId)),
      );
    });

final saveNotificationDetectionUseCaseProvider =
    Provider.family<SaveNotificationDetectionUseCase, String>((ref, userId) {
      return SaveNotificationDetectionUseCase(
        ref.watch(notificationLogRepositoryProvider(userId)),
      );
    });

final markNotificationReadUseCaseProvider =
    Provider.family<MarkNotificationReadUseCase, String>((ref, userId) {
      return MarkNotificationReadUseCase(
        ref.watch(notificationLogRepositoryProvider(userId)),
      );
    });

final markAllNotificationsReadUseCaseProvider =
    Provider.family<MarkAllNotificationsReadUseCase, String>((ref, userId) {
      return MarkAllNotificationsReadUseCase(
        ref.watch(notificationLogRepositoryProvider(userId)),
      );
    });

final ignoreNotificationUseCaseProvider =
    Provider.family<IgnoreNotificationUseCase, String>((ref, userId) {
      return IgnoreNotificationUseCase(
        ref.watch(notificationLogRepositoryProvider(userId)),
      );
    });

final markNotificationProcessedUseCaseProvider =
    Provider.family<MarkNotificationProcessedUseCase, String>((ref, userId) {
      return MarkNotificationProcessedUseCase(
        ref.watch(notificationLogRepositoryProvider(userId)),
      );
    });

final deleteNotificationUseCaseProvider =
    Provider.family<DeleteNotificationUseCase, String>((ref, userId) {
      return DeleteNotificationUseCase(
        ref.watch(notificationLogRepositoryProvider(userId)),
      );
    });

final deleteNotificationsUseCaseProvider =
    Provider.family<DeleteNotificationsUseCase, String>((ref, userId) {
      return DeleteNotificationsUseCase(
        ref.watch(notificationLogRepositoryProvider(userId)),
      );
    });

final deleteReadNotificationsUseCaseProvider =
    Provider.family<DeleteReadNotificationsUseCase, String>((ref, userId) {
      return DeleteReadNotificationsUseCase(
        ref.watch(notificationLogRepositoryProvider(userId)),
      );
    });

final deleteOldNotificationsUseCaseProvider =
    Provider.family<DeleteOldNotificationsUseCase, String>((ref, userId) {
      return DeleteOldNotificationsUseCase(
        ref.watch(notificationLogRepositoryProvider(userId)),
      );
    });

final notificationListenerStatusProvider =
    FutureProvider.autoDispose<Result<NotificationListenerStatus>>((ref) {
      return ref.watch(getNotificationListenerStatusUseCaseProvider).execute();
    });

final androidNotificationPayloadProvider =
    StreamProvider.autoDispose<AndroidNotificationPayload>((ref) {
      return ref.watch(watchAndroidNotificationsUseCaseProvider).execute();
    });

final notificationAllowedPackageNamesProvider = Provider<Set<String>>((ref) {
  const simulatorPackageName = String.fromEnvironment(
    'MYBCA_SIMULATOR_PACKAGE',
  );
  return {
    'com.bca.mybca.omni.android',
    if (simulatorPackageName.trim().isNotEmpty) simulatorPackageName,
  };
});

final notificationFilterProvider = Provider<NotificationFilter>((ref) {
  return NotificationFilter(
    allowedPackageNames: ref.watch(notificationAllowedPackageNamesProvider),
  );
});

final androidNotificationDetectionResultProvider =
    StreamProvider.autoDispose<NotificationFilterResult>((ref) {
      final filter = ref.watch(notificationFilterProvider);
      return ref
          .watch(watchAndroidNotificationsUseCaseProvider)
          .execute()
          .map(filter.evaluate);
    });

final acceptedAndroidNotificationPayloadProvider =
    StreamProvider.autoDispose<NotificationFilterResult>((ref) {
      final filter = ref.watch(notificationFilterProvider);
      return ref
          .watch(watchAndroidNotificationsUseCaseProvider)
          .execute()
          .map(filter.evaluate)
          .where((result) => result.isAccepted);
    });

final notificationDetectionControllerProvider =
    Provider.autoDispose<NotificationDetectionController>((ref) {
      final controller = NotificationDetectionController(ref);
      controller.start();
      return controller;
    });

class NotificationDetectionController {
  const NotificationDetectionController(this._ref);

  final Ref _ref;

  void start() {
    _ref.listen<AsyncValue<NotificationFilterResult>>(
      androidNotificationDetectionResultProvider,
      (_, next) => next.whenData(_persistDetection),
    );
    _ref.listen(authStateProvider, (previous, next) {
      next.whenData(
        (result) => result.when(
          success: (user) {
            if (user != null) {
              _ref
                  .read(deleteOldNotificationsUseCaseProvider(user.id))
                  .execute();
            }
          },
          failure: (_) {},
        ),
      );
    }, fireImmediately: true);
  }

  Future<void> confirmDetection(NotificationFilterResult result) async {
    final transaction = result.detectedTransaction;
    if (transaction == null) {
      return;
    }

    await _ref
        .read(showNotificationReviewConfirmationUseCaseProvider)
        .execute(transaction);
  }

  Future<void> _persistDetection(NotificationFilterResult result) async {
    if (result.source == NotificationSource.unknown) {
      return;
    }

    final authResult = _ref.read(authStateProvider).asData?.value;
    final userId = authResult?.when(
      success: (user) => user?.id,
      failure: (_) => null,
    );
    if (userId == null) {
      return;
    }

    await _ref
        .read(saveNotificationDetectionUseCaseProvider(userId))
        .execute(result);
  }
}

final pendingDetectedTransactionProvider =
    NotifierProvider<
      PendingDetectedTransactionController,
      DetectedTransaction?
    >(PendingDetectedTransactionController.new);

class PendingDetectedTransactionController
    extends Notifier<DetectedTransaction?> {
  var _handledKeys = <String>{};

  @override
  DetectedTransaction? build() {
    Future.microtask(_loadInitialRequest);
    ref.listen<AsyncValue<DetectedTransaction>>(
      transactionReviewRequestStreamProvider,
      (_, next) => next.whenData(requestReview),
    );
    return null;
  }

  void requestReview(DetectedTransaction transaction) {
    final key = _keyFor(transaction);
    if (_handledKeys.contains(key)) {
      return;
    }
    _handledKeys = {..._handledKeys, key};
    state = transaction;
  }

  void markHandled(DetectedTransaction transaction) {
    if (state == transaction) {
      state = null;
      return;
    }
    if (state != null && _keyFor(state!) == _keyFor(transaction)) {
      state = null;
    }
  }

  Future<void> _loadInitialRequest() async {
    final result = await ref
        .read(getInitialTransactionReviewRequestUseCaseProvider)
        .execute();
    result.when(
      success: (transaction) {
        if (transaction != null) {
          requestReview(transaction);
        }
      },
      failure: (_) {},
    );
  }

  String _keyFor(DetectedTransaction transaction) {
    return [
      transaction.type.firestoreValue,
      transaction.amount.toStringAsFixed(2),
      transaction.detectedAt.millisecondsSinceEpoch,
      transaction.sourcePackage,
      transaction.description ?? '',
    ].join('|');
  }
}

final transactionReviewRequestStreamProvider =
    StreamProvider.autoDispose<DetectedTransaction>((ref) {
      return ref.watch(watchTransactionReviewRequestsUseCaseProvider).execute();
    });

final notificationLogListProvider =
    StreamProvider.family<Result<List<NotificationLog>>, String>((ref, userId) {
      return ref.watch(watchNotificationLogsUseCaseProvider(userId)).execute();
    });

final unreadNotificationCountProvider = Provider.family<int, String>((
  ref,
  userId,
) {
  final logsState = ref.watch(notificationLogListProvider(userId));
  return logsState.maybeWhen(
    data: (result) => result.when(
      success: (logs) => logs.where((log) => !log.isRead).length,
      failure: (_) => 0,
    ),
    orElse: () => 0,
  );
});

class NotificationDebugState {
  const NotificationDebugState({
    required this.status,
    required this.results,
    this.message,
  });

  final AsyncValue<Result<NotificationListenerStatus>> status;
  final List<NotificationFilterResult> results;
  final String? message;

  NotificationDebugState copyWith({
    AsyncValue<Result<NotificationListenerStatus>>? status,
    List<NotificationFilterResult>? results,
    String? message,
    bool clearMessage = false,
  }) {
    return NotificationDebugState(
      status: status ?? this.status,
      results: results ?? this.results,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final notificationDebugControllerProvider =
    NotifierProvider.autoDispose<
      NotificationDebugController,
      NotificationDebugState
    >(NotificationDebugController.new);

class NotificationDebugController extends Notifier<NotificationDebugState> {
  @override
  NotificationDebugState build() {
    ref.listen<AsyncValue<NotificationFilterResult>>(
      androidNotificationDetectionResultProvider,
      (previous, next) {
        next.whenData(_prependResult);
      },
    );

    Future.microtask(refresh);

    return const NotificationDebugState(
      status: AsyncValue.loading(),
      results: [],
    );
  }

  Future<void> refresh() async {
    state = state.copyWith(
      status: const AsyncValue.loading(),
      clearMessage: true,
    );

    final statusResult = await ref
        .read(getNotificationListenerStatusUseCaseProvider)
        .execute();
    final recentResult = await ref
        .read(getRecentAndroidNotificationsUseCaseProvider)
        .execute();
    final allowedPackageNames = ref.read(
      notificationAllowedPackageNamesProvider,
    );

    final results = recentResult.when(
      success: (value) {
        final filter = NotificationFilter(
          allowedPackageNames: allowedPackageNames,
        );
        return value.map(filter.evaluate).toList().reversed.toList();
      },
      failure: (_) => state.results,
    );

    state = state.copyWith(
      status: AsyncValue.data(statusResult),
      results: results,
      message: recentResult.when(
        success: (_) => null,
        failure: (failure) => failure.message,
      ),
    );
  }

  Future<void> openNotificationAccessSettings() async {
    final result = await ref
        .read(openNotificationListenerSettingsUseCaseProvider)
        .execute();
    state = state.copyWith(
      message: result.when(
        success: (_) => 'Opened Notification Access settings.',
        failure: (failure) => failure.message,
      ),
    );
  }

  Future<void> requestConfirmationNotificationPermission() async {
    final result = await ref
        .read(requestConfirmationNotificationPermissionUseCaseProvider)
        .execute();
    state = state.copyWith(
      message: result.when(
        success: (_) => 'Requested notification permission.',
        failure: (failure) => failure.message,
      ),
    );
  }

  void clearNotifications() {
    state = state.copyWith(results: []);
  }

  void _prependResult(NotificationFilterResult result) {
    state = state.copyWith(
      results: [result, ...state.results].take(100).toList(),
      clearMessage: true,
    );
  }
}
