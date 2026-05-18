import 'package:fixnum/fixnum.dart';
import '../../generated/proto/loan.pbenum.dart' as pb_enum;
import '../../generated/proto/google/protobuf/timestamp.pb.dart' as ts_pb;

// ── Helper: Proto LoanType ↔ String ──

String loanTypeToString(pb_enum.LoanType type) {
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

pb_enum.LoanType stringToLoanType(String type) {
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

String repaymentMethodToString(pb_enum.RepaymentMethod method) {
  switch (method) {
    case pb_enum.RepaymentMethod.REPAYMENT_METHOD_EQUAL_PRINCIPAL:
      return 'equal_principal';
    case pb_enum.RepaymentMethod.REPAYMENT_METHOD_INTEREST_ONLY:
      return 'interest_only';
    case pb_enum.RepaymentMethod.REPAYMENT_METHOD_BULLET:
      return 'bullet';
    case pb_enum.RepaymentMethod.REPAYMENT_METHOD_EQUAL_INTEREST:
      return 'equal_interest';
    default:
      return 'equal_installment';
  }
}

pb_enum.RepaymentMethod stringToRepaymentMethod(String method) {
  switch (method) {
    case 'equal_principal':
      return pb_enum.RepaymentMethod.REPAYMENT_METHOD_EQUAL_PRINCIPAL;
    case 'interest_only':
      return pb_enum.RepaymentMethod.REPAYMENT_METHOD_INTEREST_ONLY;
    case 'bullet':
      return pb_enum.RepaymentMethod.REPAYMENT_METHOD_BULLET;
    case 'equal_interest':
      return pb_enum.RepaymentMethod.REPAYMENT_METHOD_EQUAL_INTEREST;
    default:
      return pb_enum.RepaymentMethod.REPAYMENT_METHOD_EQUAL_INSTALLMENT;
  }
}

pb_enum.InterestCalcMethod stringToInterestCalcMethod(String method) {
  switch (method) {
    case 'daily_act_365':
      return pb_enum.InterestCalcMethod.INTEREST_CALC_DAILY_ACT_365;
    case 'daily_act_360':
      return pb_enum.InterestCalcMethod.INTEREST_CALC_DAILY_ACT_360;
    default:
      return pb_enum.InterestCalcMethod.INTEREST_CALC_MONTHLY;
  }
}

String subTypeToString(pb_enum.LoanSubType type) {
  switch (type) {
    case pb_enum.LoanSubType.LOAN_SUB_TYPE_COMMERCIAL:
      return 'commercial';
    case pb_enum.LoanSubType.LOAN_SUB_TYPE_PROVIDENT:
      return 'provident';
    default:
      return '';
  }
}

pb_enum.LoanSubType stringToSubType(String type) {
  switch (type) {
    case 'commercial':
      return pb_enum.LoanSubType.LOAN_SUB_TYPE_COMMERCIAL;
    case 'provident':
      return pb_enum.LoanSubType.LOAN_SUB_TYPE_PROVIDENT;
    default:
      return pb_enum.LoanSubType.LOAN_SUB_TYPE_UNSPECIFIED;
  }
}

String rateTypeToString(pb_enum.RateType type) {
  switch (type) {
    case pb_enum.RateType.RATE_TYPE_FIXED:
      return 'fixed';
    case pb_enum.RateType.RATE_TYPE_LPR_FLOATING:
      return 'lpr_floating';
    default:
      return 'fixed';
  }
}

pb_enum.RateType stringToRateType(String type) {
  switch (type) {
    case 'lpr_floating':
      return pb_enum.RateType.RATE_TYPE_LPR_FLOATING;
    default:
      return pb_enum.RateType.RATE_TYPE_FIXED;
  }
}

ts_pb.Timestamp toTimestamp(DateTime dt) {
  final seconds = dt.millisecondsSinceEpoch ~/ 1000;
  return ts_pb.Timestamp(seconds: Int64(seconds));
}

DateTime fromTimestamp(ts_pb.Timestamp ts) {
  return DateTime.fromMillisecondsSinceEpoch(ts.seconds.toInt() * 1000);
}

