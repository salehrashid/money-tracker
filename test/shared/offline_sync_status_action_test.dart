import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/offline/sync_status.dart';
import 'package:money_tracker/shared/widgets/app_page.dart';

void main() {
  Widget subject(RemoteSyncState state) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(actions: [OfflineSyncStatusAction(state: state)]),
      ),
    );
  }

  testWidgets('shows an accessible cloud-off action while offline', (
    tester,
  ) async {
    await tester.pumpWidget(subject(RemoteSyncState.offline));

    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(
      find.byTooltip('Offline — changes will sync when connected'),
      findsOneWidget,
    );
  });

  testWidgets('keeps reserved space but hides the icon when online', (
    tester,
  ) async {
    await tester.pumpWidget(subject(RemoteSyncState.online));

    expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
    expect(find.byType(OfflineSyncStatusAction), findsOneWidget);
  });
}
