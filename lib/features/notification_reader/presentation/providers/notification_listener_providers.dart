import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../application/usecases/notification_listener_use_cases.dart';
import '../../data/datasources/notification_listener_method_channel_data_source.dart';
import '../../data/repositories/platform_notification_listener_repository.dart';
import '../../domain/entities/android_notification_payload.dart';
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

final acceptedAndroidNotificationPayloadProvider =
    StreamProvider.autoDispose<AndroidNotificationPayload>((ref) {
      final filter = ref.watch(notificationFilterProvider);
      return ref
          .watch(watchAndroidNotificationsUseCaseProvider)
          .execute()
          .map(filter.evaluate)
          .where((result) => result.isAccepted)
          .map((result) => result.notification);
    });

final notificationDetectionControllerProvider =
    Provider.autoDispose<NotificationDetectionController>((ref) {
      final controller = NotificationDetectionController(ref);
      ref.listen<AsyncValue<AndroidNotificationPayload>>(
        acceptedAndroidNotificationPayloadProvider,
        (previous, next) => next.whenData(controller.confirmDetection),
      );
      return controller;
    });

class NotificationDetectionController {
  const NotificationDetectionController(this._ref);

  final Ref _ref;

  Future<void> confirmDetection(AndroidNotificationPayload notification) async {
    await _ref
        .read(showNotificationReviewConfirmationUseCaseProvider)
        .execute(notification);
  }
}

class NotificationDebugState {
  const NotificationDebugState({
    required this.status,
    required this.notifications,
    this.message,
  });

  final AsyncValue<Result<NotificationListenerStatus>> status;
  final List<AndroidNotificationPayload> notifications;
  final String? message;

  NotificationDebugState copyWith({
    AsyncValue<Result<NotificationListenerStatus>>? status,
    List<AndroidNotificationPayload>? notifications,
    String? message,
    bool clearMessage = false,
  }) {
    return NotificationDebugState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
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
    ref.listen<AsyncValue<AndroidNotificationPayload>>(
      acceptedAndroidNotificationPayloadProvider,
      (previous, next) {
        next.whenData(_prependNotification);
      },
    );

    Future.microtask(refresh);

    return const NotificationDebugState(
      status: AsyncValue.loading(),
      notifications: [],
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

    final notifications = recentResult.when(
      success: (value) {
        final filter = NotificationFilter(
          allowedPackageNames: allowedPackageNames,
        );
        return value
            .map(filter.evaluate)
            .where((result) => result.isAccepted)
            .map((result) => result.notification)
            .toList()
            .reversed
            .toList();
      },
      failure: (_) => state.notifications,
    );

    state = state.copyWith(
      status: AsyncValue.data(statusResult),
      notifications: notifications,
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
    state = state.copyWith(notifications: []);
  }

  void _prependNotification(AndroidNotificationPayload payload) {
    state = state.copyWith(
      notifications: [payload, ...state.notifications].take(100).toList(),
      clearMessage: true,
    );
  }
}
