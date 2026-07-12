import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/features/notification_reader/domain/entities/android_notification_payload.dart';

void main() {
  group('AndroidNotificationPayload', () {
    test('maps safe platform notification fields', () {
      final payload = AndroidNotificationPayload.fromPlatformMap({
        'packageName': 'com.mybca',
        'appName': 'myBCA',
        'title': 'Catatan Finansial',
        'body': 'Pengeluaran sebesar IDR 10.000',
        'receivedAtMillis': 1700000000000,
      });

      expect(payload.packageName, 'com.mybca');
      expect(payload.appName, 'myBCA');
      expect(payload.title, 'Catatan Finansial');
      expect(payload.body, 'Pengeluaran sebesar IDR 10.000');
      expect(payload.hasContent, isTrue);
      expect(payload.receivedAt.millisecondsSinceEpoch, 1700000000000);
    });

    test('dedupe hash is stable for the same notification fields', () {
      final receivedAt = DateTime(2026);
      final first = AndroidNotificationPayload(
        packageName: 'com.mybca',
        appName: 'myBCA',
        title: 'Catatan Finansial',
        body: 'Pemasukan sebesar IDR 25.000',
        receivedAt: receivedAt,
      );
      final second = AndroidNotificationPayload(
        packageName: 'com.mybca',
        appName: 'myBCA',
        title: 'Catatan Finansial',
        body: 'Pemasukan sebesar IDR 25.000',
        receivedAt: receivedAt,
      );

      expect(first.dedupeHash, second.dedupeHash);
      expect(first.dedupeHash, hasLength(16));
    });
  });
}
