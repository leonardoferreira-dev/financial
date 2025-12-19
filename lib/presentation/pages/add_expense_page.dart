import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/repository_providers.dart';
import '../../domain/models/expense.dart';

class AddExpensePage extends ConsumerStatefulWidget {
  final String monthRef;
  final ExpenseModel? expense;

  const AddExpensePage({
    super.key,
    required this.monthRef,
    this.expense,
  });

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  int? _selectedCategoryId;
  int? _selectedCardId;
  String _type = 'expense';

  DateTime _getInitialDate() {
    if (widget.expense != null) {
      return widget.expense!.date;
    }
    
    // Se não há gasto existente, usar o dia atual mas com o ano e mês do monthRef
    final now = DateTime.now();
    final monthRefParts = widget.monthRef.split('-');
    if (monthRefParts.length == 2) {
      final year = int.tryParse(monthRefParts[0]);
      final month = int.tryParse(monthRefParts[1]);
      if (year != null && month != null) {
        // Usar o dia atual, mas garantir que não ultrapasse o último dia do mês
        final lastDayOfMonth = DateTime(year, month + 1, 0).day;
        final day = now.day > lastDayOfMonth ? lastDayOfMonth : now.day;
        return DateTime(year, month, day);
      }
    }
    
    // Fallback para data atual
    return now;
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = _getInitialDate();
    _descriptionController = TextEditingController(text: widget.expense?.description ?? '');
    _amountController = TextEditingController(
      text: widget.expense?.amount.toString() ?? '',
    );
    _selectedCategoryId = widget.expense?.categoryId;
    _selectedCardId = widget.expense?.cardId;
    _type = widget.expense?.type ?? 'expense';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
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

    final expense = ExpenseModel(
      id: widget.expense?.id,
      date: _selectedDate,
      monthRef: widget.monthRef,
      description: _descriptionController.text.trim(),
      categoryId: _selectedCategoryId!,
      amount: double.parse(_amountController.text.replaceAll(',', '.')),
      type: _type,
      cardId: _selectedCardId,
    );

    final repository = ref.read(expenseRepositoryProvider);
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

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);
    final cardsAsync = ref.watch(creditCardsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Adicionar Gasto' : 'Editar Gasto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Data
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Descrição
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe a descrição';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Tipo (Gasto ou Receita)
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<String>(
                  value: 'expense',
                  child: Text('Gasto'),
                ),
                DropdownMenuItem<String>(
                  value: 'income',
                  child: Text('Receita'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _type = value!;
                  // Se for receita, não pode vincular a cartão
                  if (_type == 'income') {
                    _selectedCardId = null;
                  }
                });
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
            // Cartão (opcional, apenas para gastos)
            if (_type == 'expense')
              cardsAsync.when(
              data: (cards) {
                if (cards.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      value: _selectedCardId,
                      decoration: const InputDecoration(
                        labelText: 'Cartão de Crédito (opcional)',
                        border: OutlineInputBorder(),
                        helperText: 'Vincular este gasto a uma fatura',
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
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            if (_type == 'expense') const SizedBox(height: 16),
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
}

