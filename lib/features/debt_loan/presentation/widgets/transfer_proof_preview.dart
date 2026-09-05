import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class TransferProofPreview extends StatelessWidget {
  const TransferProofPreview({required this.base64Data, super.key});

  final String base64Data;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'View transfer proof',
      child: Tooltip(
        message: 'View transfer proof',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showTransferProofDialog(context, base64Data),
          child: Container(
            height: 160,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _TransferProofImage(base64Data: base64Data),
          ),
        ),
      ),
    );
  }
}

Future<void> showTransferProofDialog(BuildContext context, String base64Data) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: SizedBox(
        width: 800,
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Transfer proof',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: SizedBox.expand(
                    child: _TransferProofImage(base64Data: base64Data),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TransferProofImage extends StatefulWidget {
  const _TransferProofImage({required this.base64Data});

  final String base64Data;

  @override
  State<_TransferProofImage> createState() => _TransferProofImageState();
}

class _TransferProofImageState extends State<_TransferProofImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant _TransferProofImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64Data != widget.base64Data) _decode();
  }

  void _decode() {
    try {
      _bytes = base64Decode(widget.base64Data);
    } on FormatException {
      _bytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null || bytes.isEmpty) return _error();

    return Image.memory(
      bytes,
      fit: BoxFit.contain,
      semanticLabel: 'Transfer receipt photo',
      errorBuilder: (context, error, stackTrace) => _error(),
    );
  }

  Widget _error() => const Center(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text('Unable to display this photo.'),
    ),
  );
}
