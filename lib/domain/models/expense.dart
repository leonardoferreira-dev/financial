class ExpenseModel {
  final int? id;
  final DateTime date;
  final String monthRef; // YYYY-MM
  final String description;
  final int categoryId;
  final double amount;
  final String type; // expense/income
  final int? cardId; // Opcional: vincula a um cartão de crédito

  ExpenseModel({
    this.id,
    required this.date,
    required this.monthRef,
    required this.description,
    required this.categoryId,
    required this.amount,
    this.type = 'expense',
    this.cardId,
  });
}

