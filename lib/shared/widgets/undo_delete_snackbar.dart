import 'package:circular_countdown_timer/circular_countdown_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../theme/app_theme.dart';
import '../undo_delete/pending_delete_controller.dart';

bool scheduleUndoDelete<T>({
  required BuildContext context,
  required WidgetRef ref,
  required String operationKey,
  required Set<String> itemKeys,
  required List<T> items,
  required String message,
  required String failureMessage,
  required Future<Result<void>> Function() commitDelete,
}) {
  final started = ref
      .read(pendingDeleteControllerProvider.notifier)
      .begin(
        operationKey: operationKey,
        itemKeys: itemKeys,
        items: items.cast<Object>(),
        commitDelete: commitDelete,
        failureMessage: failureMessage,
      );
  if (!started) {
    return false;
  }

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  final width = MediaQuery.sizeOf(context).width;
  final desktop = AppBreakpoints.isDesktop(context);
  final horizontalMargin = desktop ? 24.0 : 12.0;
  final snackbarWidth = desktop ? width.clamp(320.0, 400.0).toDouble() : width;

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: deleteUndoDuration + const Duration(milliseconds: 350),
      margin: desktop
          ? EdgeInsets.fromLTRB(
              (width - snackbarWidth - horizontalMargin)
                  .clamp(0.0, width)
                  .toDouble(),
              0,
              horizontalMargin,
              16,
            )
          : const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      content: _UndoDeleteSnackbarContent(
        operationKey: operationKey,
        message: message,
      ),
    ),
  );
  return true;
}

class _UndoDeleteSnackbarContent extends ConsumerStatefulWidget {
  const _UndoDeleteSnackbarContent({
    required this.operationKey,
    required this.message,
  });

  final String operationKey;
  final String message;

  @override
  ConsumerState<_UndoDeleteSnackbarContent> createState() =>
      _UndoDeleteSnackbarContentState();
}

class _UndoDeleteSnackbarContentState
    extends ConsumerState<_UndoDeleteSnackbarContent> {
  final CountDownController _countDownController = CountDownController();
  bool _resolved = false;

  void _undo() {
    if (_resolved) {
      return;
    }
    _resolved = true;
    _countDownController.pause();
    ref
        .read(pendingDeleteControllerProvider.notifier)
        .undo(widget.operationKey);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  void _complete() {
    if (_resolved) {
      return;
    }
    _resolved = true;
    ref
        .read(pendingDeleteControllerProvider.notifier)
        .commit(widget.operationKey);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          label: 'Seconds remaining to undo deletion',
          child: CircularCountDownTimer(
            duration: deleteUndoDuration.inSeconds,
            initialDuration: 0,
            controller: _countDownController,
            width: 28,
            height: 28,
            ringColor: colors.onInverseSurface.withValues(alpha: 0.28),
            fillColor: colors.inversePrimary,
            backgroundColor: Colors.transparent,
            strokeWidth: 3,
            strokeCap: StrokeCap.round,
            textStyle: TextStyle(
              color: colors.onInverseSurface,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textFormat: CountdownTextFormat.S,
            isReverse: true,
            isReverseAnimation: true,
            autoStart: true,
            onComplete: _complete,
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: _undo,
          style: TextButton.styleFrom(
            foregroundColor: colors.inversePrimary,
            minimumSize: const Size(64, 48),
          ),
          child: const Text('UNDO'),
        ),
      ],
    );
  }
}
