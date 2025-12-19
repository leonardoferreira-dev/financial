import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repository_providers.dart';
import '../../domain/models/credit_card.dart';

class AddEditCardPage extends ConsumerStatefulWidget {
  final CreditCardModel? card;

  const AddEditCardPage({super.key, this.card});

  @override
  ConsumerState<AddEditCardPage> createState() => _AddEditCardPageState();
}

class _AddEditCardPageState extends ConsumerState<AddEditCardPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  int _closingDay = 1;
  int _dueDay = 10;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.card?.name ?? '');
    _closingDay = widget.card?.closingDay ?? 1;
    _dueDay = widget.card?.dueDay ?? 10;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final card = CreditCardModel(
      id: widget.card?.id,
      name: _nameController.text.trim(),
      closingDay: _closingDay,
      dueDay: _dueDay,
    );

    final repository = ref.read(creditCardRepositoryProvider);
    try {
      if (widget.card == null) {
        await repository.insert(card);
      } else {
        await repository.update(card);
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
        title: Text(widget.card == null ? 'Adicionar Cartão' : 'Editar Cartão'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nome
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do Cartão',
                border: OutlineInputBorder(),
                hintText: 'Ex: Nubank, Inter, etc',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o nome do cartão';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Dia de fechamento
            DropdownButtonFormField<int>(
              value: _closingDay,
              decoration: const InputDecoration(
                labelText: 'Dia de Fechamento',
                border: OutlineInputBorder(),
              ),
              items: List.generate(31, (index) => index + 1).map((day) {
                return DropdownMenuItem<int>(
                  value: day,
                  child: Text('Dia $day'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _closingDay = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            // Dia de vencimento
            DropdownButtonFormField<int>(
              value: _dueDay,
              decoration: const InputDecoration(
                labelText: 'Dia de Vencimento',
                border: OutlineInputBorder(),
              ),
              items: List.generate(31, (index) => index + 1).map((day) {
                return DropdownMenuItem<int>(
                  value: day,
                  child: Text('Dia $day'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _dueDay = value!;
                });
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

