import '../../data/repositories/salary_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/card_invoice_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../data/repositories/recurring_expense_repository.dart';
import '../../domain/models/goal_target.dart';

class GoalCalculator {
  final SalaryRepository _salaryRepo;
  final ExpenseRepository _expenseRepo;
  final CardInvoiceRepository _invoiceRepo;
  final UserProfileRepository _profileRepo;
  final RecurringExpenseRepository _recurringExpenseRepo;

  GoalCalculator({
    required SalaryRepository salaryRepo,
    required ExpenseRepository expenseRepo,
    required CardInvoiceRepository invoiceRepo,
    required UserProfileRepository profileRepo,
    required RecurringExpenseRepository recurringExpenseRepo,
  })  : _salaryRepo = salaryRepo,
        _expenseRepo = expenseRepo,
        _invoiceRepo = invoiceRepo,
        _profileRepo = profileRepo,
        _recurringExpenseRepo = recurringExpenseRepo;

  /// Calcula quando o objetivo será alcançado baseado no saldo acumulado
  /// Retorna os meses (YYYY-MM) quando o saldo acumulado será suficiente para o valor mínimo e máximo
  Future<GoalTarget> calculateTargetMonths({
    required double minAmount,
    required double maxAmount,
    int maxYears = 10, // Máximo de anos para calcular
  }) async {
    final profile = await _profileRepo.get();
    final initialBalance = profile?.initialBalance ?? 0.0;

    // Verificar qual é o primeiro mês com salário
    final allSalaries = await _salaryRepo.getAll();
    final firstSalaryMonth = allSalaries.isNotEmpty
        ? allSalaries.map((s) => s.startMonth).reduce((a, b) => a.compareTo(b) < 0 ? a : b)
        : null;

    if (firstSalaryMonth == null) {
      // Sem salários cadastrados, não é possível calcular
      return GoalTarget();
    }

    final parts = firstSalaryMonth.split('-');
    final startYear = int.parse(parts[0]);
    final startMonth = int.parse(parts[1]);

    double accumulatedBalance = 0.0;
    bool initialBalanceAdded = false;
    String? minTargetMonth;
    String? maxTargetMonth;

    // Calcular até maxYears anos à frente
    for (int yearOffset = 0; yearOffset < maxYears; yearOffset++) {
      final currentYear = startYear + yearOffset;
      final monthStart = yearOffset == 0 ? startMonth : 1;
      final monthEnd = 12;

      for (int month = monthStart; month <= monthEnd; month++) {
        final monthRef = '${currentYear.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

        // Buscar salário do mês
        final salary = await _salaryRepo.getForMonth(monthRef);
        final salaryAmount = salary?.amount ?? 0.0;

        // Buscar gastos e receitas do mês
        final expenses = await _expenseRepo.getByMonth(monthRef);
        final totalExpenses = expenses
            .where((e) => e.type == 'expense')
            .fold(0.0, (sum, e) => sum + e.amount);
        
        // Receitas do mês (não todas as receitas, apenas as do mês específico)
        final totalIncome = expenses
            .where((e) => e.type == 'income')
            .fold(0.0, (sum, e) => sum + e.amount);

        // Buscar gastos fixos do mês
        final totalRecurringExpenses = await _recurringExpenseRepo.getTotalForMonth(monthRef);

        // Buscar faturas do mês
        final totalInvoices = await _invoiceRepo.getTotalByMonth(monthRef);

        // Adicionar saldo inicial apenas no primeiro mês com salário
        final shouldAddInitialBalance = !initialBalanceAdded &&
            monthRef == firstSalaryMonth;

        if (shouldAddInitialBalance) {
          initialBalanceAdded = true;
        }

        // Calcular saldo do mês: salário + receitas do mês + saldo inicial (se for o primeiro mês) - gastos - gastos fixos - faturas
        final monthlyBalance = salaryAmount +
            totalIncome +
            (shouldAddInitialBalance ? initialBalance : 0.0) -
            totalExpenses -
            totalRecurringExpenses -
            totalInvoices;

        // Saldo acumulado (soma do saldo do mês com o acumulado anterior)
        accumulatedBalance += monthlyBalance;

        // Verificar se alcançou o valor mínimo (apenas uma vez)
        if (minTargetMonth == null && accumulatedBalance >= minAmount) {
          minTargetMonth = monthRef;
        }

        // Verificar se alcançou o valor máximo (apenas uma vez)
        if (maxTargetMonth == null && accumulatedBalance >= maxAmount) {
          maxTargetMonth = monthRef;
          // Se já alcançou o máximo, pode parar
          break;
        }
      }

      // Se já encontrou ambos, pode parar
      if (minTargetMonth != null && maxTargetMonth != null) {
        break;
      }
    }

    return GoalTarget(
      minTargetMonth: minTargetMonth,
      maxTargetMonth: maxTargetMonth,
    );
  }

  /// Calcula o saldo acumulado até um mês específico
  Future<double> getAccumulatedBalanceUntil(String monthRef) async {
    final profile = await _profileRepo.get();
    final initialBalance = profile?.initialBalance ?? 0.0;
    final totalIncome = await _expenseRepo.getTotalIncome();

    final allSalaries = await _salaryRepo.getAll();
    final firstSalaryMonth = allSalaries.isNotEmpty
        ? allSalaries.map((s) => s.startMonth).reduce((a, b) => a.compareTo(b) < 0 ? a : b)
        : null;

    if (firstSalaryMonth == null) {
      return 0.0;
    }

    final parts = firstSalaryMonth.split('-');
    final startYear = int.parse(parts[0]);
    final startMonth = int.parse(parts[1]);

    final targetParts = monthRef.split('-');
    final targetYear = int.parse(targetParts[0]);
    final targetMonth = int.parse(targetParts[1]);

    double accumulatedBalance = 0.0;
    bool initialBalanceAdded = false;

    for (int year = startYear; year <= targetYear; year++) {
      final monthStart = year == startYear ? startMonth : 1;
      final monthEnd = year == targetYear ? targetMonth : 12;

      for (int month = monthStart; month <= monthEnd; month++) {
        final currentMonthRef = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

        final salary = await _salaryRepo.getForMonth(currentMonthRef);
        final salaryAmount = salary?.amount ?? 0.0;
        final totalExpenses = await _expenseRepo.getTotalByMonth(currentMonthRef);
        final totalRecurringExpenses = await _recurringExpenseRepo.getTotalForMonth(currentMonthRef);
        final totalInvoices = await _invoiceRepo.getTotalByMonth(currentMonthRef);

        final shouldAddInitialBalance = !initialBalanceAdded && currentMonthRef == firstSalaryMonth;
        if (shouldAddInitialBalance) {
          initialBalanceAdded = true;
        }

        final monthlyBalance = salaryAmount +
            totalIncome +
            (shouldAddInitialBalance ? initialBalance : 0.0) -
            totalExpenses -
            totalRecurringExpenses -
            totalInvoices;

        accumulatedBalance += monthlyBalance;
      }
    }

    return accumulatedBalance;
  }
}

