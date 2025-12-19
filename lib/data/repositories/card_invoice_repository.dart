import 'package:drift/drift.dart';
import '../db/app_database.dart';
import '../../domain/models/card_invoice.dart';

class CardInvoiceRepository {
  final AppDatabase _db;

  CardInvoiceRepository(this._db);

  Future<List<CardInvoiceModel>> getAll() async {
    final results = await _db.select(_db.cardInvoices).get();
    return results.map((row) => CardInvoiceModel(
          id: row.id,
          cardId: row.cardId,
          monthRef: row.monthRef,
          amount: row.amount,
          status: row.status,
          notes: row.notes,
        )).toList();
  }

  Future<List<CardInvoiceModel>> getByMonth(String monthRef) async {
    final query = _db.select(_db.cardInvoices)
      ..where((i) => i.monthRef.equals(monthRef))
      ..orderBy([(i) => OrderingTerm.asc(i.cardId)]);
    
    final results = await query.get();
    return results.map((row) => CardInvoiceModel(
          id: row.id,
          cardId: row.cardId,
          monthRef: row.monthRef,
          amount: row.amount,
          status: row.status,
          notes: row.notes,
        )).toList();
  }

  Future<List<CardInvoiceModel>> getByCard(int cardId) async {
    final query = _db.select(_db.cardInvoices)
      ..where((i) => i.cardId.equals(cardId))
      ..orderBy([(i) => OrderingTerm.desc(i.monthRef)]);
    
    final results = await query.get();
    return results.map((row) => CardInvoiceModel(
          id: row.id,
          cardId: row.cardId,
          monthRef: row.monthRef,
          amount: row.amount,
          status: row.status,
          notes: row.notes,
        )).toList();
  }

  Future<double> getTotalByMonth(String monthRef) async {
    final query = _db.selectOnly(_db.cardInvoices)
      ..addColumns([_db.cardInvoices.amount.sum()])
      ..where(_db.cardInvoices.monthRef.equals(monthRef))
      ..where(_db.cardInvoices.status.equals('open'));
    
    final result = await query.getSingle();
    return result.read(_db.cardInvoices.amount.sum()) ?? 0.0;
  }

  Future<int> insert(CardInvoiceModel invoice) async {
    return await _db.into(_db.cardInvoices).insert(
          CardInvoicesCompanion.insert(
            cardId: invoice.cardId,
            monthRef: invoice.monthRef,
            amount: invoice.amount,
            status: Value(invoice.status),
            notes: Value(invoice.notes),
          ),
        );
  }

  Future<bool> update(CardInvoiceModel invoice) async {
    if (invoice.id == null) return false;
    
    final result = await (_db.update(_db.cardInvoices)..where((i) => i.id.equals(invoice.id!)))
        .write(
          CardInvoicesCompanion(
            cardId: Value(invoice.cardId),
            monthRef: Value(invoice.monthRef),
            amount: Value(invoice.amount),
            status: Value(invoice.status),
            notes: Value(invoice.notes),
          ),
        );
    return result > 0;
  }

  Future<bool> delete(int id) async {
    final result = await (_db.delete(_db.cardInvoices)..where((i) => i.id.equals(id))).go();
    return result > 0;
  }
}

