import 'package:drift/drift.dart';
import '../db/app_database.dart';
import '../../domain/models/credit_card.dart';

class CreditCardRepository {
  final AppDatabase _db;

  CreditCardRepository(this._db);

  Future<List<CreditCardModel>> getAll() async {
    final results = await _db.select(_db.creditCards).get();
    return results.map((row) => CreditCardModel(
          id: row.id,
          name: row.name,
          closingDay: row.closingDay,
          dueDay: row.dueDay,
        )).toList();
  }

  Future<CreditCardModel?> getById(int id) async {
    final result = await (_db.select(_db.creditCards)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    if (result == null) return null;
    
    return CreditCardModel(
      id: result.id,
      name: result.name,
      closingDay: result.closingDay,
      dueDay: result.dueDay,
    );
  }

  Future<int> insert(CreditCardModel card) async {
    return await _db.into(_db.creditCards).insert(
          CreditCardsCompanion.insert(
            name: card.name,
            closingDay: card.closingDay,
            dueDay: card.dueDay,
          ),
        );
  }

  Future<bool> update(CreditCardModel card) async {
    if (card.id == null) return false;
    
    final result = await (_db.update(_db.creditCards)..where((c) => c.id.equals(card.id!)))
        .write(
          CreditCardsCompanion(
            name: Value(card.name),
            closingDay: Value(card.closingDay),
            dueDay: Value(card.dueDay),
          ),
        );
    return result > 0;
  }

  Future<bool> delete(int id) async {
    final result = await (_db.delete(_db.creditCards)..where((c) => c.id.equals(id))).go();
    return result > 0;
  }
}

