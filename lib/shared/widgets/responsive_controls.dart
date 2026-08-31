import 'package:flutter/material.dart';

double responsiveDialogWidth(BuildContext context, {double maxWidth = 420}) {
  final availableWidth = MediaQuery.sizeOf(context).width - 80;
  return availableWidth.clamp(0.0, maxWidth).toDouble();
}

/// A single-select control that keeps its labels readable on small screens.
///
/// SegmentedButton is ideal when there is enough horizontal space, but its
/// segments cannot wrap. Choice chips provide the same interaction while
/// allowing the options to flow onto multiple lines when the screen is narrow
/// or the user has increased system text size.
class ResponsiveSegmentedButton<T> extends StatelessWidget {
  const ResponsiveSegmentedButton({
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.showSelectedIcon = true,
    this.spacing = 8,
    super.key,
  });

  final List<ResponsiveSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>>? onSelectionChanged;
  final bool showSelectedIcon;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(14);
    final useWrappingLayout = width < 380 || textScale > 16;

    if (!useWrappingLayout) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: SegmentedButton<T>(
          expandedInsets: EdgeInsets.zero,
          showSelectedIcon: showSelectedIcon,
          segments: segments
              .map(
                (segment) => ButtonSegment<T>(
                  value: segment.value,
                  icon: segment.icon == null ? null : Icon(segment.icon),
                  label: Text(
                    segment.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          selected: selected,
          onSelectionChanged: onSelectionChanged,
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: segments
            .map(
              (segment) => ChoiceChip(
                selected: selected.contains(segment.value),
                avatar: segment.icon == null ? null : Icon(segment.icon),
                label: Text(
                  segment.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
                showCheckmark: showSelectedIcon,
                onSelected: onSelectionChanged == null
                    ? null
                    : (_) => onSelectionChanged!({segment.value}),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class ResponsiveSegment<T> {
  const ResponsiveSegment({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}
