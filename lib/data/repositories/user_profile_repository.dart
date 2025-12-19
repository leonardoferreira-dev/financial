import 'package:drift/drift.dart';
import '../db/app_database.dart';
import '../../domain/models/user_profile.dart';

class UserProfileRepository {
  final AppDatabase _db;

  UserProfileRepository(this._db);

  Future<UserProfileModel?> get() async {
    final result = await (_db.select(_db.userProfile)..where((p) => p.id.equals(1))).getSingleOrNull();
    if (result == null) return null;
    
    return UserProfileModel(
      id: result.id,
      name: result.name,
      age: result.age,
      email: result.email,
      initialBalance: result.initialBalance,
    );
  }

  Future<void> save(UserProfileModel profile) async {
    final existing = await (_db.select(_db.userProfile)..where((p) => p.id.equals(1))).getSingleOrNull();
    
    if (existing == null) {
      // Criar novo perfil
      await _db.into(_db.userProfile).insert(
        UserProfileCompanion.insert(
          id: 1,
          name: profile.name,
          age: Value(profile.age),
          email: Value(profile.email),
          initialBalance: Value(profile.initialBalance),
        ),
      );
    } else {
      // Atualizar perfil existente
      await (_db.update(_db.userProfile)..where((p) => p.id.equals(1))).write(
        UserProfileCompanion(
          name: Value(profile.name),
          age: Value(profile.age),
          email: Value(profile.email),
          initialBalance: Value(profile.initialBalance),
        ),
      );
    }
  }
}

