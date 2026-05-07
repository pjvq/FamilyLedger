import 'dart:developer' as developer;
import 'dart:math' as math;
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

// ── Loan Group Display Model ──

class LoanGroupDisplayItem {
  final db.LoanGroup group;
  final List<db.Loan> subLoans;
  final int totalMonthlyPayment; // 分
  final int totalRemainingPrincipal; // 分
  final double overallProgress; // 0.0 ~ 1.0

  const LoanGroupDisplayItem({
    required this.group,
    required this.subLoans,
    required this.totalMonthlyPayment,
    required this.totalRemainingPrincipal,
    required this.overallProgress,
  });

  db.Loan? get commercialLoan =>
      subLoans.where((l) => l.subType == 'commercial').firstOrNull;

  db.Loan? get providentLoan =>
      subLoans.where((l) => l.subType == 'provident').firstOrNull;
}

// ── State ──

class LoanState {
  final List<db.Loan> loans; // standalone loans
  final List<LoanGroupDisplayItem> loanGroups;
  final db.Loan? currentLoan;
  final LoanGroupDisplayItem? currentGroup;
  final List<LoanScheduleDisplayItem> schedule;
  final PrepaymentSimulationResult? simulation;
  final bool isLoading;
  final String? error;

  const LoanState({
    this.loans = const [],
    this.loanGroups = const [],
    this.currentLoan,
    this.currentGroup,
    this.schedule = const [],
    this.simulation,
    this.isLoading = false,
    this.error,
  });

