import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/debt.dart';

class TransferProofPicker {
  const TransferProofPicker();

  static const _maxInputBytes = 10 * 1024 * 1024;
  static const _maxDimension = 1600;
  static const _minDimension = 640;

  Future<String?> pick() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
        withData: kIsWeb,
      );
      if (picked == null || picked.files.isEmpty) return null;

      final file = picked.files.single;
      _validateInputSize(file.size);
      return await prepare(await _read(file));
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        type: AppFailureType.unavailable,
        code: 'transfer-proof-picker-unavailable',
        message: 'Unable to open this photo. Please try again.',
      );
    }
  }

  Future<Uint8List> _read(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    try {
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in file.xFile.openRead()) {
        _validateInputSize(bytes.length + chunk.length);
        bytes.add(chunk);
      }
      return bytes.takeBytes();
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        type: AppFailureType.validation,
        code: 'transfer-proof-file-not-readable',
        message: 'Unable to read this photo. Please choose another file.',
      );
    }
  }

  Future<String> prepare(Uint8List bytes) async {
    _validateInputSize(bytes.length);
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final originalDimension = math.max(descriptor.width, descriptor.height);
      var targetDimension = math.min(originalDimension, _maxDimension);
      final minimumDimension = math.min(targetDimension, _minDimension);

      while (true) {
        final image = await _decode(descriptor, targetDimension);
        try {
          // Keep compressed originals when they already fit, after verifying
          // that decoding succeeds. Re-encoding small JPEGs can make them larger.
          if (bytes.length <= debtTransferProofMaxBytes &&
              originalDimension <= _maxDimension) {
            return base64Encode(bytes);
          }

          final encoded = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (encoded == null) {
            throw const AppFailure(
              type: AppFailureType.validation,
              code: 'transfer-proof-compression-failed',
              message: 'Unable to prepare this photo. Please choose another.',
            );
          }
          if (encoded.lengthInBytes <= debtTransferProofMaxBytes) {
            return base64Encode(
              encoded.buffer.asUint8List(
                encoded.offsetInBytes,
                encoded.lengthInBytes,
              ),
            );
          }
        } finally {
          image.dispose();
        }

        if (targetDimension <= minimumDimension) {
          throw const AppFailure(
            type: AppFailureType.validation,
            code: 'transfer-proof-compression-failed',
            message:
                'This photo is too detailed to attach. Please crop it to the '
                'transfer receipt and try again.',
          );
        }
        targetDimension = math.max(
          minimumDimension,
          (targetDimension * 0.8).floor(),
        );
      }
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        type: AppFailureType.validation,
        code: 'invalid-transfer-proof',
        message:
            'This file is not a readable photo. Choose a JPG, PNG, or WebP.',
      );
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  Future<ui.Image> _decode(
    ui.ImageDescriptor descriptor,
    int targetDimension,
  ) async {
    final scale =
        targetDimension / math.max(descriptor.width, descriptor.height);
    final codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * scale).round()),
      targetHeight: math.max(1, (descriptor.height * scale).round()),
    );
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  void _validateInputSize(int length) {
    if (length > _maxInputBytes) {
      throw const AppFailure(
        type: AppFailureType.validation,
        code: 'transfer-proof-too-large',
        message: 'Choose a photo smaller than 10 MB.',
      );
    }
  }
}
