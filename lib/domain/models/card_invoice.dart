class CardInvoiceModel {
  final int? id;
  final int cardId;
  final String monthRef; // YYYY-MM
  final double amount;
  final String status; // open/paid
  final String? notes;

  CardInvoiceModel({
    this.id,
    required this.cardId,
    required this.monthRef,
    required this.amount,
    this.status = 'open',
    this.notes,
  });
}

