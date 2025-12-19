import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/repository_providers.dart';
import '../../domain/models/recurring_expense.dart';
import '../../domain/models/category.dart';
import '../../domain/models/credit_card.dart';
import '../widgets/amount_text.dart';
import 'add_recurring_expense_page.dart';

final recurringExpensesListProvider = FutureProvider<List<RecurringExpenseModel>>((ref) async {
  final repository = ref.watch(recurringExpenseRepositoryProvider);
  return repository.getAll();
});

class RecurringExpensesPage extends ConsumerWidget {
  const RecurringExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringExpensesAsync = ref.watch(recurringExpensesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos Fixos'),
      ),
      body: recurringExpensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.repeat,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum gasto fixo cadastrado',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adicione gastos que se repetem mensalmente',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(recurringExpensesListProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                final expense = expenses[index];
                return _buildExpenseCard(context, ref, expense);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Erro ao carregar: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(recurringExpensesListProvider);
                },
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'recurring_expenses_fab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddRecurringExpensePage(),
            ),
          );
          ref.invalidate(recurringExpensesListProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildExpenseCard(
    BuildContext context,
    WidgetRef ref,
    RecurringExpenseModel expense,
  ) {
    final categoriesAsync = ref.watch(categoriesListProvider);
    final cardsAsync = ref.watch(creditCardsListProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.repeat,
            color: Colors.orange.shade700,
            size: 24,
          ),
        ),
        title: Text(
          expense.description,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            categoriesAsync.when(
              data: (categories) {
                final category = categories.firstWhere(
                  (c) => c.id == expense.categoryId,
                  orElse: () => CategoryModel(id: null, name: 'Desconhecida'),
                );
                return Text('Categoria: ${category.name}');
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 4),
            Text(
              'Período: ${_formatMonth(expense.startMonth)}${expense.endMonth != null ? ' até ${_formatMonth(expense.endMonth!)}' : ' (indefinido)'}',
              style: TextStyle(
                fontSize: 12,
                color: expense.isActive ? Colors.grey.shade600 : Colors.red.shade600,
              ),
            ),
            if (expense.cardId != null) ...[
              const SizedBox(height: 4),
              cardsAsync.when(
                data: (cards) {
                  final card = cards.firstWhere(
                    (c) => c.id == expense.cardId,
                    orElse: () => CreditCardModel(id: null, name: 'Desconhecido', closingDay: 1, dueDay: 1),
                  );
                  return Text(
                    'Cartão: ${card.name}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
            if (!expense.isActive) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Inativo',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AmountText(
              amount: expense.amount,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddRecurringExpensePage(expense: expense),
                  ),
                );
                ref.invalidate(recurringExpensesListProvider);
              },
            ),
          ],
        ),
        onLongPress: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Excluir gasto fixo?'),
              content: Text('Deseja excluir "${expense.description}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    if (expense.id != null) {
                      final repository = ref.read(recurringExpenseRepositoryProvider);
                      await repository.delete(expense.id!);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ref.invalidate(recurringExpensesListProvider);
                      }
                    }
                  },
                  child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatMonth(String monthRef) {
    final parts = monthRef.split('-');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null) {
        final date = DateTime(year, month);
        final monthName = DateFormat('MMMM/yyyy', 'pt_BR').format(date);
        return monthName[0].toUpperCase() + monthName.substring(1);
      }
    }
    return monthRef;
  }
}

