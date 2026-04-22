import 'dart:math' as math;
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

// ── Local Schedule Item (for display) ──

class LoanScheduleDisplayItem {
  final int monthNumber;
  final int payment;         // 分
  final int principalPart;   // 分
  final int interestPart;    // 分
  final int remainingPrincipal; // 分
  final DateTime dueDate;
  final bool isPaid;
  final DateTime? paidDate;

  const LoanScheduleDisplayItem({
    required this.monthNumber,
    required this.payment,
    required this.principalPart,
    required this.interestPart,
    required this.remainingPrincipal,
    required this.dueDate,
    this.isPaid = false,
    this.paidDate,
  });
}

// ── Prepayment Simulation Result ──

class PrepaymentSimulationResult {
  final int prepaymentAmount;     // 分
  final int totalInterestBefore;  // 分
  final int totalInterestAfter;   // 分
  final int interestSaved;        // 分
  final int monthsReduced;
  final int newMonthlyPayment;    // 分
  final List<LoanScheduleDisplayItem> newSchedule;

  const PrepaymentSimulationResult({
    required this.prepaymentAmount,
    required this.totalInterestBefore,
    required this.totalInterestAfter,
    required this.interestSaved,
    required this.monthsReduced,
    required this.newMonthlyPayment,
    required this.newSchedule,
  });
}

// ── State ──

class LoanState {
  final List<db.Loan> loans;
  final db.Loan? currentLoan;
  final List<LoanScheduleDisplayItem> schedule;
  final PrepaymentSimulationResult? simulation;
  final bool isLoading;
  final String? error;

  const LoanState({
    this.loans = const [],
    this.currentLoan,
    this.schedule = const [],
    this.simulation,
    this.isLoading = false,
    this.error,
  });

