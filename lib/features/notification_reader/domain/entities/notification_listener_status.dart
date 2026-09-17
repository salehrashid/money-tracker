class NotificationListenerStatus {
  const NotificationListenerStatus({
    required this.isSupported,
    required this.isListenerEnabled,
    required this.areConfirmationNotificationsAllowed,
    required this.monitoredPackages,
    required this.capturesAllPackagesInDebug,
    this.listenerConnected = false,
    this.lastConnectedAt,
    this.lastDisconnectedAt,
    this.lastNotificationAt,
    this.lastRebindRequestedAt,
    this.rebindAttempts = 0,
    this.processStartedAt,
  });

  final bool isSupported;
  final bool isListenerEnabled;
  final bool areConfirmationNotificationsAllowed;
  final List<String> monitoredPackages;
  final bool capturesAllPackagesInDebug;
  final bool listenerConnected;
  final DateTime? lastConnectedAt;
  final DateTime? lastDisconnectedAt;
  final DateTime? lastNotificationAt;
  final DateTime? lastRebindRequestedAt;
  final int rebindAttempts;
  final DateTime? processStartedAt;

  bool get canListen =>
      isSupported &&
      isListenerEnabled &&
      listenerConnected &&
      (monitoredPackages.isNotEmpty || capturesAllPackagesInDebug);
}
