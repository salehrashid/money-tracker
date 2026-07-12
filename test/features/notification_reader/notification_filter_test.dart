import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/features/notification_reader/domain/entities/android_notification_payload.dart';
import 'package:money_tracker/features/notification_reader/domain/services/notification_filter.dart';

void main() {
  group('NotificationFilter', () {
    test('accepts myBCA Catatan Finansial expense notification', () {
      final filter = NotificationFilter();

      final result = filter.evaluate(
        _notification(
          packageName: 'com.bca.mybca.omni.android',
          title: 'Catatan Finansial',
          body: 'Pengeluaran sebesar IDR 50,000.00 untuk Transfer Rekening.',
        ),
      );

      expect(result.type, NotificationFilterResultType.accepted);
      expect(result.amount, 50000);
    });

    test('accepts configured simulator package', () {
      final filter = NotificationFilter(
        allowedPackageNames: const {
          'com.bca.mybca.omni.android',
          'com.example.mybca_simulator',
        },
      );

      final result = filter.evaluate(
        _notification(
          packageName: 'com.example.mybca_simulator',
          title: 'Catatan Finansial',
          body: 'Pemasukan sebesar IDR 2,500.00 untuk Transfer Rekening.',
        ),
      );

      expect(result.type, NotificationFilterResultType.accepted);
      expect(result.amount, 2500);
    });

    test('rejects other app packages before title or body checks', () {
      final filter = NotificationFilter();

      final result = filter.evaluate(
        _notification(
          packageName: 'com.whatsapp',
          title: 'Catatan Finansial',
          body: 'Pengeluaran sebesar IDR 50,000.00',
        ),
      );

      expect(result.type, NotificationFilterResultType.rejectedPackage);
    });

    test('rejects non Catatan Finansial title', () {
      final filter = NotificationFilter();

      final result = filter.evaluate(
        _notification(
          packageName: 'com.bca.mybca.omni.android',
          title: 'Promo',
          body: 'Pengeluaran sebesar IDR 50,000.00',
        ),
      );

      expect(result.type, NotificationFilterResultType.rejectedTitle);
    });

    test('rejects body without transaction keywords or IDR currency', () {
      final filter = NotificationFilter();

      final missingKeyword = filter.evaluate(
        _notification(
          packageName: 'com.bca.mybca.omni.android',
          title: 'Catatan Finansial',
          body: 'Transfer berhasil IDR 50,000.00',
        ),
      );
      final missingCurrency = filter.evaluate(
        _notification(
          packageName: 'com.bca.mybca.omni.android',
          title: 'Catatan Finansial',
          body: 'Pengeluaran sebesar 50,000.00',
        ),
      );

      expect(missingKeyword.type, NotificationFilterResultType.rejectedBody);
      expect(missingCurrency.type, NotificationFilterResultType.rejectedBody);
    });

    test('rejects body when IDR amount cannot be extracted', () {
      final filter = NotificationFilter();

      final result = filter.evaluate(
        _notification(
          packageName: 'com.bca.mybca.omni.android',
          title: 'Catatan Finansial',
          body: 'Pengeluaran sebesar IDR untuk Transfer Rekening.',
        ),
      );

      expect(result.type, NotificationFilterResultType.rejectedAmount);
    });

    test('rejects duplicate accepted notifications', () {
      final filter = NotificationFilter();
      final notification = _notification(
        packageName: 'com.bca.mybca.omni.android',
        title: 'Catatan Finansial',
        body: 'Pengeluaran sebesar IDR 1,000,000.00 untuk Transfer Rekening.',
      );

      final first = filter.evaluate(notification);
      final second = filter.evaluate(notification);

      expect(first.type, NotificationFilterResultType.accepted);
      expect(second.type, NotificationFilterResultType.rejectedDuplicate);
    });
  });
}

AndroidNotificationPayload _notification({
  required String packageName,
  required String title,
  required String body,
}) {
  return AndroidNotificationPayload(
    packageName: packageName,
    appName: packageName,
    title: title,
    body: body,
    receivedAt: DateTime(2026, 7, 12, 20, 13, 44),
  );
}
