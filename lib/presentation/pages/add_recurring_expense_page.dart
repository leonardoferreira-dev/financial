import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/repository_providers.dart';
import '../../domain/models/recurring_expense.dart';
import '../../domain/models/category.dart';
import '../../domain/models/credit_card.dart';

class AddRecurringExpensePage extends ConsumerStatefulWidget {
  final RecurringExpenseModel? expense;

  const AddRecurringExpensePage({super.key, this.expense});

  @override
  ConsumerState<AddRecurringExpensePage> createState() => _AddRecurringExpensePageState();
}

class _AddRecurringExpensePageState extends ConsumerState<AddRecurringExpensePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late TextEditingController _startMonthController;
  late TextEditingController _endMonthController;
  int? _selectedCategoryId;
  int? _selectedCardId;
  bool _hasEndMonth = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.expense?.description ?? '');
    _amountController = TextEditingController(
      text: widget.expense?.amount.toString() ?? '',
    );
    _startMonthController = TextEditingController(text: widget.expense?.startMonth ?? '');
    _endMonthController = TextEditingController(text: widget.expense?.endMonth ?? '');
    _selectedCategoryId = widget.expense?.categoryId;
    _selectedCardId = widget.expense?.cardId;
    _hasEndMonth = widget.expense?.endMonth != null;
    
    // Se não há gasto existente, usar o mês atual
    if (widget.expense == null) {
      final now = DateTime.now();
      _startMonthController.text = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _startMonthController.dispose();
    _endMonthController.dispose();
    super.dispose();
  }

  Future<void> _selectStartMonth() async {
    final parts = _startMonthController.text.split('-');
    DateTime initialDate = DateTime.now();
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null) {
        initialDate = DateTime(year, month);
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        _startMonthController.text = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _selectEndMonth() async {
    final parts = _endMonthController.text.split('-');
    DateTime initialDate = DateTime.now();
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null) {
        initialDate = DateTime(year, month);
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        _endMonthController.text = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma categoria')),
      );
      return;
    }

    if (!_validateMonthFormat(_startMonthController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formato de mês inicial inválido (use YYYY-MM)')),
      );
      return;
    }

    if (_hasEndMonth && _endMonthController.text.isNotEmpty) {
      if (!_validateMonthFormat(_endMonthController.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Formato de mês final inválido (use YYYY-MM)')),
        );
        return;
      }

      if (_endMonthController.text.compareTo(_startMonthController.text) < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O mês final deve ser posterior ao mês inicial')),
        );
        return;
      }
    }

    final expense = RecurringExpenseModel(
      id: widget.expense?.id,
      description: _descriptionController.text.trim(),
      categoryId: _selectedCategoryId!,
      amount: double.parse(_amountController.text.replaceAll(',', '.')),
      startMonth: _startMonthController.text.trim(),
      endMonth: _hasEndMonth && _endMonthController.text.isNotEmpty
          ? _endMonthController.text.trim()
          : null,
      isActive: true,
      cardId: _selectedCardId,
    );

    final repository = ref.read(recurringExpenseRepositoryProvider);
    try {
      if (widget.expense == null) {
        await repository.insert(expense);
      } else {
        await repository.update(expense);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    }
  }

  bool _validateMonthFormat(String monthRef) {
    final parts = monthRef.split('-');
    if (parts.length != 2) return false;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return false;
    if (month < 1 || month > 12) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);
    final cardsAsync = ref.watch(creditCardsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Adicionar Gasto Fixo' : 'Editar Gasto Fixo'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Descrição
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
                hintText: 'Ex: Netflix, Spotify, etc',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe a descrição';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Categoria
            categoriesAsync.when(
              data: (categories) => DropdownButtonFormField<int>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem<int>(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Selecione uma categoria';
                  }
                  return null;
                },
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Erro ao carregar categorias'),
            ),
            const SizedBox(height: 16),
            // Valor
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                border: OutlineInputBorder(),
                prefixText: 'R\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o valor';
                }
                final amount = double.tryParse(value.replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  return 'Valor inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Mês inicial
            InkWell(
              onTap: _selectStartMonth,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Mês Inicial (YYYY-MM)',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _startMonthController.text.isEmpty
                      ? 'Selecione o mês'
                      : _formatMonth(_startMonthController.text),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Checkbox para ter mês final
            CheckboxListTile(
              title: const Text('Definir mês final'),
              value: _hasEndMonth,
              onChanged: (value) {
                setState(() {
                  _hasEndMonth = value ?? false;
                  if (!_hasEndMonth) {
                    _endMonthController.clear();
                  }
                });
              },
            ),
            // Mês final (opcional)
            if (_hasEndMonth) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectEndMonth,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Mês Final (YYYY-MM) - Opcional',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _endMonthController.text.isEmpty
                        ? 'Selecione o mês'
                        : _formatMonth(_endMonthController.text),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Cartão (opcional)
            cardsAsync.when(
              data: (cards) {
                if (cards.isEmpty) {
                  return const SizedBox.shrink();
                }
                return DropdownButtonFormField<int>(
                  value: _selectedCardId,
                  decoration: const InputDecoration(
                    labelText: 'Cartão de Crédito (opcional)',
                    border: OutlineInputBorder(),
                    helperText: 'Vincular este gasto fixo a uma fatura',
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Não vincular a cartão'),
                    ),
                    ...cards.map((card) {
                      return DropdownMenuItem<int>(
                        value: card.id,
                        child: Text(card.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCardId = value;
                    });
                  },
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Salvar'),
            ),
          ],
        ),
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