  LoanState copyWith({
    List<db.Loan>? loans,
    db.Loan? currentLoan,
    List<LoanScheduleDisplayItem>? schedule,
    PrepaymentSimulationResult? simulation,
    bool? isLoading,
    String? error,
    bool clearCurrentLoan = false,
    bool clearSimulation = false,
    bool clearError = false,
  }) =>
      LoanState(
        loans: loans ?? this.loans,
        currentLoan:
            clearCurrentLoan ? null : (currentLoan ?? this.currentLoan),
        schedule: schedule ?? this.schedule,
        simulation:
            clearSimulation ? null : (simulation ?? this.simulation),
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ── Loan Calculator (local, offline-capable) ──

class LoanCalculator {
  LoanCalculator._();

  /// 等额本息还款计划
  static List<LoanScheduleDisplayItem> equalInstallment({
    required int principal,       // 分
    required double annualRate,   // 如 4.2
    required int totalMonths,
    required DateTime startDate,
    required int paymentDay,
    int paidMonths = 0,
  }) {
    final monthlyRate = annualRate / 100 / 12;
    final items = <LoanScheduleDisplayItem>[];

    if (monthlyRate == 0) {
      // 0利率
      final monthlyPayment = (principal / totalMonths).round();
      var remaining = principal;
      for (var i = 1; i <= totalMonths; i++) {
        final principalPart =
            i == totalMonths ? remaining : monthlyPayment;
        remaining -= principalPart;
        items.add(LoanScheduleDisplayItem(
          monthNumber: i,
          payment: principalPart,
          principalPart: principalPart,
          interestPart: 0,
          remainingPrincipal: remaining < 0 ? 0 : remaining,
          dueDate: _dueDate(startDate, i, paymentDay),
          isPaid: i <= paidMonths,
        ));
      }
      return items;
    }

    // 标准等额本息: M = P * r * (1+r)^n / ((1+r)^n - 1)
    final pow = math.pow(1 + monthlyRate, totalMonths);
    final monthlyPayment =
        (principal * monthlyRate * pow / (pow - 1)).round();

    var remaining = principal;
    for (var i = 1; i <= totalMonths; i++) {
      final interestPart = (remaining * monthlyRate).round();
      final principalPart = i == totalMonths
          ? remaining
          : monthlyPayment - interestPart;
      remaining -= principalPart;
      if (remaining < 0) remaining = 0;

      items.add(LoanScheduleDisplayItem(
        monthNumber: i,
        payment: i == totalMonths ? principalPart + interestPart : monthlyPayment,
        principalPart: principalPart,
        interestPart: interestPart,
        remainingPrincipal: remaining,
        dueDate: _dueDate(startDate, i, paymentDay),
        isPaid: i <= paidMonths,
      ));
    }
    return items;
  }

  /// 等额本金还款计划
  static List<LoanScheduleDisplayItem> equalPrincipal({
    required int principal,       // 分
    required double annualRate,   // 如 4.2
    required int totalMonths,
    required DateTime startDate,
    required int paymentDay,
    int paidMonths = 0,
  }) {
    final monthlyRate = annualRate / 100 / 12;
    final monthlyPrincipal = (principal / totalMonths).round();
    final items = <LoanScheduleDisplayItem>[];

    var remaining = principal;
    for (var i = 1; i <= totalMonths; i++) {
      final interestPart = (remaining * monthlyRate).round();
      final principalPart =
          i == totalMonths ? remaining : monthlyPrincipal;
      remaining -= principalPart;
      if (remaining < 0) remaining = 0;

      items.add(LoanScheduleDisplayItem(
        monthNumber: i,
        payment: principalPart + interestPart,
        principalPart: principalPart,
        interestPart: interestPart,
        remainingPrincipal: remaining,
        dueDate: _dueDate(startDate, i, paymentDay),
        isPaid: i <= paidMonths,
      ));
    }
    return items;
  }

  /// 计算还款计划
  static List<LoanScheduleDisplayItem> calculate({
    required int principal,
    required double annualRate,
    required int totalMonths,
    required String repaymentMethod,
    required DateTime startDate,
    required int paymentDay,
    int paidMonths = 0,
  }) {
    if (repaymentMethod == 'equal_principal') {
      return equalPrincipal(
        principal: principal,
        annualRate: annualRate,
        totalMonths: totalMonths,
        startDate: startDate,
        paymentDay: paymentDay,
        paidMonths: paidMonths,
      );
    }
    return equalInstallment(
      principal: principal,
      annualRate: annualRate,
      totalMonths: totalMonths,
      startDate: startDate,
      paymentDay: paymentDay,
      paidMonths: paidMonths,
    );
  }

  /// 提前还款模拟 — 缩短期限
  static PrepaymentSimulationResult simulateReduceMonths({
    required int remainingPrincipal,
    required double annualRate,
    required int remainingMonths,
    required int paidMonths,
    required int prepaymentAmount,
    required String repaymentMethod,
    required DateTime startDate,
    required int paymentDay,
    required int originalPrincipal,
    required int originalTotalMonths,
  }) {
    // 原方案总利息
    final originalSchedule = calculate(
      principal: originalPrincipal,
      annualRate: annualRate,
      totalMonths: originalTotalMonths,
      repaymentMethod: repaymentMethod,
      startDate: startDate,
      paymentDay: paymentDay,
    );
    final totalInterestBefore =
        originalSchedule.fold<int>(0, (s, i) => s + i.interestPart);

    // 提前还款后剩余本金
    final newRemaining = remainingPrincipal - prepaymentAmount;
    if (newRemaining <= 0) {
      return PrepaymentSimulationResult(
        prepaymentAmount: prepaymentAmount,
        totalInterestBefore: totalInterestBefore,
        totalInterestAfter: originalSchedule
            .where((i) => i.monthNumber <= paidMonths)
            .fold<int>(0, (s, i) => s + i.interestPart),
        interestSaved: totalInterestBefore -
            originalSchedule
                .where((i) => i.monthNumber <= paidMonths)
                .fold<int>(0, (s, i) => s + i.interestPart),
        monthsReduced: remainingMonths,
        newMonthlyPayment: 0,
        newSchedule: [],
      );
    }

    // 缩短期限: 月供不变，重新算期数
    final monthlyRate = annualRate / 100 / 12;
    int newMonths;
    int monthlyPayment;

    if (repaymentMethod == 'equal_principal') {
      // 等额本金: 月供递减，保持每月本金不变
      monthlyPayment = (newRemaining / remainingMonths).round();
      // 重新算能还几期
      var rem = newRemaining;
      newMonths = 0;
      while (rem > 0 && newMonths < remainingMonths) {
        newMonths++;
        // interest is tracked implicitly in the payment schedule
        final pPart = newMonths == remainingMonths ? rem : monthlyPayment;
        rem -= pPart;
        if (rem < 0) rem = 0;
      }
    } else {
      // 等额本息: 保持原月供，算新期数
      final origMonthlyPayment = originalSchedule
          .firstWhere((i) => i.monthNumber == paidMonths + 1,
              orElse: () => originalSchedule.last)
          .payment;
      monthlyPayment = origMonthlyPayment;

      if (monthlyRate == 0) {
        newMonths = (newRemaining / monthlyPayment).ceil();
      } else {
        // n = -log(1 - P*r/M) / log(1+r)
        final prm = newRemaining * monthlyRate / monthlyPayment;
        if (prm >= 1) {
          newMonths = remainingMonths; // 月供不够覆盖利息
        } else {
          newMonths = (-math.log(1 - prm) / math.log(1 + monthlyRate)).ceil();
        }
      }
    }

    final newSchedule = calculate(
      principal: newRemaining,
      annualRate: annualRate,
      totalMonths: newMonths,
      repaymentMethod: repaymentMethod,
      startDate: _dueDate(startDate, paidMonths, paymentDay),
      paymentDay: paymentDay,
    );

    final totalInterestAfter =
        originalSchedule
            .where((i) => i.monthNumber <= paidMonths)
            .fold<int>(0, (s, i) => s + i.interestPart) +
        newSchedule.fold<int>(0, (s, i) => s + i.interestPart);

    return PrepaymentSimulationResult(
      prepaymentAmount: prepaymentAmount,
      totalInterestBefore: totalInterestBefore,
      totalInterestAfter: totalInterestAfter,
      interestSaved: totalInterestBefore - totalInterestAfter,
      monthsReduced: remainingMonths - newMonths,
      newMonthlyPayment: newSchedule.isNotEmpty ? newSchedule.first.payment : 0,
      newSchedule: newSchedule,
    );
  }

  /// 提前还款模拟 — 减少月供
  static PrepaymentSimulationResult simulateReducePayment({
    required int remainingPrincipal,
    required double annualRate,
    required int remainingMonths,
    required int paidMonths,
    required int prepaymentAmount,
    required String repaymentMethod,
    required DateTime startDate,
    required int paymentDay,
    required int originalPrincipal,
    required int originalTotalMonths,
  }) {
    final originalSchedule = calculate(
      principal: originalPrincipal,
      annualRate: annualRate,
      totalMonths: originalTotalMonths,
      repaymentMethod: repaymentMethod,
      startDate: startDate,
      paymentDay: paymentDay,
    );
    final totalInterestBefore =
        originalSchedule.fold<int>(0, (s, i) => s + i.interestPart);

    final newRemaining = remainingPrincipal - prepaymentAmount;
    if (newRemaining <= 0) {
      final paidInterest = originalSchedule
          .where((i) => i.monthNumber <= paidMonths)
          .fold<int>(0, (s, i) => s + i.interestPart);
      return PrepaymentSimulationResult(
        prepaymentAmount: prepaymentAmount,
        totalInterestBefore: totalInterestBefore,
        totalInterestAfter: paidInterest,
        interestSaved: totalInterestBefore - paidInterest,
        monthsReduced: remainingMonths,
        newMonthlyPayment: 0,
        newSchedule: [],
      );
    }

    // 减少月供: 期数不变，重新算月供
    final newSchedule = calculate(
      principal: newRemaining,
      annualRate: annualRate,
      totalMonths: remainingMonths,
      repaymentMethod: repaymentMethod,
      startDate: _dueDate(startDate, paidMonths, paymentDay),
      paymentDay: paymentDay,
    );

    final totalInterestAfter =
        originalSchedule
            .where((i) => i.monthNumber <= paidMonths)
            .fold<int>(0, (s, i) => s + i.interestPart) +
        newSchedule.fold<int>(0, (s, i) => s + i.interestPart);

    return PrepaymentSimulationResult(
      prepaymentAmount: prepaymentAmount,
      totalInterestBefore: totalInterestBefore,
      totalInterestAfter: totalInterestAfter,
      interestSaved: totalInterestBefore - totalInterestAfter,
      monthsReduced: 0,
      newMonthlyPayment: newSchedule.isNotEmpty ? newSchedule.first.payment : 0,
      newSchedule: newSchedule,
    );
  }

  static DateTime _dueDate(DateTime startDate, int monthOffset, int paymentDay) {
    var year = startDate.year;
    var month = startDate.month + monthOffset;
    while (month > 12) {
      month -= 12;
      year++;
    }
    final maxDay = DateTime(year, month + 1, 0).day;
    final day = paymentDay > maxDay ? maxDay : paymentDay;
    return DateTime(year, month, day);
  }
}

// ── Helper: Proto LoanType ↔ String ──

String _loanTypeToString(pb_enum.LoanType type) {
  switch (type) {
    case pb_enum.LoanType.LOAN_TYPE_MORTGAGE:
      return 'mortgage';
    case pb_enum.LoanType.LOAN_TYPE_CAR_LOAN:
      return 'car_loan';
    case pb_enum.LoanType.LOAN_TYPE_CREDIT_CARD:
      return 'credit_card';
    case pb_enum.LoanType.LOAN_TYPE_CONSUMER:
      return 'consumer';
    case pb_enum.LoanType.LOAN_TYPE_BUSINESS:
      return 'business';
    default:
      return 'other';
  }
}

pb_enum.LoanType _stringToLoanType(String type) {
  switch (type) {
    case 'mortgage':
      return pb_enum.LoanType.LOAN_TYPE_MORTGAGE;
    case 'car_loan':
      return pb_enum.LoanType.LOAN_TYPE_CAR_LOAN;
    case 'credit_card':
      return pb_enum.LoanType.LOAN_TYPE_CREDIT_CARD;
    case 'consumer':
      return pb_enum.LoanType.LOAN_TYPE_CONSUMER;
    case 'business':
      return pb_enum.LoanType.LOAN_TYPE_BUSINESS;
    default:
      return pb_enum.LoanType.LOAN_TYPE_OTHER;
  }
}

String _repaymentMethodToString(pb_enum.RepaymentMethod method) {
  switch (method) {
    case pb_enum.RepaymentMethod.REPAYMENT_METHOD_EQUAL_PRINCIPAL:
      return 'equal_principal';
    default:
      return 'equal_installment';
  }
}

pb_enum.RepaymentMethod _stringToRepaymentMethod(String method) {
  switch (method) {
    case 'equal_principal':
      return pb_enum.RepaymentMethod.REPAYMENT_METHOD_EQUAL_PRINCIPAL;
    default:
      return pb_enum.RepaymentMethod.REPAYMENT_METHOD_EQUAL_INSTALLMENT;
  }
}

ts_pb.Timestamp _toTimestamp(DateTime dt) {
  final seconds = dt.millisecondsSinceEpoch ~/ 1000;
  return ts_pb.Timestamp(seconds: Int64(seconds));
}

DateTime _fromTimestamp(ts_pb.Timestamp ts) {
  return DateTime.fromMillisecondsSinceEpoch(ts.seconds.toInt() * 1000);
}

// ── Notifier ──

class LoanNotifier extends StateNotifier<LoanState> {
  final db.AppDatabase _db;
  final LoanServiceClient _client;
  final String? _userId;

  LoanNotifier(this._db, this._client, this._userId)
      : super(const LoanState()) {
    if (_userId != null) {
      listLoans();
    }
  }

  Future<void> listLoans() async {
    if (_userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // gRPC first
      final resp = await _client.listLoans(pb.ListLoansRequest());
      for (final loan in resp.loans) {
        await _db.upsertLoan(db.LoansCompanion.insert(
          id: loan.id,
          userId: loan.userId,
          name: loan.name,
          principal: loan.principal.toInt(),
          remainingPrincipal: loan.remainingPrincipal.toInt(),
          annualRate: loan.annualRate,
          totalMonths: loan.totalMonths,
          paymentDay: loan.paymentDay,
          startDate: _fromTimestamp(loan.startDate),
          loanType: Value(_loanTypeToString(loan.loanType)),
          paidMonths: Value(loan.paidMonths),
          repaymentMethod: Value(_repaymentMethodToString(loan.repaymentMethod)),
          accountId: Value(loan.accountId),
        ));
      }
    } catch (_) {
      // Offline fallback — use local DB
    }

    try {
      final loans = await _db.getLoans(_userId);
      state = state.copyWith(loans: loans, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
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
  }) async {
    if (_userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);

    String loanId = const Uuid().v4();

    try {
      final resp = await _client.createLoan(pb.CreateLoanRequest()
        ..name = name
        ..loanType = _stringToLoanType(loanType)
        ..principal = Int64(principal)
        ..annualRate = annualRate
        ..totalMonths = totalMonths
        ..repaymentMethod = _stringToRepaymentMethod(repaymentMethod)
        ..paymentDay = paymentDay
        ..startDate = _toTimestamp(startDate)
        ..accountId = accountId ?? '');
      loanId = resp.id;

      await _db.upsertLoan(db.LoansCompanion.insert(
        id: resp.id,
        userId: resp.userId,
        name: resp.name,
        principal: resp.principal.toInt(),
        remainingPrincipal: resp.remainingPrincipal.toInt(),
        annualRate: resp.annualRate,
        totalMonths: resp.totalMonths,
        paymentDay: resp.paymentDay,
        startDate: _fromTimestamp(resp.startDate),
        loanType: Value(_loanTypeToString(resp.loanType)),
        paidMonths: Value(resp.paidMonths),
        repaymentMethod: Value(_repaymentMethodToString(resp.repaymentMethod)),
        accountId: Value(resp.accountId),
      ));
    } catch (_) {
      // Offline: save locally
      await _db.upsertLoan(db.LoansCompanion.insert(
        id: loanId,
        userId: _userId,
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

    await listLoans();
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
          dueDate: _fromTimestamp(item.dueDate),
          isPaid: item.isPaid,
          paidDate: item.hasPaidDate() ? _fromTimestamp(item.paidDate) : null,
        )).toList();
      } catch (_) {
        // Local fallback: calculate or read from DB
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
            dueDate: _fromTimestamp(item.dueDate),
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
        ..effectiveDate = _toTimestamp(effectiveDate));
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
      startDate: LoanCalculator._dueDate(
          loan.startDate, loan.paidMonths, loan.paymentDay),
      paymentDay: loan.paymentDay,
    );

    // Keep paid schedules, replace unpaid
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

  Future<void> deleteLoan(String loanId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _client.deleteLoan(pb.DeleteLoanRequest()..loanId = loanId);
    } catch (_) {
      // Offline
    }

    await _db.softDeleteLoan(loanId);
    await listLoans();
  }

  /// 获取某贷款的首期月供（用于列表展示）
  int getMonthlyPayment(db.Loan loan) {
    final schedule = LoanCalculator.calculate(
      principal: loan.principal,
      annualRate: loan.annualRate,
      totalMonths: loan.totalMonths,
      repaymentMethod: loan.repaymentMethod,
      startDate: loan.startDate,
      paymentDay: loan.paymentDay,
    );
    if (schedule.isEmpty) return 0;
    // For 等额本金, use the current month's payment
    final currentMonth = loan.paidMonths + 1;
    final item = schedule.where((s) => s.monthNumber == currentMonth).firstOrNull;
    return item?.payment ?? schedule.first.payment;
  }

  /// 下次还款日
  DateTime? getNextPaymentDate(db.Loan loan) {
    if (loan.paidMonths >= loan.totalMonths) return null;
    return LoanCalculator._dueDate(
        loan.startDate, loan.paidMonths + 1, loan.paymentDay);
  }
}

// ── Provider ──

final loanProvider =
    StateNotifierProvider<LoanNotifier, LoanState>((ref) {
  final database = ref.watch(databaseProvider);
  final client = ref.watch(loanClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  return LoanNotifier(database, client, userId);
});
