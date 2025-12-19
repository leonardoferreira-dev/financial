class UserProfileModel {
  final int id;
  final String name;
  final int? age;
  final String? email;
  final double initialBalance;

  UserProfileModel({
    required this.id,
    required this.name,
    this.age,
    this.email,
    required this.initialBalance,
  });
}

