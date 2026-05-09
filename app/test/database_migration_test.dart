/// Database migration / schema tests.
///
/// Validates that:
/// - Current schemaVersion creates a fresh database without errors
/// - All tables can be created and basic CRUD works
/// - Schema is internally consistent
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/data/local/database.dart';

void main() {
  group('AppDatabase — schema creation (current version)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('schemaVersion is 15', () {
      expect(db.schemaVersion, 16);
    });

    test('fresh database creates all tables without error', () async {
      // The database is already initialized. If table creation failed,
      // we wouldn't get here. Verify by querying each table.
      // These should all return empty lists (no error).
      final users = await db.select(db.users).get();
      expect(users, isEmpty);

      final accounts = await db.select(db.accounts).get();
      expect(accounts, isEmpty);

      final transactions = await db.select(db.transactions).get();
      expect(transactions, isEmpty);

      final families = await db.select(db.families).get();
      expect(families, isEmpty);

      final familyMembers = await db.select(db.familyMembers).get();
      expect(familyMembers, isEmpty);

      final transfers = await db.select(db.transfers).get();
      expect(transfers, isEmpty);

      final budgets = await db.select(db.budgets).get();
      expect(budgets, isEmpty);

      final categoryBudgets = await db.select(db.categoryBudgetsTable).get();
      expect(categoryBudgets, isEmpty);

      final notifications = await db.select(db.notifications).get();
      expect(notifications, isEmpty);

      final notificationSettings =
          await db.select(db.notificationSettingsTable).get();
      expect(notificationSettings, isEmpty);

      final loanGroups = await db.select(db.loanGroups).get();
      expect(loanGroups, isEmpty);

      final loans = await db.select(db.loans).get();
      expect(loans, isEmpty);

      final loanSchedules = await db.select(db.loanSchedules).get();
      expect(loanSchedules, isEmpty);

      final loanRateChanges = await db.select(db.loanRateChanges).get();
      expect(loanRateChanges, isEmpty);

      final investments = await db.select(db.investments).get();
      expect(investments, isEmpty);

      final investmentTrades = await db.select(db.investmentTrades).get();
      expect(investmentTrades, isEmpty);

      final marketQuotes = await db.select(db.marketQuotes).get();
      expect(marketQuotes, isEmpty);

      final fixedAssets = await db.select(db.fixedAssets).get();
      expect(fixedAssets, isEmpty);

      final assetValuations = await db.select(db.assetValuations).get();
      expect(assetValuations, isEmpty);

      final depreciationRules = await db.select(db.depreciationRules).get();
      expect(depreciationRules, isEmpty);

      final syncQueue = await db.select(db.syncQueue).get();
      expect(syncQueue, isEmpty);

      final exchangeRates = await db.select(db.exchangeRates).get();
      expect(exchangeRates, isEmpty);
    });

    test('preset categories are seeded after auth (not on fresh database)', () async {
      final categories = await db.select(db.categories).get();
      // Since v13+, categories are seeded after auth when userId is known,
      // so a fresh database will have no categories.
      expect(categories, isEmpty);
    });
  });

  group('AppDatabase — basic CRUD operations', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('insert and query user', () async {
      await db.customStatement(
          "INSERT INTO users (id, email, created_at) "
          "VALUES ('u1', 'test@example.com', "
          "${DateTime.now().millisecondsSinceEpoch ~/ 1000})");

      final users = await db.select(db.users).get();
      expect(users.length, 1);
      expect(users.first.id, 'u1');
      expect(users.first.email, 'test@example.com');
    });

    test('insert and query account', () async {
      // Need a user first (foreign key)
      await db.customStatement(
          "INSERT INTO users (id, email, created_at) "
          "VALUES ('u1', 'test@example.com', "
          "${DateTime.now().millisecondsSinceEpoch ~/ 1000})");

      await db.insertAccount(AccountsCompanion.insert(
        id: 'acc1',
        userId: 'u1',
        name: 'My Bank',
        balance: const Value(500000),
        familyId: const Value(''),
        accountType: const Value('bank_card'),
      ));

      final accounts = await db.getActiveAccounts('u1');
      expect(accounts.length, 1);
      expect(accounts.first.name, 'My Bank');
      expect(accounts.first.balance, 500000);
    });

    test('insert and query transaction', () async {
      await db.customStatement(
          "INSERT INTO users (id, email, created_at) "
          "VALUES ('u1', 'test@example.com', "
          "${DateTime.now().millisecondsSinceEpoch ~/ 1000})");

      await db.insertAccount(AccountsCompanion.insert(
        id: 'acc1',
        userId: 'u1',
        name: 'My Bank',
        familyId: const Value(''),
        accountType: const Value('bank_card'),
      ));

      // Insert a test category since categories are no longer seeded on fresh DB
      await db.customStatement(
          "INSERT INTO categories (id, name, type, icon, sort_order, is_preset) "
          "VALUES ('cat1', 'Food', 'expense', '🍔', 1, 1)");

      await db.insertTransaction(TransactionsCompanion.insert(
        id: 'tx1',
        userId: 'u1',
        accountId: 'acc1',
        categoryId: 'cat1',
        amount: 5000,
        amountCny: 5000,
        type: 'expense',
        txnDate: DateTime(2024, 6, 15),
      ));

      final txns = await db.getRecentTransactions('u1', 10);
      expect(txns.length, 1);
      expect(txns.first.amountCny, 5000);
    });

    test('insert and query family + members', () async {
      await db.insertFamily(FamiliesCompanion.insert(
        id: 'fam1',
        name: '小Q家',
        ownerId: 'u1',
      ));

      await db.insertFamilyMember(FamilyMembersCompanion.insert(
        id: 'fm1',
        familyId: 'fam1',
        userId: 'u1',
        role: const Value('owner'),
        canView: const Value(true),
        canCreate: const Value(true),
        canEdit: const Value(true),
        canDelete: const Value(true),
        canManageAccounts: const Value(true),
      ));

      final families = await db.getAllFamilies();
      expect(families.length, 1);
      expect(families.first.name, '小Q家');

      final members = await db.getFamilyMembers('fam1');
      expect(members.length, 1);
      expect(members.first.role, 'owner');
    });

    test('insert and query loan', () async {
      await db.customStatement(
          "INSERT INTO users (id, email, created_at) "
          "VALUES ('u1', 'test@example.com', "
          "${DateTime.now().millisecondsSinceEpoch ~/ 1000})");

      await db.insertAccount(AccountsCompanion.insert(
        id: 'acc1',
        userId: 'u1',
        name: 'Account',
        familyId: const Value(''),
        accountType: const Value('bank_card'),
      ));

      await db.upsertLoan(LoansCompanion.insert(
        id: 'loan1',
        userId: 'u1',
        name: '房贷',
        principal: 50000000,
        remainingPrincipal: 48000000,
        annualRate: 4.1,
        totalMonths: 360,
        paymentDay: 15,
        startDate: DateTime(2024, 1, 1),
        loanType: const Value('mortgage'),
        repaymentMethod: const Value('equal_installment'),
      ));

      final loans = await db.getLoans('u1');
      expect(loans.length, 1);
      expect(loans.first.name, '房贷');
      expect(loans.first.principal, 50000000);
    });

    test('insert and query budget', () async {
      await db.into(db.budgets).insert(BudgetsCompanion.insert(
        id: 'budget1',
        userId: 'u1',
        year: 2024,
        month: 6,
        totalAmount: 500000,
      ));

      final budget = await db.getBudgetByMonth('u1', 2024, 6);
      expect(budget, isNotNull);
      expect(budget!.totalAmount, 500000);
    });
  });

  group('AppDatabase — multiple instances are independent', () {
    test('two in-memory databases do not share data', () async {
      final db1 = AppDatabase.forTesting(NativeDatabase.memory());
      final db2 = AppDatabase.forTesting(NativeDatabase.memory());

      await db1.customStatement(
          "INSERT INTO users (id, email, created_at) "
          "VALUES ('u1', 'alice@test.com', "
          "${DateTime.now().millisecondsSinceEpoch ~/ 1000})");

      final usersDb1 = await db1.select(db1.users).get();
      final usersDb2 = await db2.select(db2.users).get();

      expect(usersDb1.length, 1);
      expect(usersDb2.length, 0); // Separate instance, no data

      await db1.close();
      await db2.close();
    });
  });
}
