/// P2-A: verifies CRUD providers run pure-local when the gRPC client is null
/// (local-only / Android build, `syncEnabled == false`). The `_require*()`
/// helpers throw `GrpcError.unavailable` fast, which each method's existing
/// offline `catch` turns into a local Drift write — no network, no timeout.
library;

import 'package:drift/native.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/providers/loan_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.users)
        .insert(UsersCompanion.insert(id: 'u1', email: 'u1@e.com'));
  });
  tearDown(() async => db.close());

  test('createLoan persists locally when client is null (local-only build)',
      () async {
    // Null client == local-only build (syncEnabled false).
    final notifier = LoanNotifier(db, null, 'u1', null);

    await notifier.createLoan(
      name: '房贷',
      loanType: 'mortgage',
      principal: 1200000,
      annualRate: 0.04,
      totalMonths: 12,
      repaymentMethod: 'equal_installment',
      paymentDay: 10,
      startDate: DateTime(2026, 1, 1),
    );

    // Loan was written to the local DB despite having no gRPC client.
    final loans = await db.getStandaloneLoans('u1');
    expect(loans, hasLength(1));
    expect(loans.single.name, '房贷');
    expect(loans.single.principal, 1200000);

    // A local schedule was generated too.
    final schedules = await db.getLoanSchedules(loans.single.id);
    expect(schedules, isNotEmpty);
  });
}
