import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

typedef ConnectivityCheck = Future<List<ConnectivityResult>> Function();
typedef ReachabilityCheck = Future<bool> Function();

class ConnectivityWatcher {
  ConnectivityWatcher({
    required Stream<List<ConnectivityResult>> changes,
    required ConnectivityCheck checkConnectivity,
    required ReachabilityCheck checkReachability,
    required FutureOr<void> Function() onUnavailable,
    required FutureOr<void> Function() onAvailable,
    this.heartbeat = const Duration(seconds: 10),
  }) : _changes = changes,
       _checkConnectivity = checkConnectivity,
       _checkReachability = checkReachability,
       _onUnavailable = onUnavailable,
       _onAvailable = onAvailable;

  factory ConnectivityWatcher.forFirestore({
    required FutureOr<void> Function() onUnavailable,
    required FutureOr<void> Function() onAvailable,
  }) {
    final connectivity = Connectivity();
    return ConnectivityWatcher(
      changes: connectivity.onConnectivityChanged,
      checkConnectivity: connectivity.checkConnectivity,
      checkReachability: checkFirestoreReachability,
      onUnavailable: onUnavailable,
      onAvailable: onAvailable,
    );
  }

  final Stream<List<ConnectivityResult>> _changes;
  final ConnectivityCheck _checkConnectivity;
  final ReachabilityCheck _checkReachability;
  final FutureOr<void> Function() _onUnavailable;
  final FutureOr<void> Function() _onAvailable;
  final Duration heartbeat;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _timer;
  bool? _wasReachable;
  bool _checking = false;
  bool _disposed = false;

  void start() {
    if (_subscription != null) return;
    _subscription = _changes.listen((_) => unawaited(checkNow()));
    _timer = Timer.periodic(heartbeat, (_) => unawaited(checkNow()));
    unawaited(checkNow());
  }

  Future<void> checkNow() async {
    if (_checking || _disposed) return;
    _checking = true;
    try {
      final interfaces = await _checkConnectivity();
      final hasInterface = interfaces.any(
        (result) => result != ConnectivityResult.none,
      );
      final reachable = hasInterface && await _checkReachability();
      if (_disposed || reachable == _wasReachable) return;
      _wasReachable = reachable;
      if (reachable) {
        await _onAvailable();
      } else {
        await _onUnavailable();
      }
    } catch (_) {
      if (!_disposed && _wasReachable != false) {
        _wasReachable = false;
        await _onUnavailable();
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _subscription?.cancel();
  }
}

Future<bool> checkFirestoreReachability() async {
  Socket? socket;
  try {
    socket = await Socket.connect(
      'firestore.googleapis.com',
      443,
      timeout: const Duration(seconds: 3),
    );
    return true;
  } catch (_) {
    return false;
  } finally {
    socket?.destroy();
  }
}
