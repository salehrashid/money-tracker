import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/errors/app_failure.dart';
import 'package:money_tracker/features/debt_loan/domain/entities/debt.dart';
import 'package:money_tracker/features/debt_loan/presentation/services/transfer_proof_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const picker = TransferProofPicker();

  group('TransferProofPicker.prepare', () {
    test('retains a small, decodable original photo', () async {
      final bytes = await _photo(width: 32, height: 16);

      final prepared = await picker.prepare(bytes);

      expect(base64Decode(prepared), bytes);
    });

    test('rejects invalid image bytes with a friendly failure', () async {
      await expectLater(
        picker.prepare(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(_failure('invalid-transfer-proof')),
      );
    });

    test('rejects an empty file with a friendly failure', () async {
      await expectLater(
        picker.prepare(Uint8List(0)),
        throwsA(_failure('invalid-transfer-proof')),
      );
    });

    test('rejects input bytes over the 10 MiB limit', () async {
      await expectLater(
        picker.prepare(Uint8List(10 * 1024 * 1024 + 1)),
        throwsA(_failure('transfer-proof-too-large')),
      );
    });

    test('reduces large dimensions even when encoded input is small', () async {
      final bytes = await _photo(width: 3000, height: 1500);
      expect(bytes.length, lessThan(debtTransferProofMaxBytes));

      final prepared = base64Decode(await picker.prepare(bytes));
      final image = await _decode(prepared);
      try {
        expect(image.width, 1600);
        expect(image.height, 800);
        expect(prepared.length, lessThanOrEqualTo(debtTransferProofMaxBytes));
      } finally {
        image.dispose();
      }
    });

    test('shrinks a detailed photo into the storage budget', () async {
      final bytes = await _photo(width: 1800, height: 900, noise: true);
      expect(bytes.length, greaterThan(debtTransferProofMaxBytes));

      final prepared = base64Decode(await picker.prepare(bytes));
      final image = await _decode(prepared);
      try {
        expect(prepared.length, lessThanOrEqualTo(debtTransferProofMaxBytes));
        expect(image.width, inInclusiveRange(640, 1600));
        expect(image.height, closeTo(image.width / 2, 1));
      } finally {
        image.dispose();
      }
    });
  });

  group('TransferProofPicker.pick', () {
    test('returns null when choosing a photo is cancelled', () async {
      FilePicker.platform = _FakeFilePicker();

      expect(await picker.pick(), isNull);
    });

    test('returns null for an empty picker result', () async {
      FilePicker.platform = _FakeFilePicker(result: FilePickerResult([]));

      expect(await picker.pick(), isNull);
    });

    test('requests one photo and returns its prepared image', () async {
      final bytes = await _photo(width: 32, height: 16);
      final platform = _FakeFilePicker(
        result: FilePickerResult([
          PlatformFile(name: 'receipt.png', size: bytes.length, bytes: bytes),
        ]),
      );
      FilePicker.platform = platform;

      expect(base64Decode((await picker.pick())!), bytes);
      expect(platform.requestedType, FileType.custom);
      expect(platform.requestedExtensions, ['jpg', 'jpeg', 'png', 'webp']);
      expect(platform.requestedMultiple, isFalse);
      expect(platform.requestedData, kIsWeb);
    });

    test(
      'reads a native file when the platform returns only its path',
      () async {
        final bytes = await _photo(width: 32, height: 16);
        final directory = await Directory.systemTemp.createTemp(
          'transfer-proof-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = await File(
          '${directory.path}/receipt.png',
        ).writeAsBytes(bytes);
        FilePicker.platform = _FakeFilePicker(
          result: FilePickerResult([
            PlatformFile(
              name: 'receipt.png',
              size: bytes.length,
              path: file.path,
            ),
          ]),
        );

        expect(base64Decode((await picker.pick())!), bytes);
      },
    );

    test('maps platform errors to a friendly failure', () async {
      FilePicker.platform = _FakeFilePicker(error: StateError('Native error'));

      await expectLater(
        picker.pick(),
        throwsA(_failure('transfer-proof-picker-unavailable')),
      );
    });

    test('rejects files without readable bytes', () async {
      FilePicker.platform = _FakeFilePicker(
        result: FilePickerResult([PlatformFile(name: 'receipt.png', size: 10)]),
      );

      await expectLater(
        picker.pick(),
        throwsA(_failure('transfer-proof-file-not-readable')),
      );
    });

    test('checks reported size before attempting to read a file', () async {
      FilePicker.platform = _FakeFilePicker(
        result: FilePickerResult([
          PlatformFile(name: 'receipt.png', size: 10 * 1024 * 1024 + 1),
        ]),
      );

      await expectLater(
        picker.pick(),
        throwsA(_failure('transfer-proof-too-large')),
      );
    });

    test(
      'also checks actual byte length when the reported size is small',
      () async {
        FilePicker.platform = _FakeFilePicker(
          result: FilePickerResult([
            PlatformFile(
              name: 'receipt.png',
              size: 1,
              bytes: Uint8List(10 * 1024 * 1024 + 1),
            ),
          ]),
        );

        await expectLater(
          picker.pick(),
          throwsA(_failure('transfer-proof-too-large')),
        );
      },
    );
  });
}

Matcher _failure(String code) =>
    isA<AppFailure>().having((failure) => failure.code, 'code', code);

Future<Uint8List> _photo({
  required int width,
  required int height,
  bool noise = false,
}) async {
  final pixels = Uint8List(width * height * 4);
  final random = Random(23);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = noise ? random.nextInt(256) : 40;
    pixels[i + 1] = noise ? random.nextInt(256) : 120;
    pixels[i + 2] = noise ? random.nextInt(256) : 220;
    pixels[i + 3] = 255;
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  try {
    final encoded = (await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!;
    return encoded.buffer.asUint8List(
      encoded.offsetInBytes,
      encoded.lengthInBytes,
    );
  } finally {
    frame.image.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
  }
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

class _FakeFilePicker extends FilePicker {
  _FakeFilePicker({this.result, this.error});

  final FilePickerResult? result;
  final Object? error;
  FileType? requestedType;
  List<String>? requestedExtensions;
  bool? requestedMultiple;
  bool? requestedData;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    requestedType = type;
    requestedExtensions = allowedExtensions;
    requestedMultiple = allowMultiple;
    requestedData = withData;
    if (error != null) throw error!;
    return result;
  }
}
