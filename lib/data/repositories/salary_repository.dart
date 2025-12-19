import 'package:drift/drift.dart';
import '../db/app_database.dart';
import '../../domain/models/salary_history.dart';

class SalaryRepository {
  final AppDatabase _db;

  SalaryRepository(this._db);

  Future<List<SalaryHistoryModel>> getAll() async {
    final query = _db.select(_db.salaryHistory)
      ..orderBy([(s) => OrderingTerm.desc(s.startMonth)]);
    final results = await query.get();
    return results.map((row) => SalaryHistoryModel(
          id: row.id,
          amount: row.amount,
          startMonth: row.startMonth,
          endMonth: row.endMonth,
        )).toList();
  }

  Future<SalaryHistoryModel?> getForMonth(String monthRef) async {
    final query = _db.select(_db.salaryHistory)
      ..where((s) => s.startMonth.isSmallerOrEqualValue(monthRef))
      ..orderBy([(s) => OrderingTerm.desc(s.startMonth)])
      ..limit(1);
    
    final results = await query.get();
    if (results.isEmpty) return null;
    
    final result = results.first;
    
    // Verifica se o mês está dentro do período válido
    if (result.endMonth != null) {
      final endParts = result.endMonth!.split('-');
      final monthParts = monthRef.split('-');
      if (endParts.length == 2 && monthParts.length == 2) {
        final endDate = DateTime(int.parse(endParts[0]), int.parse(endParts[1]));
        final monthDate = DateTime(int.parse(monthParts[0]), int.parse(monthParts[1]));
        if (monthDate.isAfter(endDate)) {
          return null;
        }
      }
    }
    
    return SalaryHistoryModel(
      id: result.id,
      amount: result.amount,
      startMonth: result.startMonth,
      endMonth: result.endMonth,
    );
  }

  Future<int> insert(SalaryHistoryModel salary) async {
    // Ao inserir um novo salário, fechar o período do salário anterior
    final currentActive = _db.select(_db.salaryHistory)
      ..where((s) => s.endMonth.isNull())
      ..limit(1);
    
    final activeResults = await currentActive.get();
    if (activeResults.isNotEmpty) {
      final active = activeResults.first;
      final activeParts = active.startMonth.split('-');
      final salaryParts = salary.startMonth.split('-');
      if (activeParts.length == 2 && salaryParts.length == 2) {
        final activeDate = DateTime(int.parse(activeParts[0]), int.parse(activeParts[1]));
        final salaryDate = DateTime(int.parse(salaryParts[0]), int.parse(salaryParts[1]));
        if (salaryDate.isAfter(activeDate)) {
          await (_db.update(_db.salaryHistory)..where((s) => s.id.equals(active.id)))
              .write(SalaryHistoryCompanion(endMonth: Value(salary.startMonth)));
        }
      }
    }

    return await _db.into(_db.salaryHistory).insert(
          SalaryHistoryCompanion.insert(
            amount: salary.amount,
            startMonth: salary.startMonth,
            endMonth: Value(salary.endMonth),
          ),
        );
  }

  Future<bool> update(SalaryHistoryModel salary) async {
    if (salary.id == null) return false;
    
    final result = await (_db.update(_db.salaryHistory)..where((s) => s.id.equals(salary.id!)))
        .write(
          SalaryHistoryCompanion(
            amount: Value(salary.amount),
            startMonth: Value(salary.startMonth),
            endMonth: Value(salary.endMonth),
          ),
        );
    return result > 0;
  }

  Future<bool> delete(int id) async {
    final result = await (_db.delete(_db.salaryHistory)..where((s) => s.id.equals(id))).go();
    return result > 0;
  }
}

