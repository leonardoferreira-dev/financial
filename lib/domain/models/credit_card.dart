class CreditCardModel {
  final int? id;
  final String name;
  final int closingDay;
  final int dueDay;

  CreditCardModel({
    this.id,
    required this.name,
    required this.closingDay,
    required this.dueDay,
  });
}

