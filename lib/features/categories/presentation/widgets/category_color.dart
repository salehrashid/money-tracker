import 'package:flutter/material.dart';

const categoryColorOptions = [
  '#2E7D32',
  '#1565C0',
  '#6A1B9A',
  '#00838F',
  '#AD1457',
  '#C62828',
  '#EF6C00',
  '#455A64',
];

Color categoryColor(String value) {
  final normalized = value.trim().replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null || normalized.length != 6) {
    return Colors.grey;
  }

  return Color(0xFF000000 | parsed);
}
