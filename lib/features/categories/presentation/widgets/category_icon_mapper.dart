import 'package:flutter/material.dart';

const categoryIconOptions = [
  'restaurant',
  'directions_car',
  'receipt_long',
  'shopping_bag',
  'home',
  'health_and_safety',
  'school',
  'payments',
  'redeem',
  'savings',
  'work',
  'more_horiz',
];

IconData categoryIconData(String icon) {
  return switch (icon) {
    'restaurant' => Icons.restaurant,
    'directions_car' => Icons.directions_car,
    'receipt_long' => Icons.receipt_long,
    'shopping_bag' => Icons.shopping_bag,
    'home' => Icons.home,
    'health_and_safety' => Icons.health_and_safety,
    'school' => Icons.school,
    'payments' => Icons.payments,
    'redeem' => Icons.redeem,
    'savings' => Icons.savings,
    'work' => Icons.work,
    _ => Icons.more_horiz,
  };
}

String categoryIconLabel(String icon) {
  return switch (icon) {
    'restaurant' => 'Food',
    'directions_car' => 'Transport',
    'receipt_long' => 'Bills',
    'shopping_bag' => 'Shopping',
    'home' => 'Home',
    'health_and_safety' => 'Health',
    'school' => 'Education',
    'payments' => 'Payments',
    'redeem' => 'Gift',
    'savings' => 'Savings',
    'work' => 'Work',
    _ => 'Other',
  };
}
