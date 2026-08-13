import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/features/notification_reader/domain/entities/android_notification_payload.dart';
import 'package:money_tracker/features/notification_reader/domain/entities/detected_transaction.dart';
import 'package:money_tracker/features/notification_reader/domain/services/notification_filter.dart';
import 'package:money_tracker/shared/models/finance_enums.dart';

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
      expect(result.detectedTransaction?.type, TransactionType.expense);
    });

    test('accepts myBCA Catatan Finansial income notification', () {
      final filter = NotificationFilter();

      final result = filter.evaluate(
        _notification(
          packageName: 'com.bca.mybca.omni.android',
          title: 'Catatan Finansial',
          body: 'Pemasukkan sebesar Rp 2.500.000 dari Salary.',
        ),
      );

      expect(result.type, NotificationFilterResultType.accepted);
      expect(result.amount, 2500000);
      expect(result.detectedTransaction?.type, TransactionType.income);
      expect(result.detectedTransaction?.description, 'Salary');
    });

    test('accepts Indonesian Rupiah amount variants', () {
      final amounts = {
        'Pengeluaran sebesar Rp50.000 untuk Merchant.': 50000,
        'Pengeluaran sebesar Rp 50.000 untuk Merchant.': 50000,
        'Pengeluaran sebesar Rp50000 untuk Merchant.': 50000,
        'Pengeluaran sebesar Rp 2.500.000 untuk Merchant.': 2500000,
      };

      for (final entry in amounts.entries) {
        final filter = NotificationFilter();
        final result = filter.evaluate(
          _notification(
            packageName: 'com.bca.mybca.omni.android',
            title: 'Catatan Finansial',
            body: entry.key,
          ),
        );

        expect(result.type, NotificationFilterResultType.accepted);
        expect(result.amount, entry.value);
      }
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

    test('accepts simulator expense notification by transaction content', () {
      final filter = NotificationFilter();

      final result = filter.evaluate(
        _notification(
          packageName: 'com.example.transaction_simulator',
          title: 'Catatan Finansial',
          body: 'Pengeluaran Rp50.000',
        ),
      );

      expect(result.type, NotificationFilterResultType.accepted);
      expect(result.detectedTransaction?.type, TransactionType.expense);
      expect(result.amount, 50000);
    });

    test('accepts simulator income notification by transaction content', () {
      final filter = NotificationFilter();

      final result = filter.evaluate(
        _notification(
          packageName: 'com.example.transaction_simulator',
          title: 'Catatan Finansial',
          body: 'Pemasukkan Rp2.500.000',
        ),
      );

      expect(result.type, NotificationFilterResultType.accepted);
      expect(result.detectedTransaction?.type, TransactionType.income);
      expect(result.amount, 2500000);
    });

    test('rejects other app packages with unrelated content', () {
      final filter = NotificationFilter();

      final result = filter.evaluate(
        _notification(
          packageName: 'com.example.otherapp',
          title: 'Hello',
          body: 'A normal unrelated notification.',
        ),
      );

      expect(result.type, NotificationFilterResultType.unknownPackage);
    });

    test('does not require Catatan Finansial title for real myBCA', () {
      final filter = NotificationFilter();

      final result = filter.evaluate(
        _notification(
          packageName: 'com.bca.mybca.omni.android',
          title: 'myBCA',
          body: 'Pengeluaran sebesar IDR 50,000.00',
        ),
      );

      expect(result.type, NotificationFilterResultType.accepted);
      expect(result.amount, 50000);
    });

    test('rejects body without transaction keywords', () {
      final filter = NotificationFilter();

      final missingKeyword = filter.evaluate(
        _notification(
          packageName: 'com.bca.mybca.omni.android',
          title: 'Catatan Finansial',
          body: 'Transfer berhasil IDR 50,000.00',
        ),
      );
      expect(
        missingKeyword.type,
        NotificationFilterResultType.transactionTypeNotFound,
      );
    });

    test('rejects body when currency amount cannot be extracted', () {
      final filter = NotificationFilter();

      final missingNumber = filter.evaluate(
        _notification(
          packageName: 'com.bca.mybca.omni.android',
          title: 'Catatan Finansial',
          body: 'Pengeluaran sebesar IDR untuk Transfer Rekening.',
        ),
      );
      final missingCurrency = filter.evaluate(
        _notification(
          packageName: 'com.bca.mybca.omni.android',
          title: 'Catatan Finansial',
          body: 'Pengeluaran sebesar 50,000.00',
        ),
      );

      expect(missingNumber.type, NotificationFilterResultType.amountNotFound);
      expect(missingCurrency.type, NotificationFilterResultType.amountNotFound);
    });

    test('rejects missing amount in simulator notification', () {
      final filter = NotificationFilter();

      final result = filter.evaluate(
        _notification(
          packageName: 'com.example.transaction_simulator',
          title: 'Catatan Finansial',
          body: 'Pengeluaran',
        ),
      );

      expect(result.type, NotificationFilterResultType.amountNotFound);
    });

    test('rejects missing transaction type in simulator notification', () {
      final filter = NotificationFilter();

      final result = filter.evaluate(
        _notification(
          packageName: 'com.example.transaction_simulator',
          title: 'Catatan Finansial',
          body: 'Rp50.000',
        ),
      );

      expect(result.type, NotificationFilterResultType.transactionTypeNotFound);
    });

    test('detects myBCA transaction data from big text and text lines', () {
      final filter = NotificationFilter();

      final result = filter.evaluate(
        _notification(
          packageName: 'com.bca.mybca.omni.android',
          title: 'myBCA',
          body: '',
          bigText: 'Catatan Finansial\nPemasukkan sebesar Rp 2.500.000',
          textLines: const ['Saldo berhasil diperbarui'],
        ),
      );

      expect(result.type, NotificationFilterResultType.accepted);
      expect(result.detectedTransaction?.type, TransactionType.income);
      expect(result.amount, 2500000);
    });

    test('rejects non-transaction myBCA notification', () {
      final filter = NotificationFilter();

      final result = filter.evaluate(
        _notification(
          packageName: 'com.bca.mybca.omni.android',
          title: 'Security',
          body: 'Perangkat baru berhasil didaftarkan.',
        ),
      );

      expect(result.type, NotificationFilterResultType.transactionTypeNotFound);
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
      expect(second.type, NotificationFilterResultType.duplicateNotification);
    });

    test(
      'does not deduplicate distinct notifications with the same amount',
      () {
        final filter = NotificationFilter();

        final first = filter.evaluate(
          _notification(
            packageName: 'com.example.transaction_simulator',
            title: 'Catatan Finansial',
            body: 'Pengeluaran Rp50.000',
            receivedAt: DateTime(2026, 7, 12, 20, 13, 44),
          ),
        );
        final second = filter.evaluate(
          _notification(
            packageName: 'com.example.transaction_simulator',
            title: 'Catatan Finansial',
            body: 'Pengeluaran Rp50.000',
            receivedAt: DateTime(2026, 7, 12, 20, 14),
          ),
        );

        expect(first.type, NotificationFilterResultType.accepted);
        expect(second.type, NotificationFilterResultType.accepted);
      },
    );

    test('round-trips detected transaction notification payload', () {
      final detected = DetectedTransaction(
        type: TransactionType.expense,
        amount: 50000,
        description: 'Some Merchant',
        originalText: 'Pengeluaran sebesar Rp50.000 untuk Some Merchant.',
        detectedAt: DateTime(2026, 7, 12, 20, 13, 44),
        sourcePackage: 'com.bca.mybca.omni.android',
        source: 'myBCA',
      );

      final parsed = DetectedTransaction.fromNotificationPayload(
        detected.toNotificationPayload(),
      );

      expect(parsed.type, TransactionType.expense);
      expect(parsed.amount, 50000);
      expect(parsed.description, 'Some Merchant');
      expect(parsed.sourcePackage, 'com.bca.mybca.omni.android');
    });
  });
}

AndroidNotificationPayload _notification({
  required String packageName,
  required String title,
  required String body,
  String bigText = '',
  List<String> textLines = const [],
  DateTime? receivedAt,
}) {
  return AndroidNotificationPayload(
    packageName: packageName,
    appName: packageName,
    title: title,
    body: body,
    bigText: bigText,
    textLines: textLines,
    receivedAt: receivedAt ?? DateTime(2026, 7, 12, 20, 13, 44),
  );
}
