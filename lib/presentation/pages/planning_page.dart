import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/repository_providers.dart';
import '../../domain/models/salary_history.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/card_invoice.dart';
import '../../domain/models/category.dart';
import '../../domain/models/credit_card.dart';
import '../widgets/month_picker.dart';
import '../widgets/amount_text.dart';
import 'add_expense_page.dart';
import 'add_card_invoice_page.dart';
import 'salary_history_page.dart';

final currentMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
});

final monthlyPlanningProvider = FutureProvider.family<MonthlyPlanningData, String>((ref, monthRef) async {
  final salaryRepo = ref.watch(salaryRepositoryProvider);
  final expenseRepo = ref.watch(expenseRepositoryProvider);
  final invoiceRepo = ref.watch(cardInvoiceRepositoryProvider);
  final categoryRepo = ref.watch(categoryRepositoryProvider);
  final cardRepo = ref.watch(creditCardRepositoryProvider);
  final profileRepo = ref.watch(userProfileRepositoryProvider);
  final recurringExpenseRepo = ref.watch(recurringExpenseRepositoryProvider);

  final salary = await salaryRepo.getForMonth(monthRef);
  final expenses = await expenseRepo.getByMonth(monthRef);
  final invoices = await invoiceRepo.getByMonth(monthRef);
  final categories = await categoryRepo.getAll();
  final cards = await cardRepo.getAll();
  final profile = await profileRepo.get();

  final totalExpenses = await expenseRepo.getTotalByMonth(monthRef);
  final totalInvoices = await invoiceRepo.getTotalByMonth(monthRef);
  final expensesByCategory = await expenseRepo.getTotalByCategoryAndMonth(monthRef);
  final totalIncome = await expenseRepo.getTotalIncome();
  final totalRecurringExpenses = await recurringExpenseRepo.getTotalForMonth(monthRef);

  final salaryAmount = salary?.amount ?? 0.0;
  final initialBalance = profile?.initialBalance ?? 0.0;
  
  // Verificar se este é o primeiro mês (primeiro mês com salário ou mês atual se não houver histórico)
  final allSalaries = await salaryRepo.getAll();
  final firstSalaryMonth = allSalaries.isNotEmpty 
      ? allSalaries.map((s) => s.startMonth).reduce((a, b) => a.compareTo(b) < 0 ? a : b)
      : monthRef;
  
  // Adicionar saldo inicial apenas no primeiro mês
  final shouldAddInitialBalance = monthRef == firstSalaryMonth;
  
  // Calcular saldo: salário + receitas + saldo inicial (se for o primeiro mês) - gastos - gastos fixos - faturas
  final balance = salaryAmount + totalIncome + (shouldAddInitialBalance ? initialBalance : 0.0) - totalExpenses - totalRecurringExpenses - totalInvoices;

  return MonthlyPlanningData(
    salary: salary,
    salaryAmount: salaryAmount,
    expenses: expenses,
    totalExpenses: totalExpenses,
    invoices: invoices,
    totalInvoices: totalInvoices,
    balance: balance,
    categories: categories,
    cards: cards,
    expensesByCategory: expensesByCategory,
    totalIncome: totalIncome,
    initialBalance: shouldAddInitialBalance ? initialBalance : 0.0,
    totalRecurringExpenses: totalRecurringExpenses,
  );
});

class MonthlyPlanningData {
  final SalaryHistoryModel? salary;
  final double salaryAmount;
  final List<ExpenseModel> expenses;
  final double totalExpenses;
  final List<CardInvoiceModel> invoices;
  final double totalInvoices;
  final double balance;
  final List<CategoryModel> categories;
  final List<CreditCardModel> cards;
  final Map<int, double> expensesByCategory;
  final double totalIncome;
  final double initialBalance;
  final double totalRecurringExpenses;

  MonthlyPlanningData({
    required this.salary,
    required this.salaryAmount,
    required this.expenses,
    required this.totalExpenses,
    required this.invoices,
    required this.totalInvoices,
    required this.balance,
    required this.categories,
    required this.cards,
    required this.expensesByCategory,
    required this.totalIncome,
    required this.initialBalance,
    required this.totalRecurringExpenses,
  });
}

