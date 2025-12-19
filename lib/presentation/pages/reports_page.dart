import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/repository_providers.dart';
import '../widgets/amount_text.dart';

final selectedYearProvider = StateProvider<int>((ref) {
  return DateTime.now().year;
});

final monthlyBalanceProvider = FutureProvider.family<List<MonthlyBalance>, int>((ref, year) async {
  final salaryRepo = ref.watch(salaryRepositoryProvider);
  final expenseRepo = ref.watch(expenseRepositoryProvider);
  final invoiceRepo = ref.watch(cardInvoiceRepositoryProvider);
  final profileRepo = ref.watch(userProfileRepositoryProvider);
  final recurringExpenseRepo = ref.watch(recurringExpenseRepositoryProvider);

  final profile = await profileRepo.get();
  final initialBalance = profile?.initialBalance ?? 0.0;
  final totalIncome = await expenseRepo.getTotalIncome();
  
  // Verificar qual é o primeiro mês com salário
  final allSalaries = await salaryRepo.getAll();
  final firstSalaryMonth = allSalaries.isNotEmpty 
      ? allSalaries.map((s) => s.startMonth).reduce((a, b) => a.compareTo(b) < 0 ? a : b)
      : null;

  final List<MonthlyBalance> balances = [];
  double accumulatedBalance = 0.0;
  bool initialBalanceAdded = false;

  for (int month = 1; month <= 12; month++) {
    final monthRef = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    
    // Buscar salário do mês
    final salary = await salaryRepo.getForMonth(monthRef);
    final salaryAmount = salary?.amount ?? 0.0;
    
    // Buscar gastos do mês
    final totalExpenses = await expenseRepo.getTotalByMonth(monthRef);
    
    // Buscar gastos fixos do mês
    final totalRecurringExpenses = await recurringExpenseRepo.getTotalForMonth(monthRef);
    
    // Buscar faturas do mês
    final totalInvoices = await invoiceRepo.getTotalByMonth(monthRef);
    
    // Adicionar saldo inicial apenas no primeiro mês com salário (se ainda não foi adicionado)
    final shouldAddInitialBalance = !initialBalanceAdded && 
        firstSalaryMonth != null && 
        monthRef == firstSalaryMonth;
    
    if (shouldAddInitialBalance) {
      initialBalanceAdded = true;
    }
    
    // Calcular saldo do mês: salário + receitas + saldo inicial (se for o primeiro mês) - gastos - gastos fixos - faturas
    final monthlyBalance = salaryAmount + totalIncome + (shouldAddInitialBalance ? initialBalance : 0.0) - totalExpenses - totalRecurringExpenses - totalInvoices;
    
    // Saldo acumulado (saldo do mês + saldo acumulado anterior)
    accumulatedBalance += monthlyBalance;
    
    balances.add(MonthlyBalance(
      monthRef: monthRef,
      month: month,
      year: year,
      salary: salaryAmount,
      expenses: totalExpenses,
      invoices: totalInvoices,
      monthlyBalance: monthlyBalance,
      accumulatedBalance: accumulatedBalance,
      totalIncome: totalIncome,
      initialBalance: shouldAddInitialBalance ? initialBalance : 0.0,
      recurringExpenses: totalRecurringExpenses,
    ));
  }

  return balances;
});

class MonthlyBalance {
  final String monthRef;
  final int month;
  final int year;
  final double salary;
  final double expenses;
  final double invoices;
  final double monthlyBalance;
  final double accumulatedBalance;
  final double totalIncome;
  final double initialBalance;
  final double recurringExpenses;

