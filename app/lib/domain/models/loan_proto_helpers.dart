import 'package:fixnum/fixnum.dart';
import '../../generated/proto/loan.pbenum.dart' as pb_enum;
import '../../generated/proto/google/protobuf/timestamp.pb.dart' as ts_pb;

// ── Proto ↔ String Converters (map-based, single source of truth) ──

const _loanTypeMap = <pb_enum.LoanType, String>{
  pb_enum.LoanType.LOAN_TYPE_MORTGAGE: 'mortgage',
  pb_enum.LoanType.LOAN_TYPE_CAR_LOAN: 'car_loan',
  pb_enum.LoanType.LOAN_TYPE_CREDIT_CARD: 'credit_card',
  pb_enum.LoanType.LOAN_TYPE_CONSUMER: 'consumer',
  pb_enum.LoanType.LOAN_TYPE_BUSINESS: 'business',
};

const _repaymentMethodMap = <pb_enum.RepaymentMethod, String>{
  pb_enum.RepaymentMethod.REPAYMENT_METHOD_EQUAL_PRINCIPAL: 'equal_principal',
  pb_enum.RepaymentMethod.REPAYMENT_METHOD_INTEREST_ONLY: 'interest_only',
  pb_enum.RepaymentMethod.REPAYMENT_METHOD_BULLET: 'bullet',
  pb_enum.RepaymentMethod.REPAYMENT_METHOD_EQUAL_INTEREST: 'equal_interest',
};

const _interestCalcMethodMap = <pb_enum.InterestCalcMethod, String>{
  pb_enum.InterestCalcMethod.INTEREST_CALC_DAILY_ACT_365: 'daily_act_365',
  pb_enum.InterestCalcMethod.INTEREST_CALC_DAILY_ACT_360: 'daily_act_360',
};

const _subTypeMap = <pb_enum.LoanSubType, String>{
  pb_enum.LoanSubType.LOAN_SUB_TYPE_COMMERCIAL: 'commercial',
  pb_enum.LoanSubType.LOAN_SUB_TYPE_PROVIDENT: 'provident',
};

const _rateTypeMap = <pb_enum.RateType, String>{
  pb_enum.RateType.RATE_TYPE_FIXED: 'fixed',
  pb_enum.RateType.RATE_TYPE_LPR_FLOATING: 'lpr_floating',
};

// Forward lookups (proto → string)
String loanTypeToString(pb_enum.LoanType type) =>
    _loanTypeMap[type] ?? 'other';

String repaymentMethodToString(pb_enum.RepaymentMethod method) =>
    _repaymentMethodMap[method] ?? 'equal_installment';

String subTypeToString(pb_enum.LoanSubType type) =>
    _subTypeMap[type] ?? '';

String rateTypeToString(pb_enum.RateType type) =>
    _rateTypeMap[type] ?? 'fixed';

// Reverse lookups (string → proto)
late final _loanTypeReverse = {for (final e in _loanTypeMap.entries) e.value: e.key};
late final _repaymentMethodReverse = {for (final e in _repaymentMethodMap.entries) e.value: e.key};
late final _interestCalcMethodReverse = {for (final e in _interestCalcMethodMap.entries) e.value: e.key};
late final _subTypeReverse = {for (final e in _subTypeMap.entries) e.value: e.key};
late final _rateTypeReverse = {for (final e in _rateTypeMap.entries) e.value: e.key};

pb_enum.LoanType stringToLoanType(String type) =>
    _loanTypeReverse[type] ?? pb_enum.LoanType.LOAN_TYPE_OTHER;

pb_enum.RepaymentMethod stringToRepaymentMethod(String method) =>
    _repaymentMethodReverse[method] ?? pb_enum.RepaymentMethod.REPAYMENT_METHOD_EQUAL_INSTALLMENT;

pb_enum.InterestCalcMethod stringToInterestCalcMethod(String method) =>
    _interestCalcMethodReverse[method] ?? pb_enum.InterestCalcMethod.INTEREST_CALC_MONTHLY;

pb_enum.LoanSubType stringToSubType(String type) =>
    _subTypeReverse[type] ?? pb_enum.LoanSubType.LOAN_SUB_TYPE_UNSPECIFIED;

pb_enum.RateType stringToRateType(String type) =>
    _rateTypeReverse[type] ?? pb_enum.RateType.RATE_TYPE_FIXED;

// ── Timestamp helpers (generic, consider moving to core/utils) ──

ts_pb.Timestamp toTimestamp(DateTime dt) {
  final seconds = dt.millisecondsSinceEpoch ~/ 1000;
  return ts_pb.Timestamp(seconds: Int64(seconds));
}

DateTime fromTimestamp(ts_pb.Timestamp ts) {
  return DateTime.fromMillisecondsSinceEpoch(ts.seconds.toInt() * 1000);
}
