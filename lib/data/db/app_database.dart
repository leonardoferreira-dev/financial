import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// Tabela de histórico de salários
class SalaryHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get startMonth => text()(); // YYYY-MM
  TextColumn get endMonth => text().nullable()(); // YYYY-MM ou null
}

// Tabela de categorias
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()(); // Para cores personalizadas
}

// Tabela de gastos
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get monthRef => text()(); // YYYY-MM
  TextColumn get description => text()();
  IntColumn get categoryId => integer()();
  RealColumn get amount => real()();
  TextColumn get type => text().withDefault(const Constant('expense'))(); // expense/income
  IntColumn get cardId => integer().nullable()(); // Opcional: vincula a um cartão de crédito
}

// Tabela de cartões de crédito
class CreditCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get closingDay => integer()();
  IntColumn get dueDay => integer()();
}

// Tabela de faturas de cartão
class CardInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardId => integer()();
  TextColumn get monthRef => text()(); // YYYY-MM
  RealColumn get amount => real()();
  TextColumn get status => text().withDefault(const Constant('open'))(); // open/paid
  TextColumn get notes => text().nullable()();
}

// Tabela de perfil do usuário (sempre terá apenas um registro)
class UserProfile extends Table {
  IntColumn get id => integer()(); // Sempre será 1
  TextColumn get name => text()();
  IntColumn get age => integer().nullable()();
  TextColumn get email => text().nullable()();
  RealColumn get initialBalance => real().withDefault(const Constant(0.0))(); // Saldo inicial
}

// Tabela de gastos fixos/recorrentes
class RecurringExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text()();
  IntColumn get categoryId => integer()();
  RealColumn get amount => real()();
  TextColumn get startMonth => text()(); // YYYY-MM - mês de início
  TextColumn get endMonth => text().nullable()(); // YYYY-MM ou null - mês de fim (null = ativo indefinidamente)
  BoolColumn get isActive => boolean().withDefault(const Constant(true))(); // Para desativar sem deletar
  IntColumn get cardId => integer().nullable()(); // Opcional: vincula a um cartão de crédito
}

@DriftDatabase(tables: [
  SalaryHistory,
  Categories,
  Expenses,
  CreditCards,
  CardInvoices,
  UserProfile,
  RecurringExpenses,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Inserir categorias padrão
        await _insertDefaultCategories();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Adicionar coluna cardId na tabela expenses
          await m.addColumn(expenses, expenses.cardId);
        }
        if (from < 3) {
          // Criar tabela de perfil do usuário
          await m.createTable(userProfile);
          // Inserir registro padrão
          await into(userProfile).insert(
            UserProfileCompanion.insert(
              id: 1,
              name: 'Usuário',
              age: const Value.absent(),
              email: const Value.absent(),
              initialBalance: const Value(0.0),
            ),
          );
        }
        if (from < 4) {
          // Criar tabela de gastos fixos/recorrentes
          await m.createTable(recurringExpenses);
        }
      },
    );
  }

  Future<void> _insertDefaultCategories() async {
    final defaultCategories = [
      'Mercado',
      'Transporte',
      'Casa',
      'Saúde',
      'Lazer',
      'Assinaturas',
      'Outros',
    ];

    for (final categoryName in defaultCategories) {
      await into(categories).insert(
        CategoriesCompanion.insert(name: categoryName),
      );
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'financial_lf.db'));
    return NativeDatabase(file);
  });
}

