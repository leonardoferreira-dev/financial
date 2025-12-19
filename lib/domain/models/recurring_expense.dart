class RecurringExpenseModel {
  final int? id;
  final String description;
  final int categoryId;
  final double amount;
  final String startMonth; // YYYY-MM
  final String? endMonth; // YYYY-MM ou null
  final bool isActive;
  final int? cardId; // Opcional: vincula a um cartão de crédito

  RecurringExpenseModel({
    this.id,
    required this.description,
    required this.categoryId,
    required this.amount,
    required this.startMonth,
    this.endMonth,
    this.isActive = true,
    this.cardId,
  });

  // Verifica se o gasto fixo deve ser aplicado em um mês específico
  bool appliesToMonth(String monthRef) {
    if (!isActive) return false;
    
    // Verifica se o mês está dentro do período válido
    if (monthRef.compareTo(startMonth) < 0) return false;
    
    final endMonthValue = endMonth;
    if (endMonthValue != null && monthRef.compareTo(endMonthValue) > 0) return false;
    
    return true;
  }
}

