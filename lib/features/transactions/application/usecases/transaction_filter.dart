import '../../../../features/categories/domain/entities/category.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/transaction.dart';
import '../../../accounts/domain/entities/account.dart';

enum TransactionSortOrder {
  defaultOrder,
  amountAscending,
  amountDescending;

  String get label => switch (this) {
    TransactionSortOrder.defaultOrder => 'Default',
    TransactionSortOrder.amountAscending => 'Amount: Low to High (ASC)',
    TransactionSortOrder.amountDescending => 'Amount: High to Low (DESC)',
  };
}

class TransactionFilterCriteria {
  const TransactionFilterCriteria({
    this.searchQuery = '',
    this.type,
    this.categoryId,
    this.accountId,
    this.startDate,
    this.endDate,
    this.sortOrder = TransactionSortOrder.defaultOrder,
  });

  final String searchQuery;
  final TransactionType? type;
  final String? categoryId;
  final String? accountId;
  final DateTime? startDate;
  final DateTime? endDate;
  final TransactionSortOrder sortOrder;

  bool get hasActiveFilters {
    return searchQuery.trim().isNotEmpty ||
        type != null ||
        categoryId != null ||
        accountId != null ||
        startDate != null ||
        endDate != null;
  }

  TransactionFilterCriteria copyWith({
    String? searchQuery,
    TransactionType? type,
    String? categoryId,
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
    TransactionSortOrder? sortOrder,
    bool clearType = false,
    bool clearCategoryId = false,
    bool clearAccountId = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return TransactionFilterCriteria(
      searchQuery: searchQuery ?? this.searchQuery,
      type: clearType ? null : type ?? this.type,
      categoryId: clearCategoryId ? null : categoryId ?? this.categoryId,
      accountId: clearAccountId ? null : accountId ?? this.accountId,
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class ApplyTransactionFiltersUseCase {
  const ApplyTransactionFiltersUseCase();

  List<TransactionEntity> execute({
    required List<TransactionEntity> transactions,
    required List<Category> categories,
    List<Account> accounts = const [],
    required TransactionFilterCriteria criteria,
  }) {
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final accountById = {for (final account in accounts) account.id: account};
    final query = criteria.searchQuery.trim().toLowerCase();
    final selectedCategoryIds = criteria.categoryId == null
        ? const <String>{}
        : {
            criteria.categoryId!,
            ...categories
                .where((item) => item.parentCategoryId == criteria.categoryId)
                .map((item) => item.id),
          };
    final selectedAccountIds = criteria.accountId == null
        ? const <String>{}
        : {
            criteria.accountId!,
            ...accounts
                .where((item) => item.parentAccountId == criteria.accountId)
                .map((item) => item.id),
          };
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
            criteria.endDate!.day + 1,
          );

    final filteredTransactions = transactions
        .where((transaction) {
          if (criteria.type != null && transaction.type != criteria.type) {
            return false;
          }
          if (criteria.categoryId != null &&
              !selectedCategoryIds.contains(transaction.categoryId)) {
            return false;
          }
          if (criteria.accountId != null &&
              !selectedAccountIds.contains(transaction.accountId)) {
            return false;
          }
          final transactionDate = transaction.transactionDate.toLocal();
          if (startDate != null && transactionDate.isBefore(startDate)) {
            return false;
          }
          if (endDate != null && !transactionDate.isBefore(endDate)) {
            return false;
          }

          if (query.isEmpty) {
            return true;
          }

          final category = categoryById[transaction.categoryId];
          final parent = category == null
              ? null
              : categoryById[category.parentCategoryId];
          final account = accountById[transaction.accountId];
          final searchableText = [
            transaction.note,
            transaction.amount.toStringAsFixed(0),
            transaction.currency,
            transaction.type.firestoreValue,
            transaction.source.firestoreValue,
            category?.name ?? '',
            parent?.name ?? '',
            account?.name ?? '',
          ].join(' ').toLowerCase();

          return searchableText.contains(query);
        })
        .toList(growable: false);

    switch (criteria.sortOrder) {
      case TransactionSortOrder.defaultOrder:
        return filteredTransactions;
      case TransactionSortOrder.amountAscending:
        return [...filteredTransactions]
          ..sort((first, second) => first.amount.compareTo(second.amount));
      case TransactionSortOrder.amountDescending:
        return [...filteredTransactions]
          ..sort((first, second) => second.amount.compareTo(first.amount));
    }
  }
}
