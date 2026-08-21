import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppButton extends StatelessWidget {
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  }) : _type = _AppButtonType.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  }) : _type = _AppButtonType.secondary;

  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  }) : _type = _AppButtonType.destructive;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final _AppButtonType _type;

  @override
  Widget build(BuildContext context) {
    final style = _getButtonStyle(context);
    final child = Text(label);

    if (_type == _AppButtonType.secondary) {
      if (icon != null) {
        return OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: child,
          style: style,
        );
      }
      return OutlinedButton(
        onPressed: onPressed,
        style: style,
        child: child,
      );
    }

    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: child,
        style: style,
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: child,
    );
  }

  ButtonStyle? _getButtonStyle(BuildContext context) {
    switch (_type) {
      case _AppButtonType.primary:
        return null; // Uses theme default
      case _AppButtonType.secondary:
        return null; // Uses theme default
      case _AppButtonType.destructive:
        return ElevatedButton.styleFrom(
          backgroundColor: AppColors.expense,
          foregroundColor: AppColors.white,
        );
    }
  }
}

enum _AppButtonType { primary, secondary, destructive }
