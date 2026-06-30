import '../../../../features/accounts/domain/entities/account.dart';
import '../../../../features/categories/domain/entities/category.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/transaction.dart';

class TransactionFilterCriteria {
  const TransactionFilterCriteria({
    this.searchQuery = '',
    this.type,
    this.categoryId,
    this.accountId,
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
  });

  final String searchQuery;
  final TransactionType? type;
  final String? categoryId;
  final String? accountId;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final double? maxAmount;

  bool get hasActiveFilters {
    return searchQuery.trim().isNotEmpty ||
        type != null ||
        categoryId != null ||
        accountId != null ||
        startDate != null ||
        endDate != null ||
        minAmount != null ||
        maxAmount != null;
  }

  TransactionFilterCriteria copyWith({
    String? searchQuery,
    TransactionType? type,
    String? categoryId,
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    bool clearType = false,
    bool clearCategoryId = false,
    bool clearAccountId = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearMinAmount = false,
    bool clearMaxAmount = false,
  }) {
    return TransactionFilterCriteria(
      searchQuery: searchQuery ?? this.searchQuery,
      type: clearType ? null : type ?? this.type,
      categoryId: clearCategoryId ? null : categoryId ?? this.categoryId,
      accountId: clearAccountId ? null : accountId ?? this.accountId,
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      minAmount: clearMinAmount ? null : minAmount ?? this.minAmount,
      maxAmount: clearMaxAmount ? null : maxAmount ?? this.maxAmount,
    );
  }
}

class ApplyTransactionFiltersUseCase {
  const ApplyTransactionFiltersUseCase();

  List<TransactionEntity> execute({
    required List<TransactionEntity> transactions,
    required List<Category> categories,
    required List<Account> accounts,
    required TransactionFilterCriteria criteria,
  }) {
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final accountById = {for (final account in accounts) account.id: account};
    final query = criteria.searchQuery.trim().toLowerCase();
    final startDate = criteria.startDate == null
        ? null
        : DateTime(
            criteria.startDate!.year,
            criteria.startDate!.month,
            criteria.startDate!.day,
          );
    final endDate = criteria.endDate == null
        ? null
        : DateTime(
            criteria.endDate!.year,
            criteria.endDate!.month,
            criteria.endDate!.day,
            23,
            59,
            59,
            999,
          );

    return transactions
        .where((transaction) {
          if (criteria.type != null && transaction.type != criteria.type) {
            return false;
          }
          if (criteria.categoryId != null &&
              transaction.categoryId != criteria.categoryId) {
            return false;
          }
          if (criteria.accountId != null &&
              transaction.accountId != criteria.accountId) {
            return false;
          }
          if (criteria.minAmount != null &&
              transaction.amount < criteria.minAmount!) {
            return false;
          }
          if (criteria.maxAmount != null &&
              transaction.amount > criteria.maxAmount!) {
            return false;
          }

          final transactionDate = transaction.transactionDate.toLocal();
          if (startDate != null && transactionDate.isBefore(startDate)) {
            return false;
          }
          if (endDate != null && transactionDate.isAfter(endDate)) {
            return false;
          }

          if (query.isEmpty) {
            return true;
          }

          final category = categoryById[transaction.categoryId];
          final account = accountById[transaction.accountId];
          final searchableText = [
            transaction.note,
            transaction.amount.toStringAsFixed(0),
            transaction.currency,
            transaction.type.firestoreValue,
            transaction.source.firestoreValue,
            category?.name ?? '',
            account?.name ?? '',
          ].join(' ').toLowerCase();

          return searchableText.contains(query);
        })
        .toList(growable: false);
  }
}
