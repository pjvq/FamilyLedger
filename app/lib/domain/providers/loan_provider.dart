import 'dart:developer' as developer;
import 'package:grpc/grpc.dart' show CallOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fixnum/fixnum.dart';
import 'package:drift/drift.dart' show Value;
import '../../data/local/database.dart' as db;
import '../../data/remote/grpc_clients.dart';
import '../../generated/proto/loan.pb.dart' as pb;
import '../../generated/proto/loan.pbgrpc.dart';
import '../../generated/proto/loan.pbenum.dart' as pb_enum;
import '../../generated/proto/google/protobuf/timestamp.pb.dart' as ts_pb;
import 'app_providers.dart';
import '../models/loan_models.dart';
import '../models/loan_calculator.dart';
import '../models/loan_proto_helpers.dart';

export '../models/loan_models.dart';
export '../models/loan_calculator.dart';

class LoanNotifier extends StateNotifier<LoanState> {
  final db.AppDatabase _db;
  final LoanServiceClient _client;
  final String? _userId;
  final String? _familyId;

  LoanNotifier(this._db, this._client, this._userId, this._familyId)
      : super(const LoanState()) {
    developer.log('[Loan] LoanNotifier created: userId=$_userId, familyId=$_familyId', name: 'LoanProvider');
    if (_userId != null) {
      loadAll();
    }
  }

  /// Load both standalone loans and loan groups
  Future<void> loadAll() async {
    await Future.wait([listLoans(), listLoanGroups()]);
  }

