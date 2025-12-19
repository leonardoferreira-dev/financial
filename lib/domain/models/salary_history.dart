class SalaryHistoryModel {
  final int? id;
  final double amount;
  final String startMonth; // YYYY-MM
  final String? endMonth; // YYYY-MM ou null

  SalaryHistoryModel({
    this.id,
    required this.amount,
    required this.startMonth,
    this.endMonth,
  });

  bool coversMonth(String monthRef) {
    final startParts = startMonth.split('-');
    final monthParts = monthRef.split('-');
    if (startParts.length != 2 || monthParts.length != 2) return false;
    
    final startDate = DateTime(int.parse(startParts[0]), int.parse(startParts[1]));
    final monthDate = DateTime(int.parse(monthParts[0]), int.parse(monthParts[1]));
    
    if (endMonth == null) {
      return !monthDate.isBefore(startDate);
    }
    
    final endParts = endMonth!.split('-');
    if (endParts.length != 2) return false;
    final endDate = DateTime(int.parse(endParts[0]), int.parse(endParts[1]));
    
    return !monthDate.isBefore(startDate) && !monthDate.isAfter(endDate);
  }
}

