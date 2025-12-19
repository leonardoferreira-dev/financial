import 'package:drift/drift.dart';
import '../db/app_database.dart';
import '../../domain/models/expense.dart';

class ExpenseRepository {
  final AppDatabase _db;

  ExpenseRepository(this._db);

  Future<List<ExpenseModel>> getAll() async {
    final results = await _db.select(_db.expenses).get();
    return results.map((row) => ExpenseModel(
          id: row.id,
          date: row.date,
          monthRef: row.monthRef,
          description: row.description,
          categoryId: row.categoryId,
          amount: row.amount,
          type: row.type,
          cardId: row.cardId,
        )).toList();
  }

  Future<List<ExpenseModel>> getByMonth(String monthRef) async {
    final query = _db.select(_db.expenses)
      ..where((e) => e.monthRef.equals(monthRef))
      ..orderBy([(e) => OrderingTerm.desc(e.date)]);
    
    final results = await query.get();
    return results.map((row) => ExpenseModel(
          id: row.id,
          date: row.date,
          monthRef: row.monthRef,
          description: row.description,
          categoryId: row.categoryId,
          amount: row.amount,
          type: row.type,
          cardId: row.cardId,
        )).toList();
  }

  Future<double> getTotalByMonth(String monthRef) async {
    final query = _db.selectOnly(_db.expenses)
      ..addColumns([_db.expenses.amount.sum()])
      ..where(_db.expenses.monthRef.equals(monthRef))
      ..where(_db.expenses.type.equals('expense'));
    
    final result = await query.getSingle();
    return result.read(_db.expenses.amount.sum()) ?? 0.0;
  }

  Future<double> getTotalIncome() async {
    final query = _db.selectOnly(_db.expenses)
      ..addColumns([_db.expenses.amount.sum()])
      ..where(_db.expenses.type.equals('income'));
    
    final result = await query.getSingle();
    return result.read(_db.expenses.amount.sum()) ?? 0.0;
  }

  Future<Map<int, double>> getTotalByCategoryAndMonth(String monthRef) async {
    final query = _db.selectOnly(_db.expenses)
      ..addColumns([_db.expenses.categoryId, _db.expenses.amount.sum()])
      ..where(_db.expenses.monthRef.equals(monthRef))
      ..where(_db.expenses.type.equals('expense'))
      ..groupBy([_db.expenses.categoryId]);
    
    final results = await query.get();
    final Map<int, double> categoryTotals = {};
    
    for (final row in results) {
      final categoryId = row.read(_db.expenses.categoryId);
      final total = row.read(_db.expenses.amount.sum()) ?? 0.0;
      if (categoryId != null) {
        categoryTotals[categoryId] = total;
      }
    }
    
    return categoryTotals;
  }

  Future<int> insert(ExpenseModel expense) async {
    final expenseId = await _db.into(_db.expenses).insert(
          ExpensesCompanion.insert(
            date: expense.date,
            monthRef: expense.monthRef,
            description: expense.description,
            categoryId: expense.categoryId,
            amount: expense.amount,
            type: Value(expense.type),
            cardId: Value(expense.cardId),
          ),
        );
    
    // Se o gasto está vinculado a um cartão, atualizar/criar a fatura automaticamente
    if (expense.cardId != null) {
      await _updateCardInvoice(expense.cardId!, expense.monthRef, expense.amount);
    }
    
    return expenseId;
  }
  
  Future<void> _updateCardInvoice(int cardId, String monthRef, double amount) async {
    // Buscar fatura existente para este cartão e mês
    final invoiceQuery = _db.select(_db.cardInvoices)
      ..where((i) => i.cardId.equals(cardId) & i.monthRef.equals(monthRef));
    final existingInvoices = await invoiceQuery.get();
    final existingInvoice = existingInvoices.isNotEmpty ? existingInvoices.first : null;
    
    if (existingInvoice != null) {
      // Atualizar fatura existente adicionando o valor do gasto
      await (_db.update(_db.cardInvoices)..where((i) => i.id.equals(existingInvoice.id)))
          .write(CardInvoicesCompanion(
        amount: Value(existingInvoice.amount + amount),
      ));
    } else {
      // Criar nova fatura com o valor do gasto
      await _db.into(_db.cardInvoices).insert(
        CardInvoicesCompanion.insert(
          cardId: cardId,
          monthRef: monthRef,
          amount: amount,
          status: const Value('open'),
          notes: const Value('Criada automaticamente a partir de gastos'),
        ),
      );
    }
  }

  Future<bool> update(ExpenseModel expense) async {
    if (expense.id == null) return false;
    
    // Buscar gasto antigo para calcular diferença na fatura
    final oldExpense = await (_db.select(_db.expenses)..where((e) => e.id.equals(expense.id!)))
        .getSingleOrNull();
    
    final result = await (_db.update(_db.expenses)..where((e) => e.id.equals(expense.id!)))
        .write(
          ExpensesCompanion(
            date: Value(expense.date),
            monthRef: Value(expense.monthRef),
            description: Value(expense.description),
            categoryId: Value(expense.categoryId),
            amount: Value(expense.amount),
            type: Value(expense.type),
            cardId: Value(expense.cardId),
          ),
        );
    
    // Atualizar faturas se necessário
    if (oldExpense != null) {
      // Remover valor antigo da fatura antiga (se tinha cartão)
      if (oldExpense.cardId != null) {
        final oldCardId = oldExpense.cardId!;
        final oldInvoiceQuery = _db.select(_db.cardInvoices)
          ..where((i) => i.cardId.equals(oldCardId) & i.monthRef.equals(oldExpense.monthRef));
        final oldInvoices = await oldInvoiceQuery.get();
        if (oldInvoices.isNotEmpty) {
          final oldInvoice = oldInvoices.first;
          final newAmount = (oldInvoice.amount - oldExpense.amount).clamp(0.0, double.infinity);
          await (_db.update(_db.cardInvoices)..where((i) => i.id.equals(oldInvoice.id)))
              .write(CardInvoicesCompanion(amount: Value(newAmount)));
        }
      }
    }
    
    // Adicionar valor novo à fatura (se tem cartão)
    if (expense.cardId != null) {
      await _updateCardInvoice(expense.cardId!, expense.monthRef, expense.amount);
    }
    
    return result > 0;
  }

  Future<bool> delete(int id) async {
    final result = await (_db.delete(_db.expenses)..where((e) => e.id.equals(id))).go();
    return result > 0;
  }
}