  LoanState copyWith({
    List<db.Loan>? loans,
    List<LoanGroupDisplayItem>? loanGroups,
    db.Loan? currentLoan,
    LoanGroupDisplayItem? currentGroup,
    List<LoanScheduleDisplayItem>? schedule,
    PrepaymentSimulationResult? simulation,
    bool? isLoading,
    String? error,
    bool clearCurrentLoan = false,
    bool clearCurrentGroup = false,
    bool clearSimulation = false,
    bool clearError = false,
  }) =>
      LoanState(
        loans: loans ?? this.loans,
        loanGroups: loanGroups ?? this.loanGroups,
        currentLoan:
            clearCurrentLoan ? null : (currentLoan ?? this.currentLoan),
        currentGroup:
            clearCurrentGroup ? null : (currentGroup ?? this.currentGroup),
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

  /// 计算贷款的有效年利率（考虑 LPR 浮动）
  static double effectiveRate(db.Loan loan) {
    if (loan.rateType == 'lpr_floating' && loan.lprBase > 0) {
      return loan.lprBase + loan.lprSpread;
    }
    return loan.annualRate;
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
      monthlyPayment = (newRemaining / remainingMonths).round();
      var rem = newRemaining;
      newMonths = 0;
      while (rem > 0 && newMonths < remainingMonths) {
        newMonths++;
        final pPart = newMonths == remainingMonths ? rem : monthlyPayment;
        rem -= pPart;
        if (rem < 0) rem = 0;
      }
    } else {
      final origMonthlyPayment = originalSchedule
          .firstWhere((i) => i.monthNumber == paidMonths + 1,
              orElse: () => originalSchedule.last)
          .payment;
      monthlyPayment = origMonthlyPayment;

      if (monthlyRate == 0) {
        newMonths = (newRemaining / monthlyPayment).ceil();
      } else {
        final prm = newRemaining * monthlyRate / monthlyPayment;
        if (prm >= 1) {
          newMonths = remainingMonths;
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

String _subTypeToString(pb_enum.LoanSubType type) {
  switch (type) {
    case pb_enum.LoanSubType.LOAN_SUB_TYPE_COMMERCIAL:
      return 'commercial';
    case pb_enum.LoanSubType.LOAN_SUB_TYPE_PROVIDENT:
      return 'provident';
    default:
      return '';
  }
}

pb_enum.LoanSubType _stringToSubType(String type) {
  switch (type) {
    case 'commercial':
      return pb_enum.LoanSubType.LOAN_SUB_TYPE_COMMERCIAL;
    case 'provident':
      return pb_enum.LoanSubType.LOAN_SUB_TYPE_PROVIDENT;
    default:
      return pb_enum.LoanSubType.LOAN_SUB_TYPE_UNSPECIFIED;
  }
}

String _rateTypeToString(pb_enum.RateType type) {
  switch (type) {
    case pb_enum.RateType.RATE_TYPE_FIXED:
      return 'fixed';
    case pb_enum.RateType.RATE_TYPE_LPR_FLOATING:
      return 'lpr_floating';
    default:
      return 'fixed';
  }
}

pb_enum.RateType _stringToRateType(String type) {
  switch (type) {
    case 'lpr_floating':
      return pb_enum.RateType.RATE_TYPE_LPR_FLOATING;
    default:
      return pb_enum.RateType.RATE_TYPE_FIXED;
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
  final String? _familyId;

  LoanNotifier(this._db, this._client, this._userId, this._familyId)
      : super(const LoanState()) {
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
    developer.log('[Loan] listLoans: userId=$_userId familyId=$_familyId');

    try {
      // gRPC first
      final req = pb.ListLoansRequest();
      if (_familyId != null && _familyId.isNotEmpty) {
        req.familyId = _familyId;
      }
      final resp = await _client.listLoans(req,
          options: CallOptions(timeout: const Duration(seconds: 10)));
      developer.log('[Loan] listLoans: gRPC returned ${resp.loans.length} loans');
      for (final loan in resp.loans) {
        await _db.upsertLoan(_loanFromProto(loan));
      }
    } catch (e) {
      // Offline fallback — use local DB
    }

    try {
      final loans = await _db.getStandaloneLoans(_userId, familyId: _familyId);
      developer.log('[Loan] listLoans: local DB returned ${loans.length} standalone loans (userId=$_userId, familyId=$_familyId)');
      state = state.copyWith(loans: loans, isLoading: false);
    } catch (e) {
      developer.log('[Loan] listLoans: local DB error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> listLoanGroups() async {
    if (_userId == null) return;

    developer.log('[Loan] listLoanGroups: userId=$_userId familyId=$_familyId');

    try {
      final grpReq = pb.ListLoanGroupsRequest();
      if (_familyId != null && _familyId.isNotEmpty) {
        grpReq.familyId = _familyId;
      }
      final resp = await _client.listLoanGroups(grpReq,
          options: CallOptions(timeout: const Duration(seconds: 10)));
      developer.log('[Loan] listLoanGroups: gRPC returned ${resp.groups.length} groups');
      for (final group in resp.groups) {
        developer.log('[Loan] listLoanGroups: upserting group id=${group.id} name=${group.name} familyId="${group.familyId}" userId=${group.userId}');
        await _db.upsertLoanGroup(db.LoanGroupsCompanion.insert(
          id: group.id,
          userId: group.userId,
          familyId: Value(group.familyId),
          name: group.name,
          groupType: group.groupType,
          totalPrincipal: group.totalPrincipal.toInt(),
          paymentDay: group.paymentDay,
          startDate: _fromTimestamp(group.startDate),
          accountId: Value(group.accountId),
        ));
        for (final loan in group.subLoans) {
          await _db.upsertLoan(_loanFromProto(loan));
        }
      }
    } catch (e) {
      developer.log('[Loan] listLoanGroups: gRPC error: $e');
      // Offline fallback
    }

    try {
      final groups = await _db.getLoanGroups(_userId, familyId: _familyId);
      developer.log('[Loan] listLoanGroups: local DB returned ${groups.length} groups (query: userId=$_userId, familyId=$_familyId)');
      for (final g in groups) {
        developer.log('[Loan] listLoanGroups: local group id=${g.id} name=${g.name} familyId="${g.familyId}"');
      }
      final displayGroups = <LoanGroupDisplayItem>[];
      for (final group in groups) {
        final subLoans = await _db.getLoansByGroupId(group.id);
        displayGroups.add(_buildGroupDisplay(group, subLoans));
      }
      state = state.copyWith(loanGroups: displayGroups);
    } catch (e) {
      developer.log('[Loan] listLoanGroups: local DB error: $e');
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
      startDate: _fromTimestamp(loan.startDate),
      loanType: Value(_loanTypeToString(loan.loanType)),
      paidMonths: Value(loan.paidMonths),
      repaymentMethod: Value(_repaymentMethodToString(loan.repaymentMethod)),
      accountId: Value(loan.accountId),
      groupId: Value(loan.groupId),
      subType: Value(_subTypeToString(loan.subType)),
      rateType: Value(_rateTypeToString(loan.rateType)),
      lprBase: Value(loan.lprBase),
      lprSpread: Value(loan.lprSpread),
      rateAdjustMonth: Value(loan.rateAdjustMonth),
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
  }) async {
    if (_userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    developer.log('[Loan] createLoan: name=$name familyId=$familyId userId=$_userId');

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
        ..accountId = accountId ?? ''
        ..familyId = familyId ?? '');
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
        ..startDate = _toTimestamp(startDate)
        ..accountId = accountId ?? ''
        ..loanType = _stringToLoanType(loanType)
        ..familyId = familyId ?? '';

      for (final sub in subLoans) {
        req.subLoans.add(pb.SubLoanSpec()
          ..name = sub.name
          ..subType = _stringToSubType(sub.subType)
          ..principal = Int64(sub.principal)
          ..annualRate = sub.annualRate
          ..totalMonths = sub.totalMonths
          ..repaymentMethod = _stringToRepaymentMethod(sub.repaymentMethod)
          ..rateType = _stringToRateType(sub.rateType)
          ..lprBase = sub.lprBase
          ..lprSpread = sub.lprSpread
          ..rateAdjustMonth = sub.rateAdjustMonth);
      }

      final resp = await _client.createLoanGroup(req);
      await _db.upsertLoanGroup(db.LoanGroupsCompanion.insert(
        id: resp.id,
        userId: resp.userId,
        name: resp.name,
        groupType: resp.groupType,
        totalPrincipal: resp.totalPrincipal.toInt(),
        paymentDay: resp.paymentDay,
        startDate: _fromTimestamp(resp.startDate),
        accountId: Value(resp.accountId),
        familyId: Value(resp.familyId),
        loanType: Value(_loanTypeToString(resp.loanType)),
      ));
      for (final loan in resp.subLoans) {
        await _db.upsertLoan(_loanFromProto(loan));
        await _generateScheduleForLoan(loan.id, loan.principal.toInt(),
            loan.annualRate, loan.totalMonths,
            _repaymentMethodToString(loan.repaymentMethod),
            _fromTimestamp(loan.startDate), loan.paymentDay);
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
          dueDate: _fromTimestamp(item.dueDate),
          isPaid: item.isPaid,
          paidDate: item.hasPaidDate() ? _fromTimestamp(item.paidDate) : null,
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
