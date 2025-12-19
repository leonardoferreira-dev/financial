import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/repository_providers.dart';
import '../../domain/models/card_invoice.dart';

class AddCardInvoicePage extends ConsumerStatefulWidget {
  final String monthRef;
  final CardInvoiceModel? invoice;

  const AddCardInvoicePage({
    super.key,
    required this.monthRef,
    this.invoice,
  });

  @override
  ConsumerState<AddCardInvoicePage> createState() => _AddCardInvoicePageState();
}

class _AddCardInvoicePageState extends ConsumerState<AddCardInvoicePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  int? _selectedCardId;
  String _selectedStatus = 'open';
  late String _selectedMonthRef;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.invoice?.amount.toString() ?? '',
    );
    _notesController = TextEditingController(text: widget.invoice?.notes ?? '');
    _selectedCardId = widget.invoice?.cardId;
    _selectedStatus = widget.invoice?.status ?? 'open';
    _selectedMonthRef = widget.invoice?.monthRef ?? widget.monthRef;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatMonth(String monthRef) {
    final parts = monthRef.split('-');
    if (parts.length != 2) return monthRef;
    
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final date = DateTime(year, month);
    
    final monthName = DateFormat('MMMM yyyy', 'pt_BR').format(date);
    return monthName[0].toUpperCase() + monthName.substring(1);
  }

  Future<void> _selectMonth() async {
    final parts = _selectedMonthRef.split('-');
    DateTime initialDate = DateTime.now();
    if (parts.length == 2) {
      try {
        initialDate = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      } catch (_) {}
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Selecione o mês da fatura',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedMonthRef = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um cartão')),
      );
      return;
    }

    final invoice = CardInvoiceModel(
      id: widget.invoice?.id,
      cardId: _selectedCardId!,
      monthRef: _selectedMonthRef,
      amount: double.parse(_amountController.text.replaceAll(',', '.')),
      status: _selectedStatus,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    final repository = ref.read(cardInvoiceRepositoryProvider);
    try {
      if (widget.invoice == null) {
        await repository.insert(invoice);
      } else {
        await repository.update(invoice);
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
    final cardsAsync = ref.watch(creditCardsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.invoice == null ? 'Adicionar Fatura' : 'Editar Fatura'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Cartão
            cardsAsync.when(
              data: (cards) {
                if (cards.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Nenhum cartão cadastrado. Cadastre um cartão primeiro.'),
                    ),
                  );
                }
                return DropdownButtonFormField<int>(
                  value: _selectedCardId,
                  decoration: const InputDecoration(
                    labelText: 'Cartão',
                    border: OutlineInputBorder(),
                  ),
                  items: cards.map((card) {
                    return DropdownMenuItem<int>(
                      value: card.id,
                      child: Text(card.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCardId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Selecione um cartão';
                    }
                    return null;
                  },
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Erro ao carregar cartões'),
            ),
            const SizedBox(height: 16),
            // Mês de referência
            InkWell(
              onTap: _selectMonth,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Mês de Referência',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(_formatMonth(_selectedMonthRef)),
              ),
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
            // Status
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'open', child: Text('Aberta')),
                DropdownMenuItem(value: 'paid', child: Text('Paga')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            // Notas
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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