class PlanningPage extends ConsumerWidget {
  const PlanningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthRef = ref.watch(currentMonthProvider);
    final planningAsync = ref.watch(monthlyPlanningProvider(monthRef));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Planejamento Mensal'),
        elevation: 0,
      ),
      body: planningAsync.when(
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(monthlyPlanningProvider(monthRef));
          },
          child: CustomScrollView(
            key: ValueKey(monthRef), // Adiciona key para forçar rebuild ao trocar mês
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header com seletor de mês e saldo destacado
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        children: [
                          MonthPicker(
                            monthRef: monthRef,
                            onMonthChanged: (newMonth) {
                              ref.read(currentMonthProvider.notifier).state = newMonth;
                            },
                            textColor: Colors.white,
                            iconColor: Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 24),
                          // Saldo previsto destacado
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Saldo Previsto',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                AmountText(
                                  amount: data.balance,
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -1,
                                    color: data.balance >= 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Cards de resumo
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildSummaryCard(
                      context,
                      'Salário',
                      data.salaryAmount,
                      Icons.account_balance_wallet,
                      Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SalaryHistoryPage(),
                          ),
                        );
                      },
                    ),
                    _buildSummaryCard(
                      context,
                      'Gastos',
                      data.totalExpenses,
                      Icons.shopping_cart,
                      Colors.red,
                    ),
                    _buildSummaryCard(
                      context,
                      'Faturas',
                      data.totalInvoices,
                      Icons.credit_card,
                      Colors.orange,
                    ),
                    _buildSummaryCard(
                      context,
                      'Disponível',
                      data.salaryAmount - data.totalExpenses - data.totalInvoices,
                      Icons.account_balance,
                      data.balance >= 0 ? Colors.green : Colors.red,
                    ),
                  ]),
                ),
              ),
              // Gastos por categoria
              if (data.expensesByCategory.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildSectionCard(
                      context,
                      'Gastos por Categoria',
                      Icons.category,
                      Colors.blue,
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddExpensePage(monthRef: monthRef),
                            ),
                          );
                          ref.invalidate(monthlyPlanningProvider(monthRef));
                        },
                      ),
                      child: Column(
                        children: [
                          ...data.expensesByCategory.entries.map((entry) {
                            final category = data.categories.firstWhere(
                              (c) => c.id == entry.key,
                              orElse: () => CategoryModel(id: entry.key, name: 'Desconhecida'),
                            );
                            return _buildListItem(
                              context,
                              category.name,
                              entry.value,
                              Colors.blue.shade100,
                              Icons.label_outline,
                            );
                          }),
                          if (data.expensesByCategory.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddExpensePage(monthRef: monthRef),
                                    ),
                                  );
                                  ref.invalidate(monthlyPlanningProvider(monthRef));
                                },
                                icon: const Icon(Icons.add_circle_outline, size: 18),
                                label: const Text('Adicionar gasto'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Lista de gastos
              if (data.expenses.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildSectionCard(
                      context,
                      'Gastos do Mês',
                      Icons.receipt_long,
                      Colors.purple,
                      child: Column(
                        children: data.expenses.map((expense) {
                          final category = data.categories.firstWhere(
                            (c) => c.id == expense.categoryId,
                            orElse: () => CategoryModel(id: expense.categoryId, name: 'Desconhecida'),
                          );
                          return _buildExpenseItem(
                            context,
                            ref,
                            expense,
                            expense.description,
                            '${category.name} • ${DateFormat('dd/MM/yyyy', 'pt_BR').format(expense.date)}',
                            expense.amount,
                            Colors.purple.shade100,
                            Icons.shopping_bag_outlined,
                            monthRef,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              // Faturas do mês
              if (data.invoices.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildSectionCard(
                      context,
                      'Faturas do Mês',
                      Icons.credit_card,
                      Colors.orange,
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddCardInvoicePage(monthRef: monthRef),
                            ),
                          );
                          ref.invalidate(monthlyPlanningProvider(monthRef));
                        },
                      ),
                      child: Column(
                        children: data.invoices.map((invoice) {
                          final card = data.cards.firstWhere(
                            (c) => c.id == invoice.cardId,
                            orElse: () => CreditCardModel(
                              id: invoice.cardId,
                              name: 'Desconhecido',
                              closingDay: 1,
                              dueDay: 1,
                            ),
                          );
                          return _buildInvoiceItem(
                            context,
                            ref,
                            invoice,
                            card.name,
                            invoice.status == 'open',
                            invoice.amount,
                            monthRef,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Erro ao carregar dados',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(monthlyPlanningProvider(monthRef));
                },
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'planning_fab',
        onPressed: () async {
          final result = await showModalBottomSheet<String>(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shopping_cart, color: Colors.green),
                    ),
                    title: const Text('Adicionar Gasto'),
                    onTap: () {
                      Navigator.pop(context, 'expense');
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.credit_card, color: Colors.orange),
                    ),
                    title: const Text('Adicionar Fatura'),
                    onTap: () {
                      Navigator.pop(context, 'invoice');
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.account_balance_wallet, color: Colors.blue),
                    ),
                    title: const Text('Editar Salário'),
                    onTap: () {
                      Navigator.pop(context, 'salary');
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );

          if (result == null) return;

          if (!context.mounted) return;
          final navigator = Navigator.of(context);

          if (result == 'expense') {
            await navigator.push(
              MaterialPageRoute(
                builder: (_) => AddExpensePage(monthRef: monthRef),
              ),
            );
            if (context.mounted) {
              ref.invalidate(monthlyPlanningProvider(monthRef));
            }
          } else if (result == 'invoice') {
            await navigator.push(
              MaterialPageRoute(
                builder: (_) => AddCardInvoicePage(monthRef: monthRef),
              ),
            );
            if (context.mounted) {
              ref.invalidate(monthlyPlanningProvider(monthRef));
            }
          } else if (result == 'salary') {
            await navigator.push(
              MaterialPageRoute(
                builder: (_) => const SalaryHistoryPage(),
              ),
            );
            if (context.mounted) {
              ref.invalidate(monthlyPlanningProvider(monthRef));
            }
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    double amount,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                AmountText(
                  amount: amount,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  positiveColor: color,
                  negativeColor: color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color, {
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context,
    String title,
    double amount,
    Color iconColor,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
          ),
          AmountText(
            amount: amount,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseItem(
    BuildContext context,
    WidgetRef ref,
    ExpenseModel expense,
    String title,
    String subtitle,
    double amount,
    Color iconColor,
    IconData icon,
    String monthRef,
  ) {
    return _SwipeableExpenseItem(
      key: Key('expense_${expense.id}'),
      expense: expense,
      title: title,
      subtitle: subtitle,
      amount: amount,
      iconColor: iconColor,
      icon: icon,
      monthRef: monthRef,
      onEdit: () async {
        final navigator = Navigator.of(context);
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => AddExpensePage(
              monthRef: monthRef,
              expense: expense,
            ),
          ),
        );
        ref.invalidate(monthlyPlanningProvider(monthRef));
      },
      onDelete: () async {
        if (expense.id != null) {
          final expenseRepo = ref.read(expenseRepositoryProvider);
          
          // Se o gasto está vinculado a um cartão, atualizar a fatura
          if (expense.cardId != null) {
            final invoiceRepo = ref.read(cardInvoiceRepositoryProvider);
            final invoices = await invoiceRepo.getByMonth(expense.monthRef);
            final invoice = invoices.firstWhere(
              (inv) => inv.cardId == expense.cardId,
              orElse: () => CardInvoiceModel(
                id: null,
                cardId: expense.cardId!,
                monthRef: expense.monthRef,
                amount: 0,
                status: 'open',
                notes: null,
              ),
            );
            
            if (invoice.id != null) {
              final newAmount = (invoice.amount - expense.amount).clamp(0.0, double.infinity);
              await invoiceRepo.update(CardInvoiceModel(
                id: invoice.id,
                cardId: invoice.cardId,
                monthRef: invoice.monthRef,
                amount: newAmount,
                status: invoice.status,
                notes: invoice.notes,
              ));
            }
          }
          
          await expenseRepo.delete(expense.id!);
          ref.invalidate(monthlyPlanningProvider(monthRef));
        }
      },
    );
  }

  Widget _buildInvoiceItem(
    BuildContext context,
    WidgetRef ref,
    CardInvoiceModel invoice,
    String cardName,
    bool isOpen,
    double amount,
    String monthRef,
  ) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddCardInvoicePage(
              monthRef: monthRef,
              invoice: invoice,
            ),
          ),
        );
        ref.invalidate(monthlyPlanningProvider(monthRef));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isOpen ? Colors.orange.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOpen ? Colors.orange.shade200 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.credit_card, size: 18, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cardName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOpen
                              ? Colors.orange.shade100
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isOpen ? 'Aberta' : 'Paga',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isOpen
                                ? Colors.orange.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AmountText(
                  amount: amount,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeableExpenseItem extends StatefulWidget {
  final ExpenseModel expense;
  final String title;
  final String subtitle;
  final double amount;
  final Color iconColor;
  final IconData icon;
  final String monthRef;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  _SwipeableExpenseItem({
    required Key key,
    required this.expense,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.iconColor,
    required this.icon,
    required this.monthRef,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<_SwipeableExpenseItem> createState() => _SwipeableExpenseItemState();
}

class _SwipeableExpenseItemState extends State<_SwipeableExpenseItem> {
  double _dragOffset = 0.0;
  bool _isDeleteButtonVisible = false;

  void _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text('Tem certeza que deseja excluir este gasto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Sim'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onDelete();
      setState(() {
        _dragOffset = 0.0;
        _isDeleteButtonVisible = false;
      });
    } else {
      // Se cancelar, volta o item para a posição original
      setState(() {
        _dragOffset = 0.0;
        _isDeleteButtonVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx < 0) {
          // Arrastando para a esquerda
          setState(() {
            _dragOffset = (_dragOffset + details.delta.dx).clamp(-80.0, 0.0);
            _isDeleteButtonVisible = _dragOffset < -20;
          });
        } else if (details.delta.dx > 0 && _dragOffset < 0) {
          // Arrastando de volta para a direita
          setState(() {
            _dragOffset = (_dragOffset + details.delta.dx).clamp(-80.0, 0.0);
            _isDeleteButtonVisible = _dragOffset < -20;
          });
        }
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset > -40) {
          // Se não arrastou o suficiente, volta para a posição original
          setState(() {
            _dragOffset = 0.0;
            _isDeleteButtonVisible = false;
          });
        } else {
          // Mantém o botão visível
          setState(() {
            _dragOffset = -80.0;
            _isDeleteButtonVisible = true;
          });
        }
      },
      child: Stack(
        children: [
          // Botão de deletar (background)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: GestureDetector(
                onTap: _handleDelete,
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          // Item do gasto
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: InkWell(
              onTap: widget.onEdit,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.purple.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.iconColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(widget.icon, size: 18, color: Colors.grey.shade700),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AmountText(
                          amount: widget.amount,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
