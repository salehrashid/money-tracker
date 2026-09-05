import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/errors/app_failure.dart';
import 'package:money_tracker/features/debt_loan/application/usecases/debt_commands.dart';
import 'package:money_tracker/features/debt_loan/domain/entities/debt.dart';
import 'package:money_tracker/features/debt_loan/presentation/services/transfer_proof_picker.dart';
import 'package:money_tracker/features/debt_loan/presentation/widgets/debt_form_dialog.dart';
import 'package:money_tracker/shared/models/finance_enums.dart';

const _proof =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';
const _replacementProof =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYPj/HwADAgH/5ncLrgAAAABJRU5ErkJggg==';

void main() {
  for (final size in [const Size(360, 800), const Size(1200, 900)]) {
    testWidgets('saves without a transfer proof at $size', (tester) async {
      _setViewport(tester, size);
      final result = await _openDialog(tester);

      await _fillRequiredFields(tester);
      await tester.ensureVisible(find.text('Transfer proof (optional)'));
      await tester.pumpAndSettle();
      expect(find.text('Upload photo'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _tap(tester, find.text('Save'));

      expect(result.command, isNotNull);
      expect(result.command!.personName, 'Ari');
      expect(result.command!.amount, 100000);
      expect(result.command!.transferProofBase64, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('previews and saves a selected photo at $size', (tester) async {
      _setViewport(tester, size);
      final result = await _openDialog(
        tester,
        picker: _FakeTransferProofPicker(() async => _proof),
      );
      await _fillRequiredFields(tester);

      await _tap(tester, find.text('Upload photo'));

      expect(find.text('Replace photo'), findsOneWidget);
      expect(find.text('Remove photo'), findsOneWidget);
      expect(_displayedProof(tester), orderedEquals(base64Decode(_proof)));
      expect(tester.takeException(), isNull);

      await _tap(tester, find.byTooltip('View transfer proof'));
      expect(find.text('Transfer proof'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _tap(tester, find.byTooltip('Close'));

      await _tap(tester, find.text('Save'));

      expect(result.command!.transferProofBase64, _proof);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keeps an existing proof when editing other fields', (
    tester,
  ) async {
    final result = await _openDialog(tester, debt: _debt());
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Person / entity'),
      'Budi',
    );

    await _tap(tester, find.text('Save'));

    expect(result.command!.personName, 'Budi');
    expect(result.command!.transferProofBase64, _proof);
  });

  testWidgets('keeps an existing proof when the picker is canceled', (
    tester,
  ) async {
    final result = await _openDialog(
      tester,
      debt: _debt(),
      picker: _FakeTransferProofPicker(() async => null),
    );

    await _tap(tester, find.text('Replace photo'));

    expect(_displayedProof(tester), orderedEquals(base64Decode(_proof)));
    await _tap(tester, find.text('Save'));
    expect(result.command!.transferProofBase64, _proof);
  });

  testWidgets('replaces an existing proof with the newly selected photo', (
    tester,
  ) async {
    final result = await _openDialog(
      tester,
      debt: _debt(),
      picker: _FakeTransferProofPicker(() async => _replacementProof),
    );

    await _tap(tester, find.text('Replace photo'));

    expect(
      _displayedProof(tester),
      orderedEquals(base64Decode(_replacementProof)),
    );
    await _tap(tester, find.text('Save'));
    expect(result.command!.transferProofBase64, _replacementProof);
  });

  testWidgets('removes an existing proof while keeping the form valid', (
    tester,
  ) async {
    final result = await _openDialog(tester, debt: _debt());

    await _tap(tester, find.text('Remove photo'));

    expect(find.byType(Image), findsNothing);
    expect(find.text('Upload photo'), findsOneWidget);
    await _tap(tester, find.text('Save'));
    expect(result.command, isNotNull);
    expect(result.command!.transferProofBase64, isNull);
  });

  testWidgets('disables Save until photo selection finishes', (tester) async {
    final selection = Completer<String?>();
    final result = await _openDialog(
      tester,
      debt: _debt(),
      picker: _FakeTransferProofPicker(() => selection.future),
    );
    await tester.ensureVisible(find.text('Replace photo'));
    await tester.tap(find.text('Replace photo'));
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    expect(result.command, isNull);

    selection.complete(_replacementProof);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNotNull,
    );
    await _tap(tester, find.text('Save'));
    expect(result.command!.transferProofBase64, _replacementProof);
  });

  testWidgets('allows saving without a photo after a picker failure', (
    tester,
  ) async {
    final result = await _openDialog(
      tester,
      picker: _FakeTransferProofPicker(() async => throw _pickerFailure),
    );
    await _fillRequiredFields(tester);

    await _tap(tester, find.text('Upload photo'));

    expect(find.text(_pickerFailure.message), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Save'));
    expect(result.command, isNotNull);
    expect(result.command!.transferProofBase64, isNull);
  });

  testWidgets('keeps the previous proof after a failed replacement', (
    tester,
  ) async {
    final result = await _openDialog(
      tester,
      debt: _debt(),
      picker: _FakeTransferProofPicker(() async => throw _pickerFailure),
    );

    await _tap(tester, find.text('Replace photo'));

    expect(find.text(_pickerFailure.message), findsOneWidget);
    expect(_displayedProof(tester), orderedEquals(base64Decode(_proof)));
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Save'));
    expect(result.command!.transferProofBase64, _proof);
  });
}

const _pickerFailure = AppFailure(
  type: AppFailureType.validation,
  message: 'Choose a supported image file.',
);

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<_DialogResult> _openDialog(
  WidgetTester tester, {
  Debt? debt,
  TransferProofPicker? picker,
}) async {
  final result = _DialogResult();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result.command = await showDialog<SaveDebtCommand>(
                context: context,
                builder: (_) => DebtFormDialog(
                  debt: debt,
                  transferProofPicker:
                      picker ?? _FakeTransferProofPicker(() async => null),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await _tap(tester, find.text('Open'));
  return result;
}

Future<void> _fillRequiredFields(WidgetTester tester) async {
  final person = find.widgetWithText(TextFormField, 'Person / entity');
  final amount = find.widgetWithText(TextFormField, 'Amount');
  await tester.ensureVisible(person);
  await tester.enterText(person, 'Ari');
  await tester.ensureVisible(amount);
  await tester.enterText(amount, '100000');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

List<int> _displayedProof(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  return (image.image as MemoryImage).bytes;
}

Debt _debt() {
  final date = DateTime.utc(2026, 1, 1);
  return Debt(
    id: 'debt-1',
    kind: DebtKind.debt,
    personName: 'Ari',
    amount: 100000,
    currency: 'IDR',
    status: DebtStatus.open,
    note: '',
    transactionDate: date,
    createdAt: date,
    updatedAt: date,
    transferProofBase64: _proof,
  );
}

class _DialogResult {
  SaveDebtCommand? command;
}

class _FakeTransferProofPicker extends TransferProofPicker {
  const _FakeTransferProofPicker(this.onPick);

  final Future<String?> Function() onPick;

  @override
  Future<String?> pick() => onPick();
}
