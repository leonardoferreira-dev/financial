import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/repository_providers.dart' as providers;
import '../../domain/models/goal.dart';
import '../../core/goal_calculator.dart';
import '../widgets/amount_text.dart';
import 'add_goal_page.dart';

final goalsListProvider = FutureProvider<List<GoalModel>>((ref) async {
  final repository = ref.watch(providers.goalRepositoryProvider);
  return repository.getAll();
});

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Objetivos'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum objetivo cadastrado',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque no botão + para adicionar',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(goalsListProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                return _GoalCard(goal: goal);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar objetivos: $error'),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'goals_fab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddGoalPage(),
            ),
          );
          ref.invalidate(goalsListProvider);
        },
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  final GoalModel goal;

  const _GoalCard({required this.goal});

  String _formatMonth(String monthRef) {
    try {
      final parts = monthRef.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final date = DateTime(year, month);
      return DateFormat('MMMM yyyy', 'pt_BR').format(date);
    } catch (e) {
      return monthRef;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Concluído';
      case 'cancelled':
        return 'Cancelado';
      default:
        return 'Ativo';
    }
  }

  Future<void> _recalculateGoal(BuildContext context, WidgetRef ref, GoalModel goal) async {
    final messenger = ScaffoldMessenger.of(context);
    
    // Mostrar loading
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Recalculando objetivo...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    final calculator = GoalCalculator(
      salaryRepo: ref.read(providers.salaryRepositoryProvider),
      expenseRepo: ref.read(providers.expenseRepositoryProvider),
      invoiceRepo: ref.read(providers.cardInvoiceRepositoryProvider),
      profileRepo: ref.read(providers.userProfileRepositoryProvider),
      recurringExpenseRepo: ref.read(providers.recurringExpenseRepositoryProvider),
    );

    final target = await calculator.calculateTargetMonths(
      minAmount: goal.minAmount,
      maxAmount: goal.maxAmount,
    );

    final updatedGoal = goal.copyWith(
      minTargetMonth: target.minTargetMonth,
      maxTargetMonth: target.maxTargetMonth,
    );
    await ref.read(providers.goalRepositoryProvider).update(updatedGoal);
    
    ref.invalidate(goalsListProvider);
    
    String message = 'Objetivo recalculado!';
    if (target.minTargetMonth != null) {
      message += '\nValor mínimo em ${_formatMonth(target.minTargetMonth!)}';
    }
    if (target.maxTargetMonth != null) {
      message += '\nValor máximo em ${_formatMonth(target.maxTargetMonth!)}';
    }
    if (target.minTargetMonth == null && target.maxTargetMonth == null) {
      message = 'Não foi possível calcular quando o objetivo será alcançado. Verifique seus dados financeiros.';
    }
    
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: target.minTargetMonth != null || target.maxTargetMonth != null ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddGoalPage(goal: goal),
            ),
          );
          ref.invalidate(goalsListProvider);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.description,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(goal.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(goal.status),
                      style: TextStyle(
                        color: _getStatusColor(goal.status),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Valor mínimo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        AmountText(
                          amount: goal.minAmount,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Valor máximo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        AmountText(
                          amount: goal.maxAmount,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (goal.minTargetMonth != null || goal.maxTargetMonth != null) ...[
                if (goal.minTargetMonth != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 16,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Valor mínimo em: ${_formatMonth(goal.minTargetMonth!)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (goal.maxTargetMonth != null)
                  Row(
                    children: [
                      Icon(
                        Icons.attach_money,
                        size: 16,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Valor máximo em: ${_formatMonth(goal.maxTargetMonth!)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
              ] else
                Row(
                  children: [
                    Icon(
                      Icons.calculate,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Calculando quando será alcançado...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              if (goal.notes != null && goal.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  goal.notes!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _recalculateGoal(context, ref, goal),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Recalcular'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

