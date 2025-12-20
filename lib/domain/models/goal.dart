class GoalModel {
  final int? id;
  final String description;
  final double minAmount;
  final double maxAmount;
  final String? minTargetMonth; // YYYY-MM - quando alcançará o valor mínimo
  final String? maxTargetMonth; // YYYY-MM - quando alcançará o valor máximo
  final String status; // active/completed/cancelled
  final String? notes;

  GoalModel({
    this.id,
    required this.description,
    required this.minAmount,
    required this.maxAmount,
    this.minTargetMonth,
    this.maxTargetMonth,
    this.status = 'active',
    this.notes,
  });

  GoalModel copyWith({
    int? id,
    String? description,
    double? minAmount,
    double? maxAmount,
    String? minTargetMonth,
    String? maxTargetMonth,
    String? status,
    String? notes,
  }) {
    return GoalModel(
      id: id ?? this.id,
      description: description ?? this.description,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      minTargetMonth: minTargetMonth ?? this.minTargetMonth,
      maxTargetMonth: maxTargetMonth ?? this.maxTargetMonth,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}

