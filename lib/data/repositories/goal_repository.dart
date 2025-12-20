import 'package:drift/drift.dart';
import '../db/app_database.dart';
import '../../domain/models/goal.dart';

class GoalRepository {
  final AppDatabase _db;

  GoalRepository(this._db);

  Future<List<GoalModel>> getAll() async {
    final goals = await (_db.select(_db.goals)
          ..orderBy([
            (g) => OrderingTerm(expression: g.minTargetMonth, mode: OrderingMode.asc),
            (g) => OrderingTerm(expression: g.id),
          ]))
        .get();
    return goals.map((g) => _toModel(g)).toList();
  }

  Future<List<GoalModel>> getActive() async {
    final goals = await (_db.select(_db.goals)
          ..where((g) => g.status.equals('active'))
          ..orderBy([
            (g) => OrderingTerm(expression: g.minTargetMonth, mode: OrderingMode.asc),
            (g) => OrderingTerm(expression: g.id),
          ]))
        .get();
    return goals.map((g) => _toModel(g)).toList();
  }

  Future<GoalModel?> getById(int id) async {
    final goal = await (_db.select(_db.goals)
          ..where((g) => g.id.equals(id)))
        .getSingleOrNull();
    return goal != null ? _toModel(goal) : null;
  }

  Future<int> insert(GoalModel goal) async {
    return await _db.into(_db.goals).insert(
          GoalsCompanion.insert(
            description: goal.description,
            minAmount: goal.minAmount,
            maxAmount: goal.maxAmount,
            minTargetMonth: Value(goal.minTargetMonth),
            maxTargetMonth: Value(goal.maxTargetMonth),
            status: Value(goal.status),
            notes: Value(goal.notes),
          ),
        );
  }

  Future<bool> update(GoalModel goal) async {
    if (goal.id == null) return false;
    final result = await (_db.update(_db.goals)..where((g) => g.id.equals(goal.id!)))
        .write(
          GoalsCompanion(
            description: Value(goal.description),
            minAmount: Value(goal.minAmount),
            maxAmount: Value(goal.maxAmount),
            minTargetMonth: Value(goal.minTargetMonth),
            maxTargetMonth: Value(goal.maxTargetMonth),
            status: Value(goal.status),
            notes: Value(goal.notes),
          ),
        );
    return result > 0;
  }

  Future<bool> delete(int id) async {
    final result = await (_db.delete(_db.goals)..where((g) => g.id.equals(id))).go();
    return result > 0;
  }

  GoalModel _toModel(Goal goal) {
    return GoalModel(
      id: goal.id,
      description: goal.description,
      minAmount: goal.minAmount,
      maxAmount: goal.maxAmount,
      minTargetMonth: goal.minTargetMonth,
      maxTargetMonth: goal.maxTargetMonth,
      status: goal.status,
      notes: goal.notes,
    );
  }
}

