import 'package:drift/drift.dart';
import '../db/app_database.dart';
import '../../domain/models/category.dart';

class CategoryRepository {
  final AppDatabase _db;

  CategoryRepository(this._db);

  Future<List<CategoryModel>> getAll() async {
    final results = await _db.select(_db.categories).get();
    return results.map((row) => CategoryModel(
          id: row.id,
          name: row.name,
          color: row.color,
        )).toList();
  }

  Future<CategoryModel?> getById(int id) async {
    final result = await (_db.select(_db.categories)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    if (result == null) return null;
    
    return CategoryModel(
      id: result.id,
      name: result.name,
      color: result.color,
    );
  }

  Future<int> insert(CategoryModel category) async {
    return await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            name: category.name,
            color: Value(category.color),
          ),
        );
  }

  Future<bool> update(CategoryModel category) async {
    if (category.id == null) return false;
    
    final result = await (_db.update(_db.categories)..where((c) => c.id.equals(category.id!)))
        .write(
          CategoriesCompanion(
            name: Value(category.name),
            color: Value(category.color),
          ),
        );
    return result > 0;
  }

  Future<bool> delete(int id) async {
    final result = await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
    return result > 0;
  }
}

