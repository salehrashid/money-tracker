class NotificationListenerStatus {
  const NotificationListenerStatus({
    required this.isSupported,
    required this.isListenerEnabled,
    required this.areConfirmationNotificationsAllowed,
    required this.monitoredPackages,
    required this.capturesAllPackagesInDebug,
  });

  final bool isSupported;
  final bool isListenerEnabled;
  final bool areConfirmationNotificationsAllowed;
  final List<String> monitoredPackages;
  final bool capturesAllPackagesInDebug;

  bool get canListen =>
      isSupported &&
      isListenerEnabled &&
      (monitoredPackages.isNotEmpty || capturesAllPackagesInDebug);
}
