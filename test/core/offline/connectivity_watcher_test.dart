import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/offline/connectivity_watcher.dart';

void main() {
  test('reports loss and recovery while the app remains running', () async {
    final changes = StreamController<List<ConnectivityResult>>.broadcast();
    var interfaces = <ConnectivityResult>[ConnectivityResult.wifi];
    var reachable = true;
    var unavailableCalls = 0;
    var availableCalls = 0;
    final watcher = ConnectivityWatcher(
      changes: changes.stream,
      checkConnectivity: () async => interfaces,
      checkReachability: () async => reachable,
      onUnavailable: () => unavailableCalls++,
      onAvailable: () => availableCalls++,
      heartbeat: const Duration(days: 1),
    )..start();
    addTearDown(() async {
      await watcher.dispose();
      await changes.close();
    });

    await _waitFor(() => availableCalls == 1);

    interfaces = [ConnectivityResult.none];
    changes.add(interfaces);
    await _waitFor(() => unavailableCalls == 1);

    interfaces = [ConnectivityResult.wifi];
    reachable = true;
    changes.add(interfaces);
    await _waitFor(() => availableCalls == 2);
  });

  test('reports Wi-Fi without internet as unavailable', () async {
    final changes = StreamController<List<ConnectivityResult>>.broadcast();
    var unavailableCalls = 0;
    final watcher = ConnectivityWatcher(
      changes: changes.stream,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      checkReachability: () async => false,
      onUnavailable: () => unavailableCalls++,
      onAvailable: () {},
      heartbeat: const Duration(days: 1),
    )..start();
    addTearDown(() async {
      await watcher.dispose();
      await changes.close();
    });

    await _waitFor(() => unavailableCalls == 1);
  });
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 20 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}
