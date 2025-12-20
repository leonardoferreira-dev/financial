import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repository_providers.dart';
import '../../domain/models/goal.dart';
import '../../core/goal_calculator.dart';

class AddGoalPage extends ConsumerStatefulWidget {
  final GoalModel? goal;

  const AddGoalPage({super.key, this.goal});

  @override
  ConsumerState<AddGoalPage> createState() => _AddGoalPageState();
}

class _AddGoalPageState extends ConsumerState<AddGoalPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late TextEditingController _minAmountController;
  late TextEditingController _maxAmountController;
  late TextEditingController _notesController;
  String _status = 'active';
  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.goal != null) {
      _descriptionController = TextEditingController(text: widget.goal!.description);
      _minAmountController = TextEditingController(text: widget.goal!.minAmount.toStringAsFixed(2));
      _maxAmountController = TextEditingController(text: widget.goal!.maxAmount.toStringAsFixed(2));
      _notesController = TextEditingController(text: widget.goal!.notes ?? '');
      _status = widget.goal!.status;
    } else {
      _descriptionController = TextEditingController();
      _minAmountController = TextEditingController();
      _maxAmountController = TextEditingController();
      _notesController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final description = _descriptionController.text.trim();
    final minAmount = double.tryParse(_minAmountController.text.replaceAll(',', '.')) ?? 0.0;
    final maxAmount = double.tryParse(_maxAmountController.text.replaceAll(',', '.')) ?? 0.0;

    if (minAmount >= maxAmount) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('O valor máximo deve ser maior que o valor mínimo'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isCalculating = true;
    });

    // Calcular quando o objetivo será alcançado
    final calculator = GoalCalculator(
      salaryRepo: ref.read(salaryRepositoryProvider),
      expenseRepo: ref.read(expenseRepositoryProvider),
      invoiceRepo: ref.read(cardInvoiceRepositoryProvider),
      profileRepo: ref.read(userProfileRepositoryProvider),
      recurringExpenseRepo: ref.read(recurringExpenseRepositoryProvider),
    );

    final target = await calculator.calculateTargetMonths(
      minAmount: minAmount,
      maxAmount: maxAmount,
    );

    setState(() {
      _isCalculating = false;
    });

    final goal = GoalModel(
      id: widget.goal?.id,
      description: description,
      minAmount: minAmount,
      maxAmount: maxAmount,
      minTargetMonth: target.minTargetMonth,
      maxTargetMonth: target.maxTargetMonth,
      status: _status,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    final repository = ref.read(goalRepositoryProvider);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (widget.goal == null) {
        await repository.insert(goal);
      } else {
        await repository.update(goal);
      }

      if (mounted) {
        navigator.pop();
        String message = 'Objetivo ${widget.goal == null ? 'adicionado' : 'atualizado'}!';
        if (target.minTargetMonth != null) {
          message += '\nValor mínimo em ${_formatMonth(target.minTargetMonth!)}';
        }
        if (target.maxTargetMonth != null) {
          message += '\nValor máximo em ${_formatMonth(target.maxTargetMonth!)}';
        }
        if (target.minTargetMonth == null && target.maxTargetMonth == null) {
          message += '\nNão foi possível calcular quando será alcançado.';
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatMonth(String monthRef) {
    try {
      final parts = monthRef.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final months = [
        'Janeiro',
        'Fevereiro',
        'Março',
        'Abril',
        'Maio',
        'Junho',
        'Julho',
        'Agosto',
        'Setembro',
        'Outubro',
        'Novembro',
        'Dezembro'
      ];
      return '${months[month - 1]}/$year';
    } catch (e) {
      return monthRef;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.goal == null ? 'Novo Objetivo' : 'Editar Objetivo'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição do objetivo',
                hintText: 'Ex: Comprar uma moto esportiva',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Digite uma descrição';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Valor mínimo (R\$)',
                      hintText: '0,00',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+[,.]?\d{0,2}')),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Digite o valor mínimo';
                      }
                      final amount = double.tryParse(value.replaceAll(',', '.'));
                      if (amount == null || amount <= 0) {
                        return 'Valor inválido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _maxAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Valor máximo (R\$)',
                      hintText: '0,00',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+[,.]?\d{0,2}')),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Digite o valor máximo';
                      }
                      final amount = double.tryParse(value.replaceAll(',', '.'));
                      if (amount == null || amount <= 0) {
                        return 'Valor inválido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'O mês em que você terá dinheiro suficiente será calculado automaticamente com base no seu planejamento financeiro.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.info),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'active',
                  child: Text('Ativo'),
                ),
                DropdownMenuItem(
                  value: 'completed',
                  child: Text('Concluído'),
                ),
                DropdownMenuItem(
                  value: 'cancelled',
                  child: Text('Cancelado'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _status = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                hintText: 'Informações adicionais sobre o objetivo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isCalculating ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isCalculating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Salvar',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            if (widget.goal != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirmar exclusão'),
                        content: const Text('Deseja realmente excluir este objetivo?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ref.read(goalRepositoryProvider).delete(widget.goal!.id!);
                        if (mounted) {
                          navigator.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Objetivo excluído!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Erro ao excluir: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Excluir'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

