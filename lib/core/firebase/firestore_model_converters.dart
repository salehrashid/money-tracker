import 'package:cloud_firestore/cloud_firestore.dart';

String requiredString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('Missing or invalid string field: $key');
}

String? optionalString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('Invalid string field: $key');
}

bool requiredBool(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Missing or invalid bool field: $key');
}

double requiredDouble(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('Missing or invalid number field: $key');
}

double? optionalDouble(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('Invalid number field: $key');
}

int requiredInt(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is int) {
    return value;
  }
  if (value is num && value % 1 == 0) {
    return value.toInt();
  }
  throw FormatException('Missing or invalid integer field: $key');
}

DateTime requiredDateTime(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  throw FormatException('Missing or invalid timestamp field: $key');
}

DateTime? optionalDateTime(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) {
    return null;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  throw FormatException('Invalid timestamp field: $key');
}

List<Map<String, dynamic>> optionalMapList(
  Map<String, dynamic> data,
  String key,
) {
  final value = data[key];
  if (value == null) {
    return const [];
  }
  if (value is List) {
    return value
        .map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          }
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          throw FormatException('Invalid map list item in field: $key');
        })
        .toList(growable: false);
  }
  throw FormatException('Invalid map list field: $key');
}

Timestamp timestampFromDate(DateTime value) {
  return Timestamp.fromDate(value);
}