  Future<void> listLoans() async {
    if (_userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    developer.log('[Loan] listLoans: userId=$_userId familyId=$_familyId', name: 'LoanProvider');

    try {
      // gRPC first
      final req = pb.ListLoansRequest();
      if (_familyId != null && _familyId.isNotEmpty) {
        req.familyId = _familyId;
      }
      final resp = await _client.listLoans(req,
          options: CallOptions(timeout: const Duration(seconds: 10)));
      developer.log('[Loan] listLoans: gRPC returned ${resp.loans.length} loans', name: 'LoanProvider');
      for (final loan in resp.loans) {
        await _db.upsertLoan(_loanFromProto(loan));
      }
    } catch (e) {
      // Offline fallback — use local DB
    }

    try {
      final loans = await _db.getStandaloneLoans(_userId, familyId: _familyId);
      developer.log('[Loan] listLoans: local DB returned ${loans.length} standalone loans (userId=$_userId, familyId=$_familyId)', name: 'LoanProvider');
      state = state.copyWith(loans: loans, isLoading: false);
    } catch (e) {
      developer.log('[Loan] listLoans: local DB error: $e', name: 'LoanProvider');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> listLoanGroups() async {
    if (_userId == null) return;

    developer.log('[Loan] listLoanGroups: userId=$_userId familyId=$_familyId', name: 'LoanProvider');

    try {
      final grpReq = pb.ListLoanGroupsRequest();
      if (_familyId != null && _familyId.isNotEmpty) {
        grpReq.familyId = _familyId;
      }
      final resp = await _client.listLoanGroups(grpReq,
          options: CallOptions(timeout: const Duration(seconds: 10)));
      developer.log('[Loan] listLoanGroups: gRPC returned ${resp.groups.length} groups', name: 'LoanProvider');
      for (final group in resp.groups) {
        developer.log('[Loan] listLoanGroups: upserting group id=${group.id} name=${group.name} familyId="${group.familyId}" userId=${group.userId}', name: 'LoanProvider');
        await _db.upsertLoanGroup(db.LoanGroupsCompanion.insert(
          id: group.id,
          userId: group.userId,
          familyId: Value(group.familyId),
          name: group.name,
          groupType: group.groupType,
          totalPrincipal: group.totalPrincipal.toInt(),
          paymentDay: group.paymentDay,
          startDate: fromTimestamp(group.startDate),
          accountId: Value(group.accountId),
        ));
        for (final loan in group.subLoans) {
          await _db.upsertLoan(_loanFromProto(loan));
        }
      }
    } catch (e) {
      developer.log('[Loan] listLoanGroups: gRPC error: $e', name: 'LoanProvider');
      // Offline fallback
    }

    try {
      final groups = await _db.getLoanGroups(_userId, familyId: _familyId);
      developer.log('[Loan] listLoanGroups: local DB returned ${groups.length} groups (query: userId=$_userId, familyId=$_familyId)', name: 'LoanProvider');
      for (final g in groups) {
        developer.log('[Loan] listLoanGroups: local group id=${g.id} name=${g.name} familyId="${g.familyId}"', name: 'LoanProvider');
      }
      final displayGroups = <LoanGroupDisplayItem>[];
      for (final group in groups) {
        final subLoans = await _db.getLoansByGroupId(group.id);
        displayGroups.add(_buildGroupDisplay(group, subLoans));
      }
      state = state.copyWith(loanGroups: displayGroups);
    } catch (e) {
      developer.log('[Loan] listLoanGroups: local DB error: $e', name: 'LoanProvider');
      // ignore
    }
  }

  db.LoansCompanion _loanFromProto(pb.Loan loan) {
    return db.LoansCompanion.insert(
      id: loan.id,
      userId: loan.userId,
      familyId: Value(loan.familyId),
      name: loan.name,
      principal: loan.principal.toInt(),
      remainingPrincipal: loan.remainingPrincipal.toInt(),
      annualRate: loan.annualRate,
      totalMonths: loan.totalMonths,
      paymentDay: loan.paymentDay,
      startDate: fromTimestamp(loan.startDate),
      loanType: Value(loanTypeToString(loan.loanType)),
      paidMonths: Value(loan.paidMonths),
      repaymentMethod: Value(repaymentMethodToString(loan.repaymentMethod)),
      accountId: Value(loan.accountId),
      groupId: Value(loan.groupId),
      subType: Value(subTypeToString(loan.subType)),
      rateType: Value(rateTypeToString(loan.rateType)),
      lprBase: Value(loan.lprBase),
      lprSpread: Value(loan.lprSpread),
      rateAdjustMonth: Value(loan.rateAdjustMonth),
      repaymentCategoryId: Value(loan.repaymentCategoryId),
    );
  }

  LoanGroupDisplayItem _buildGroupDisplay(
      db.LoanGroup group, List<db.Loan> subLoans) {
    int totalMonthly = 0;
    int totalRemaining = 0;
    double totalProgress = 0;
    int totalMonthsSum = 0;

    for (final loan in subLoans) {
      totalMonthly += getMonthlyPayment(loan);
      totalRemaining += loan.remainingPrincipal;
      totalProgress += loan.paidMonths;
      totalMonthsSum += loan.totalMonths;
    }

    final overallProgress =
        totalMonthsSum > 0 ? totalProgress / totalMonthsSum : 0.0;

    return LoanGroupDisplayItem(
      group: group,
      subLoans: subLoans,
      totalMonthlyPayment: totalMonthly,
      totalRemainingPrincipal: totalRemaining,
      overallProgress: overallProgress,
    );
  }

  Future<void> createLoan({
    required String name,
    required String loanType,
    required int principal,
    required double annualRate,
    required int totalMonths,
    required String repaymentMethod,
    required int paymentDay,
    required DateTime startDate,
    String? accountId,
    String? rateType,
    double? lprBase,
    double? lprSpread,
    int? rateAdjustMonth,
    String? familyId,
    String? interestCalcMethod,
  }) async {
    if (_userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    developer.log('[Loan] createLoan: name=$name familyId=$familyId userId=$_userId', name: 'LoanProvider');

    String loanId = const Uuid().v4();

    try {
      final resp = await _client.createLoan(pb.CreateLoanRequest()
        ..name = name
        ..loanType = stringToLoanType(loanType)
        ..principal = Int64(principal)
        ..annualRate = annualRate
        ..totalMonths = totalMonths
        ..repaymentMethod = stringToRepaymentMethod(repaymentMethod)
        ..paymentDay = paymentDay
        ..startDate = toTimestamp(startDate)
        ..accountId = accountId ?? ''
        ..familyId = familyId ?? ''
        ..interestCalcMethod = stringToInterestCalcMethod(interestCalcMethod ?? 'monthly'));
      loanId = resp.id;
      await _db.upsertLoan(_loanFromProto(resp));
    } catch (e, st) {
      // Offline: save locally
      await _db.upsertLoan(db.LoansCompanion.insert(
        id: loanId,
        userId: _userId,
        familyId: Value(familyId ?? ''),
        name: name,
        principal: principal,
        remainingPrincipal: principal,
        annualRate: annualRate,
        totalMonths: totalMonths,
        paymentDay: paymentDay,
        startDate: startDate,
        loanType: Value(loanType),
        repaymentMethod: Value(repaymentMethod),
        accountId: Value(accountId ?? ''),
        rateType: Value(rateType ?? 'fixed'),
        lprBase: Value(lprBase ?? 0.0),
        lprSpread: Value(lprSpread ?? 0.0),
        rateAdjustMonth: Value(rateAdjustMonth ?? 1),
      ));
    }

    // Generate local schedule
    final schedule = LoanCalculator.calculate(
      principal: principal,
      annualRate: annualRate,
      totalMonths: totalMonths,
      repaymentMethod: repaymentMethod,
      startDate: startDate,
      paymentDay: paymentDay,
    );

    await _db.deleteLoanSchedules(loanId);
    for (final item in schedule) {
      await _db.insertLoanSchedule(db.LoanSchedulesCompanion.insert(
        id: const Uuid().v4(),
        loanId: loanId,
        monthNumber: item.monthNumber,
        payment: item.payment,
        principalPart: item.principalPart,
        interestPart: item.interestPart,
        remainingPrincipal: item.remainingPrincipal,
        dueDate: item.dueDate,
      ));
    }

    await loadAll();
  }

  /// Create a loan group (combined / commercial_only / provident_only)
  Future<void> createLoanGroup({
    required String name,
    required String groupType,
    required String loanType,
    required int paymentDay,
    required DateTime startDate,
    required List<SubLoanInput> subLoans,
    String? accountId,
    String? familyId,
  }) async {
    if (_userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);

    final groupId = const Uuid().v4();
    final totalPrincipal =
        subLoans.fold<int>(0, (sum, l) => sum + l.principal);

    try {
      // Try gRPC
      final req = pb.CreateLoanGroupRequest()
        ..name = name
        ..groupType = groupType
        ..paymentDay = paymentDay
        ..startDate = toTimestamp(startDate)
        ..accountId = accountId ?? ''
        ..loanType = stringToLoanType(loanType)
        ..familyId = familyId ?? '';

      for (final sub in subLoans) {
        req.subLoans.add(pb.SubLoanSpec()
          ..name = sub.name
          ..subType = stringToSubType(sub.subType)
          ..principal = Int64(sub.principal)
          ..annualRate = sub.annualRate
          ..totalMonths = sub.totalMonths
          ..repaymentMethod = stringToRepaymentMethod(sub.repaymentMethod)
          ..rateType = stringToRateType(sub.rateType)
          ..lprBase = sub.lprBase
          ..lprSpread = sub.lprSpread
          ..rateAdjustMonth = sub.rateAdjustMonth
          ..interestCalcMethod = stringToInterestCalcMethod(sub.interestCalcMethod));
      }

      final resp = await _client.createLoanGroup(req);
      await _db.upsertLoanGroup(db.LoanGroupsCompanion.insert(
        id: resp.id,
        userId: resp.userId,
        name: resp.name,
        groupType: resp.groupType,
        totalPrincipal: resp.totalPrincipal.toInt(),
        paymentDay: resp.paymentDay,
        startDate: fromTimestamp(resp.startDate),
        accountId: Value(resp.accountId),
        familyId: Value(resp.familyId),
        loanType: Value(loanTypeToString(resp.loanType)),
      ));
      for (final loan in resp.subLoans) {
        await _db.upsertLoan(_loanFromProto(loan));
        await _generateScheduleForLoan(loan.id, loan.principal.toInt(),
            loan.annualRate, loan.totalMonths,
            repaymentMethodToString(loan.repaymentMethod),
            fromTimestamp(loan.startDate), loan.paymentDay);
      }
    } catch (_) {
      // Offline: save locally
      await _db.upsertLoanGroup(db.LoanGroupsCompanion.insert(
        id: groupId,
        userId: _userId,
        name: name,
        groupType: groupType,
        totalPrincipal: totalPrincipal,
        paymentDay: paymentDay,
        startDate: startDate,
        accountId: Value(accountId ?? ''),
        loanType: Value(loanType),
        familyId: Value(familyId ?? ''),
      ));

      for (final sub in subLoans) {
        final loanId = const Uuid().v4();
        await _db.upsertLoan(db.LoansCompanion.insert(
          id: loanId,
          userId: _userId,
          name: sub.name,
          principal: sub.principal,
          remainingPrincipal: sub.principal,
          annualRate: sub.annualRate,
          totalMonths: sub.totalMonths,
          paymentDay: paymentDay,
          startDate: startDate,
          loanType: Value(loanType),
          repaymentMethod: Value(sub.repaymentMethod),
          accountId: Value(accountId ?? ''),
          familyId: Value(familyId ?? ''),
          groupId: Value(groupId),
          subType: Value(sub.subType),
          rateType: Value(sub.rateType),
          lprBase: Value(sub.lprBase),
          lprSpread: Value(sub.lprSpread),
          rateAdjustMonth: Value(sub.rateAdjustMonth),
        ));

        await _generateScheduleForLoan(loanId, sub.principal,
            sub.annualRate, sub.totalMonths, sub.repaymentMethod,
            startDate, paymentDay);
      }
    }

    await loadAll();
  }

  Future<void> _generateScheduleForLoan(
    String loanId,
    int principal,
    double annualRate,
    int totalMonths,
    String repaymentMethod,
    DateTime startDate,
    int paymentDay,
  ) async {
    final schedule = LoanCalculator.calculate(
      principal: principal,
      annualRate: annualRate,
      totalMonths: totalMonths,
      repaymentMethod: repaymentMethod,
      startDate: startDate,
      paymentDay: paymentDay,
    );

    await _db.deleteLoanSchedules(loanId);
    for (final item in schedule) {
      await _db.insertLoanSchedule(db.LoanSchedulesCompanion.insert(
        id: const Uuid().v4(),
        loanId: loanId,
        monthNumber: item.monthNumber,
        payment: item.payment,
        principalPart: item.principalPart,
        interestPart: item.interestPart,
        remainingPrincipal: item.remainingPrincipal,
        dueDate: item.dueDate,
      ));
    }
  }

  /// Load loan group detail with sub-loans
  Future<void> getLoanGroupDetail(String groupId) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSimulation: true);

    try {
      final group = await _db.getLoanGroupById(groupId);
      if (group == null) {
        state = state.copyWith(isLoading: false, error: '贷款组不存在');
        return;
      }

      final subLoans = await _db.getLoansByGroupId(groupId);
      final displayGroup = _buildGroupDisplay(group, subLoans);

      state = state.copyWith(
        currentGroup: displayGroup,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> getLoanDetail(String loanId) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSimulation: true);

    try {
      final loan = await _db.getLoanById(loanId);
      if (loan == null) {
        state = state.copyWith(isLoading: false, error: '贷款不存在');
        return;
      }

      List<LoanScheduleDisplayItem> schedule;

      try {
        // Try gRPC
        final resp = await _client.getLoanSchedule(
          pb.GetLoanScheduleRequest()..loanId = loanId,
        );
        schedule = resp.items.map((item) => LoanScheduleDisplayItem(
          monthNumber: item.monthNumber,
          payment: item.payment.toInt(),
          principalPart: item.principalPart.toInt(),
          interestPart: item.interestPart.toInt(),
          remainingPrincipal: item.remainingPrincipal.toInt(),
          dueDate: fromTimestamp(item.dueDate),
          isPaid: item.isPaid,
          paidDate: item.hasPaidDate() ? fromTimestamp(item.paidDate) : null,
        )).toList();
      } catch (_) {
        // Local fallback
        final dbSchedules = await _db.getLoanSchedules(loanId);
        if (dbSchedules.isNotEmpty) {
          schedule = dbSchedules.map((s) => LoanScheduleDisplayItem(
            monthNumber: s.monthNumber,
            payment: s.payment,
            principalPart: s.principalPart,
            interestPart: s.interestPart,
            remainingPrincipal: s.remainingPrincipal,
            dueDate: s.dueDate,
            isPaid: s.isPaid,
            paidDate: s.paidDate,
          )).toList();
        } else {
          schedule = LoanCalculator.calculate(
            principal: loan.principal,
            annualRate: loan.annualRate,
            totalMonths: loan.totalMonths,
            repaymentMethod: loan.repaymentMethod,
            startDate: loan.startDate,
            paymentDay: loan.paymentDay,
            paidMonths: loan.paidMonths,
          );
        }
      }

      state = state.copyWith(
        currentLoan: loan,
        schedule: schedule,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Get schedule for a specific sub-loan (used in group detail tabs)
  Future<List<LoanScheduleDisplayItem>> getScheduleForLoan(String loanId) async {
    final loan = await _db.getLoanById(loanId);
    if (loan == null) return [];

    final dbSchedules = await _db.getLoanSchedules(loanId);
    if (dbSchedules.isNotEmpty) {
      return dbSchedules.map((s) => LoanScheduleDisplayItem(
        monthNumber: s.monthNumber,
        payment: s.payment,
        principalPart: s.principalPart,
        interestPart: s.interestPart,
        remainingPrincipal: s.remainingPrincipal,
        dueDate: s.dueDate,
        isPaid: s.isPaid,
        paidDate: s.paidDate,
      )).toList();
    }

    return LoanCalculator.calculate(
      principal: loan.principal,
      annualRate: loan.annualRate,
      totalMonths: loan.totalMonths,
      repaymentMethod: loan.repaymentMethod,
      startDate: loan.startDate,
      paymentDay: loan.paymentDay,
      paidMonths: loan.paidMonths,
    );
  }

  Future<void> simulatePrepayment({
    required String loanId,
    required int amount,
    required String strategy, // 'reduce_months' | 'reduce_payment'
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final loan = state.currentLoan ?? await _db.getLoanById(loanId);
    if (loan == null) {
      state = state.copyWith(isLoading: false, error: '贷款不存在');
      return;
    }

    try {
      // Try gRPC
      final pbStrategy = strategy == 'reduce_months'
          ? pb_enum.PrepaymentStrategy.PREPAYMENT_STRATEGY_REDUCE_MONTHS
          : pb_enum.PrepaymentStrategy.PREPAYMENT_STRATEGY_REDUCE_PAYMENT;

      final resp = await _client.simulatePrepayment(
        pb.SimulatePrepaymentRequest()
          ..loanId = loanId
          ..prepaymentAmount = Int64(amount)
          ..strategy = pbStrategy,
      );

      state = state.copyWith(
        simulation: PrepaymentSimulationResult(
          prepaymentAmount: resp.prepaymentAmount.toInt(),
          totalInterestBefore: resp.totalInterestBefore.toInt(),
          totalInterestAfter: resp.totalInterestAfter.toInt(),
          interestSaved: resp.interestSaved.toInt(),
          monthsReduced: resp.monthsReduced,
          newMonthlyPayment: resp.newMonthlyPayment.toInt(),
          newSchedule: resp.newSchedule.map((item) => LoanScheduleDisplayItem(
            monthNumber: item.monthNumber,
            payment: item.payment.toInt(),
            principalPart: item.principalPart.toInt(),
            interestPart: item.interestPart.toInt(),
            remainingPrincipal: item.remainingPrincipal.toInt(),
            dueDate: fromTimestamp(item.dueDate),
            isPaid: item.isPaid,
          )).toList(),
        ),
        isLoading: false,
      );
      return;
    } catch (_) {
      // Local fallback
    }

    final remainingMonths = loan.totalMonths - loan.paidMonths;
    PrepaymentSimulationResult sim;

    if (strategy == 'reduce_months') {
      sim = LoanCalculator.simulateReduceMonths(
        remainingPrincipal: loan.remainingPrincipal,
        annualRate: loan.annualRate,
        remainingMonths: remainingMonths,
        paidMonths: loan.paidMonths,
        prepaymentAmount: amount,
        repaymentMethod: loan.repaymentMethod,
        startDate: loan.startDate,
        paymentDay: loan.paymentDay,
        originalPrincipal: loan.principal,
        originalTotalMonths: loan.totalMonths,
      );
    } else {
      sim = LoanCalculator.simulateReducePayment(
        remainingPrincipal: loan.remainingPrincipal,
        annualRate: loan.annualRate,
        remainingMonths: remainingMonths,
        paidMonths: loan.paidMonths,
        prepaymentAmount: amount,
        repaymentMethod: loan.repaymentMethod,
        startDate: loan.startDate,
        paymentDay: loan.paymentDay,
        originalPrincipal: loan.principal,
        originalTotalMonths: loan.totalMonths,
      );
    }

    state = state.copyWith(simulation: sim, isLoading: false);
  }

  Future<void> recordRateChange({
    required String loanId,
    required double newRate,
    required DateTime effectiveDate,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final loan = await _db.getLoanById(loanId);
    if (loan == null) {
      state = state.copyWith(isLoading: false, error: '贷款不存在');
      return;
    }

    try {
      await _client.recordRateChange(pb.RecordRateChangeRequest()
        ..loanId = loanId
        ..newRate = newRate
        ..effectiveDate = toTimestamp(effectiveDate));
    } catch (_) {
      // Offline
    }

    // Save rate change record
    await _db.insertLoanRateChange(db.LoanRateChangesCompanion.insert(
      id: const Uuid().v4(),
      loanId: loanId,
      oldRate: loan.annualRate,
      newRate: newRate,
      effectiveDate: effectiveDate,
    ));

    // Update loan rate
    await _db.updateLoanFields(loanId, db.LoansCompanion(
      annualRate: Value(newRate),
      updatedAt: Value(DateTime.now()),
    ));

    // Regenerate schedule for remaining months
    final remainingPrincipal = loan.remainingPrincipal;
    final remainingMonths = loan.totalMonths - loan.paidMonths;
    final newSchedule = LoanCalculator.calculate(
      principal: remainingPrincipal,
      annualRate: newRate,
      totalMonths: remainingMonths,
      repaymentMethod: loan.repaymentMethod,
      startDate: LoanCalculator.calcDueDate(
          loan.startDate, loan.paidMonths, loan.paymentDay),
      paymentDay: loan.paymentDay,
    );

    final existingSchedules = await _db.getLoanSchedules(loanId);
    final paidSchedules = existingSchedules
        .where((s) => s.isPaid)
        .toList();
    await _db.deleteLoanSchedules(loanId);

    for (final s in paidSchedules) {
      await _db.insertLoanSchedule(db.LoanSchedulesCompanion.insert(
        id: s.id,
        loanId: loanId,
        monthNumber: s.monthNumber,
        payment: s.payment,
        principalPart: s.principalPart,
        interestPart: s.interestPart,
        remainingPrincipal: s.remainingPrincipal,
        dueDate: s.dueDate,
        isPaid: Value(true),
        paidDate: Value(s.paidDate),
      ));
    }

    for (final item in newSchedule) {
      await _db.insertLoanSchedule(db.LoanSchedulesCompanion.insert(
        id: const Uuid().v4(),
        loanId: loanId,
        monthNumber: loan.paidMonths + item.monthNumber,
        payment: item.payment,
        principalPart: item.principalPart,
        interestPart: item.interestPart,
        remainingPrincipal: item.remainingPrincipal,
        dueDate: item.dueDate,
      ));
    }

    await getLoanDetail(loanId);
  }

  /// 执行提前还款（确认模拟结果后调用）
  Future<bool> executePrepayment({
    required String loanId,
    required int amount,
    required String strategy,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final pbStrategy = strategy == 'reduce_months'
          ? pb_enum.PrepaymentStrategy.PREPAYMENT_STRATEGY_REDUCE_MONTHS
          : pb_enum.PrepaymentStrategy.PREPAYMENT_STRATEGY_REDUCE_PAYMENT;

      final resp = await _client.executePrepayment(
        pb.ExecutePrepaymentRequest()
          ..loanId = loanId
          ..prepaymentAmount = Int64(amount)
          ..strategy = pbStrategy,
      );

      // Update local DB with the returned loan
      if (resp.hasLoan()) {
        await _db.upsertLoan(_loanFromProto(resp.loan));
      }

      state = state.copyWith(isLoading: false, clearSimulation: true);
      // Refresh detail + schedule from server
      await getLoanDetail(loanId);
      return true;
    } catch (e) {
      developer.log('[Loan] executePrepayment error: $e', name: 'LoanProvider');
      state = state.copyWith(isLoading: false, error: '提前还款失败: $e');
      return false;
    }
  }

  Future<void> recordPayment({
    required String loanId,
    required int monthNumber,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _client.recordPayment(pb.RecordPaymentRequest()
        ..loanId = loanId
        ..monthNumber = monthNumber);
    } catch (_) {
      // Offline
    }

    // Update local DB
    final schedules = await _db.getLoanSchedules(loanId);
    final target = schedules.where((s) => s.monthNumber == monthNumber).firstOrNull;
    if (target != null) {
      await _db.markSchedulePaid(target.id);
    }

    // Update loan paidMonths and remainingPrincipal
    final loan = await _db.getLoanById(loanId);
    if (loan != null) {
      final newPaidMonths = loan.paidMonths + 1;
      final scheduleItem = schedules.where((s) => s.monthNumber == monthNumber).firstOrNull;
      final newRemaining = scheduleItem?.remainingPrincipal ?? loan.remainingPrincipal;

      await _db.updateLoanFields(loanId, db.LoansCompanion(
        paidMonths: Value(newPaidMonths),
        remainingPrincipal: Value(newRemaining),
        updatedAt: Value(DateTime.now()),
      ));
    }

    await getLoanDetail(loanId);
  }

  /// Expose database for UI to query categories
  db.AppDatabase get database => _db;

  Future<void> updateLoanRepaymentCategory(String loanId, String categoryId) async {
    try {
      await _client.updateLoan(
        pb.UpdateLoanRequest()
          ..loanId = loanId
          ..repaymentCategoryId = categoryId,
      );
    } catch (_) {
      // Offline — still update locally
    }
    await (_db.update(_db.loans)
          ..where((l) => l.id.equals(loanId)))
        .write(db.LoansCompanion(
      repaymentCategoryId: Value(categoryId),
      updatedAt: Value(DateTime.now()),
    ));
    // Refresh current loan detail
    await getLoanDetail(loanId);
  }

  Future<void> deleteLoan(String loanId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _client.deleteLoan(pb.DeleteLoanRequest()..loanId = loanId);
    } catch (_) {
      // Offline
    }

    await _db.softDeleteLoan(loanId);
    await loadAll();
  }

  Future<void> deleteLoanGroup(String groupId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    // TODO: gRPC delete group when backend supports it

    await _db.softDeleteLoanGroup(groupId);
    await loadAll();
  }

  /// 获取某贷款的首期月供（用于列表展示）
  int getMonthlyPayment(db.Loan loan) {
    // After prepayment, remainingPrincipal and totalMonths are updated by the
    // server but principal stays at the original value. We must recalculate
    // the schedule from the *current* remaining state so the displayed monthly
    // payment matches the actual repayment plan.
    final remainingMonths = loan.totalMonths - loan.paidMonths;
    if (remainingMonths <= 0 || loan.remainingPrincipal <= 0) return 0;

    final schedule = LoanCalculator.calculate(
      principal: loan.remainingPrincipal,
      annualRate: loan.annualRate,
      totalMonths: remainingMonths,
      repaymentMethod: loan.repaymentMethod,
      startDate: loan.startDate,
      paymentDay: loan.paymentDay,
    );
    if (schedule.isEmpty) return 0;
    return schedule.first.payment;
  }

  /// 下次还款日
  DateTime? getNextPaymentDate(db.Loan loan) {
    if (loan.paidMonths >= loan.totalMonths) return null;
    return LoanCalculator.calcDueDate(
        loan.startDate, loan.paidMonths + 1, loan.paymentDay);
  }
}

// ── Sub Loan Input Model ──

class SubLoanInput {
  final String name;
  final String subType; // commercial / provident
  final int principal; // 分
  final double annualRate;
  final int totalMonths;
  final String repaymentMethod;
  final String rateType; // fixed / lpr_floating
  final double lprBase;
  final double lprSpread;
  final int rateAdjustMonth;
  final String interestCalcMethod;

  const SubLoanInput({
    required this.name,
    required this.subType,
    required this.principal,
    required this.annualRate,
    required this.totalMonths,
    required this.repaymentMethod,
    this.rateType = 'fixed',
    this.lprBase = 0.0,
    this.lprSpread = 0.0,
    this.rateAdjustMonth = 1,
    this.interestCalcMethod = 'monthly',
  });
}

// ── Provider ──

final loanProvider =
    StateNotifierProvider<LoanNotifier, LoanState>((ref) {
  final database = ref.watch(databaseProvider);
  final client = ref.watch(loanClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  final familyId = ref.watch(currentFamilyIdProvider);
  return LoanNotifier(database, client, userId, familyId);
});
