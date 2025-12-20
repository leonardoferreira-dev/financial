import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/salary_repository.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/credit_card_repository.dart';
import '../data/repositories/card_invoice_repository.dart';
import '../data/repositories/user_profile_repository.dart';
import '../data/repositories/recurring_expense_repository.dart';
import '../data/repositories/goal_repository.dart';
import '../domain/models/category.dart';
import '../domain/models/credit_card.dart';
import 'database_provider.dart';

final salaryRepositoryProvider = Provider<SalaryRepository>((ref) {
  return SalaryRepository(ref.watch(databaseProvider));
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(databaseProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(databaseProvider));
});

final creditCardRepositoryProvider = Provider<CreditCardRepository>((ref) {
  return CreditCardRepository(ref.watch(databaseProvider));
});

final cardInvoiceRepositoryProvider = Provider<CardInvoiceRepository>((ref) {
  return CardInvoiceRepository(ref.watch(databaseProvider));
});

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(ref.watch(databaseProvider));
});

final recurringExpenseRepositoryProvider = Provider<RecurringExpenseRepository>((ref) {
  return RecurringExpenseRepository(ref.watch(databaseProvider));
});

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(ref.watch(databaseProvider));
});

// Providers para listas
final categoriesListProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getAll();
});

final creditCardsListProvider = FutureProvider<List<CreditCardModel>>((ref) async {
  final repository = ref.watch(creditCardRepositoryProvider);
  return repository.getAll();
});

