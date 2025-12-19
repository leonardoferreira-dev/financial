import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/repository_providers.dart';
import '../../domain/models/card_invoice.dart';
import '../../domain/models/credit_card.dart';
import '../widgets/amount_text.dart';
import 'add_card_invoice_page.dart';

final cardInvoicesProvider = FutureProvider.family<List<CardInvoiceModel>, int>((ref, cardId) async {
  final repository = ref.watch(cardInvoiceRepositoryProvider);
  return repository.getByCard(cardId);
});

class CardInvoicesPage extends ConsumerWidget {
  final CreditCardModel card;

  const CardInvoicesPage({
    super.key,
    required this.card,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(cardInvoicesProvider(card.id!));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(card.name),
        elevation: 0,
      ),
      body: invoicesAsync.when(
        data: (invoices) {
          if (invoices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: Colors.orange.shade300,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Nenhuma fatura encontrada',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adicione uma fatura para este cartão',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                ],
              ),
            );
          }

          // Agrupar faturas por ano
          final Map<int, List<CardInvoiceModel>> invoicesByYear = {};
          for (final invoice in invoices) {
            final year = int.parse(invoice.monthRef.split('-')[0]);
            invoicesByYear.putIfAbsent(year, () => []).add(invoice);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(cardInvoicesProvider(card.id!));
            },
            child: CustomScrollView(
              slivers: [
                // Header com informações do cartão
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.orange.shade400,
                          Colors.orange.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.credit_card,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    card.name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Fechamento: dia ${card.closingDay} | Vencimento: dia ${card.dueDay}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Lista de faturas por ano
                ...invoicesByYear.entries.map((entry) {
                  final year = entry.key;
                  final yearInvoices = entry.value;
                  final totalYear = yearInvoices
                      .where((i) => i.status == 'open')
                      .fold<double>(0.0, (sum, invoice) => sum + invoice.amount);

                  return SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                year.toString(),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: AmountText(
                                  amount: totalYear,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                  positiveColor: Colors.orange.shade700,
                                  negativeColor: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...yearInvoices.map((invoice) {
                          return _buildInvoiceCard(context, ref, invoice, card);
                        }),
                      ],
                    ),
                  );
                }),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            ),
          );
        },
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
                'Erro ao carregar faturas',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(cardInvoicesProvider(card.id!));
                },
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'card_invoices_fab',
        onPressed: () async {
          final now = DateTime.now();
          final defaultMonthRef =
              '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
          
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddCardInvoicePage(monthRef: defaultMonthRef),
            ),
          );
          ref.invalidate(cardInvoicesProvider(card.id!));
        },
        icon: const Icon(Icons.add),
        label: const Text('Adicionar Fatura'),
      ),
    );
  }

  Widget _buildInvoiceCard(
    BuildContext context,
    WidgetRef ref,
    CardInvoiceModel invoice,
    CreditCardModel card,
  ) {
    final monthName = _formatMonth(invoice.monthRef);
    final isOpen = invoice.status == 'open';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddCardInvoicePage(
                  monthRef: invoice.monthRef,
                  invoice: invoice,
                ),
              ),
            );
            ref.invalidate(cardInvoicesProvider(card.id!));
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? Colors.orange.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isOpen ? Icons.receipt_long : Icons.check_circle_outline,
                    color: isOpen ? Colors.orange.shade700 : Colors.grey.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOpen
                                  ? Colors.orange.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isOpen ? 'Aberta' : 'Paga',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isOpen
                                    ? Colors.orange.shade700
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.note_outlined,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                          ],
                        ],
                      ),
                      if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          invoice.notes!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(
                      amount: invoice.amount,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      positiveColor: Colors.grey.shade800,
                      negativeColor: Colors.red.shade700,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          color: Colors.grey.shade400,
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddCardInvoicePage(
                                  monthRef: invoice.monthRef,
                                  invoice: invoice,
                                ),
                              ),
                            );
                            ref.invalidate(cardInvoicesProvider(card.id!));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Colors.red.shade400,
                          onPressed: () => _showDeleteDialog(context, ref, invoice, card),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  Future<void> _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    CardInvoiceModel invoice,
    CreditCardModel card,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Excluir fatura?'),
        content: Text(
          'Deseja excluir a fatura de ${_formatMonth(invoice.monthRef)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final repository = ref.read(cardInvoiceRepositoryProvider);
      await repository.delete(invoice.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Fatura excluída com sucesso'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        ref.invalidate(cardInvoicesProvider(card.id!));
      }
    }
  }
}

