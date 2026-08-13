import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../application/usecases/notification_listener_use_cases.dart';
import '../../data/datasources/notification_listener_method_channel_data_source.dart';
import '../../data/repositories/platform_notification_listener_repository.dart';
import '../../domain/entities/android_notification_payload.dart';
import '../../domain/entities/detected_transaction.dart';
import '../../domain/entities/notification_listener_status.dart';
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
      // Removed confirmDetection call since native now handles it
      return controller;
    });

class NotificationDetectionController {
  const NotificationDetectionController(this._ref);

  final Ref _ref;

  Future<void> confirmDetection(NotificationFilterResult result) async {
    final transaction = result.detectedTransaction;
    if (transaction == null) {
      return;
    }

    await _ref
        .read(showNotificationReviewConfirmationUseCaseProvider)
        .execute(transaction);
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
