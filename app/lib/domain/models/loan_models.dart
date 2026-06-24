// NOTE: LoanGroupDisplayItem and LoanState use Drift-generated types (db.Loan,
// db.LoanGroup) directly. This is a known DIP violation kept for pragmatic
// reasons — creating domain entities for Loan's 20+ fields and mapping them
// across 30+ UI callsites is a separate effort (tracked as tech debt).
// ignore_for_file: depend_on_referenced_packages
import '../../data/local/database.dart' as db;

// ── Local Schedule Item (for display) ──

class LoanScheduleDisplayItem {
  final int monthNumber;
  final int payment; // 分
  final int principalPart; // 分
  final int interestPart; // 分
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
  final int prepaymentAmount; // 分
  final int totalInterestBefore; // 分
  final int totalInterestAfter; // 分
  final int interestSaved; // 分
  final int monthsReduced;
  final int newMonthlyPayment; // 分
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
  }) => LoanState(
    loans: loans ?? this.loans,
    loanGroups: loanGroups ?? this.loanGroups,
    currentLoan: clearCurrentLoan ? null : (currentLoan ?? this.currentLoan),
    currentGroup: clearCurrentGroup
        ? null
        : (currentGroup ?? this.currentGroup),
    schedule: schedule ?? this.schedule,
    simulation: clearSimulation ? null : (simulation ?? this.simulation),
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}
