import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/repository_providers.dart';
import '../../domain/models/salary_history.dart';
import '../widgets/amount_text.dart';

final salaryHistoryProvider = FutureProvider<List<SalaryHistoryModel>>((ref) async {
  final repository = ref.watch(salaryRepositoryProvider);
  return repository.getAll();
});

class SalaryHistoryPage extends ConsumerWidget {
  const SalaryHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salaryHistoryAsync = ref.watch(salaryHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Salários'),
      ),
      body: salaryHistoryAsync.when(
        data: (salaries) => Column(
          children: [
            Expanded(
              child: salaries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhum salário cadastrado',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: salaries.length,
                      itemBuilder: (context, index) {
                        final salary = salaries[index];
                        return Card(
                          child: ListTile(
                            title: AmountText(
                              amount: salary.amount,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            subtitle: Text(
                              '${_formatMonth(salary.startMonth)} - ${salary.endMonth != null ? _formatMonth(salary.endMonth!) : "Atual"}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editSalary(context, ref, salary),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Erro ao carregar: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(salaryHistoryProvider);
                },
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'salary_history_fab',
        onPressed: () => _addSalary(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatMonth(String monthRef) {
    final parts = monthRef.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final date = DateTime(year, month);
    final monthName = DateFormat('MMMM yyyy', 'pt_BR').format(date);
    return monthName[0].toUpperCase() + monthName.substring(1);
  }

  Future<void> _addSalary(BuildContext context, WidgetRef ref) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditSalaryPage(),
      ),
    );
    ref.invalidate(salaryHistoryProvider);
  }

  Future<void> _editSalary(
    BuildContext context,
    WidgetRef ref,
    SalaryHistoryModel salary,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditSalaryPage(salary: salary),
      ),
    );
    ref.invalidate(salaryHistoryProvider);
  }
}

class AddEditSalaryPage extends ConsumerStatefulWidget {
  final SalaryHistoryModel? salary;

  const AddEditSalaryPage({super.key, this.salary});

  @override
  ConsumerState<AddEditSalaryPage> createState() => _AddEditSalaryPageState();
}

class _AddEditSalaryPageState extends ConsumerState<AddEditSalaryPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _startMonthController;
  String? _endMonth;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.salary?.amount.toString() ?? '',
    );
    _startMonthController = TextEditingController(
      text: widget.salary?.startMonth ?? '',
    );
    _endMonth = widget.salary?.endMonth;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _startMonthController.dispose();
    super.dispose();
  }

  Future<void> _selectStartMonth() async {
    final parts = _startMonthController.text.split('-');
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
      helpText: 'Selecione o mês inicial',
    );

    if (picked != null) {
      setState(() {
        _startMonthController.text =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _selectEndMonth() async {
    if (_startMonthController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o mês inicial primeiro')),
      );
      return;
    }

    final parts = _startMonthController.text.split('-');
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
      helpText: 'Selecione o mês final (ou deixe em branco para atual)',
    );

    if (picked != null) {
      setState(() {
        _endMonth =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final salary = SalaryHistoryModel(
      id: widget.salary?.id,
      amount: double.parse(_amountController.text.replaceAll(',', '.')),
      startMonth: _startMonthController.text.trim(),
      endMonth: _endMonth?.isEmpty ?? true ? null : _endMonth,
    );

    final repository = ref.read(salaryRepositoryProvider);
    try {
      if (widget.salary == null) {
        await repository.insert(salary);
      } else {
        await repository.update(salary);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.salary == null ? 'Adicionar Salário' : 'Editar Salário'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                child: Text(_startMonthController.text.isEmpty ? 'Selecione o mês' : _startMonthController.text),
              ),
            ),
            const SizedBox(height: 16),
            // Mês final (opcional)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectEndMonth,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Mês Final (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_endMonth ?? 'Deixar em branco para atual'),
                    ),
                  ),
                ),
                if (_endMonth != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _endMonth = null;
                      });
                    },
                  ),
              ],
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