  MonthlyBalance({
    required this.monthRef,
    required this.month,
    required this.year,
    required this.salary,
    required this.expenses,
    required this.invoices,
    required this.monthlyBalance,
    required this.accumulatedBalance,
    required this.totalIncome,
    required this.initialBalance,
    required this.recurringExpenses,
  });
}

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedYear = ref.watch(selectedYearProvider);
    final balancesAsync = ref.watch(monthlyBalanceProvider(selectedYear));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Relatórios'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(monthlyBalanceProvider(selectedYear));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header com seletor de ano (sempre visível)
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Column(
                      children: [
                        // Seletor de ano
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, color: Colors.white),
                              onPressed: () {
                                ref.read(selectedYearProvider.notifier).state = selectedYear - 1;
                              },
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                              ),
                              child: Text(
                                selectedYear.toString(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, color: Colors.white),
                              onPressed: () {
                                ref.read(selectedYearProvider.notifier).state = selectedYear + 1;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Resumo anual destacado
                        balancesAsync.when(
                          data: (balances) {
                            final totalYear = balances.last.accumulatedBalance;
                            return Container(
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
                                    'Saldo Final do Ano',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  AmountText(
                                    amount: totalYear,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                    positiveColor: Colors.green.shade700,
                                    negativeColor: Colors.red.shade700,
                                  ),
                                ],
                              ),
                            );
                          },
                          loading: () => Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (_, __) => Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text('Erro ao carregar dados'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Conteúdo dos meses
            ...balancesAsync.when<List<Widget>>(
              data: (balances) {
                final hasData = balances.any((b) => b.salary > 0 || b.expenses > 0 || b.invoices > 0);

                if (!hasData) {
                  return [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bar_chart_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhum dado encontrado para $selectedYear',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ];
                }

                return [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final balance = balances[index];
                          final monthName = _formatMonth(balance.month);
                          final isPositive = balance.accumulatedBalance >= 0;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                children: [
                                  // Header do mês
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isPositive
                                            ? [Colors.green.shade50, Colors.green.shade100.withValues(alpha: 0.3)]
                                            : [Colors.red.shade50, Colors.red.shade100.withValues(alpha: 0.3)],
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isPositive
                                                ? Colors.green.shade100
                                                : Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            isPositive ? Icons.trending_up : Icons.trending_down,
                                            color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                monthName,
                                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.grey.shade800,
                                                    ),
                                              ),
                                              Text(
                                                '$monthName/${balance.year}',
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                      color: Colors.grey.shade600,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        AmountText(
                                          amount: balance.accumulatedBalance,
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                          positiveColor: Colors.green.shade700,
                                          negativeColor: Colors.red.shade700,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Detalhes do mês
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        _buildDetailRow(
                                          context,
                                          Icons.account_balance_wallet,
                                          'Salário',
                                          balance.salary,
                                          Colors.green.shade700,
                                        ),
                                        const SizedBox(height: 12),
                                        _buildDetailRow(
                                          context,
                                          Icons.shopping_cart,
                                          'Gastos',
                                          -balance.expenses,
                                          Colors.red.shade700,
                                        ),
                                        const SizedBox(height: 12),
                                        _buildDetailRow(
                                          context,
                                          Icons.credit_card,
                                          'Faturas',
                                          -balance.invoices,
                                          Colors.orange.shade700,
                                        ),
                                        const Divider(height: 32),
                                        _buildDetailRow(
                                          context,
                                          Icons.account_balance,
                                          'Saldo do Mês',
                                          balance.monthlyBalance,
                                          balance.monthlyBalance >= 0
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                          isBold: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: balances.length,
                      ),
                    ),
                  ),
                ];
              },
              loading: () => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (error, stack) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
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
                          'Erro ao carregar relatórios',
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
                            ref.invalidate(monthlyBalanceProvider(selectedYear));
                          },
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatMonth(int month) {
    final date = DateTime(2024, month);
    final monthName = DateFormat('MMMM', 'pt_BR').format(date);
    return monthName[0].toUpperCase() + monthName.substring(1);
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    double amount,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                  color: Colors.grey.shade700,
                ),
          ),
        ),
        AmountText(
          amount: amount,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
          positiveColor: color,
          negativeColor: color,
          showPositiveSign: amount > 0 && !isBold,
        ),
      ],
    );
  }
}
