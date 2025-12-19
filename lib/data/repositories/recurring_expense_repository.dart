import 'package:drift/drift.dart';
import '../db/app_database.dart';
import '../../domain/models/recurring_expense.dart';

class RecurringExpenseRepository {
  final AppDatabase _db;

  RecurringExpenseRepository(this._db);

  Future<List<RecurringExpenseModel>> getAll() async {
    final query = _db.select(_db.recurringExpenses)
      ..orderBy([(r) => OrderingTerm.desc(r.startMonth)]);
    
    final results = await query.get();
    return results.map((row) => RecurringExpenseModel(
      id: row.id,
      description: row.description,
      categoryId: row.categoryId,
      amount: row.amount,
      startMonth: row.startMonth,
      endMonth: row.endMonth,
      isActive: row.isActive,
      cardId: row.cardId,
    )).toList();
  }

  Future<List<RecurringExpenseModel>> getActive() async {
    final query = _db.select(_db.recurringExpenses)
      ..where((r) => r.isActive.equals(true))
      ..orderBy([(r) => OrderingTerm.desc(r.startMonth)]);
    
    final results = await query.get();
    return results.map((row) => RecurringExpenseModel(
      id: row.id,
      description: row.description,
      categoryId: row.categoryId,
      amount: row.amount,
      startMonth: row.startMonth,
      endMonth: row.endMonth,
      isActive: row.isActive,
      cardId: row.cardId,
    )).toList();
  }

  // Busca gastos fixos que se aplicam a um mês específico
  Future<List<RecurringExpenseModel>> getForMonth(String monthRef) async {
    final allRecurring = await getActive();
    return allRecurring.where((expense) => expense.appliesToMonth(monthRef)).toList();
  }

  // Calcula o total de gastos fixos para um mês específico
  Future<double> getTotalForMonth(String monthRef) async {
    final expenses = await getForMonth(monthRef);
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  Future<int> insert(RecurringExpenseModel expense) async {
    return await _db.into(_db.recurringExpenses).insert(
      RecurringExpensesCompanion.insert(
        description: expense.description,
        categoryId: expense.categoryId,
        amount: expense.amount,
        startMonth: expense.startMonth,
        endMonth: Value(expense.endMonth),
        isActive: Value(expense.isActive),
        cardId: Value(expense.cardId),
      ),
    );
  }

  Future<bool> update(RecurringExpenseModel expense) async {
    if (expense.id == null) return false;
    
    final result = await (_db.update(_db.recurringExpenses)..where((r) => r.id.equals(expense.id!)))
        .write(
          RecurringExpensesCompanion(
            description: Value(expense.description),
            categoryId: Value(expense.categoryId),
            amount: Value(expense.amount),
            startMonth: Value(expense.startMonth),
            endMonth: Value(expense.endMonth),
            isActive: Value(expense.isActive),
            cardId: Value(expense.cardId),
          ),
        );
    return result > 0;
  }

  Future<bool> delete(int id) async {
    final result = await (_db.delete(_db.recurringExpenses)..where((r) => r.id.equals(id))).go();
    return result > 0;
  }
}

