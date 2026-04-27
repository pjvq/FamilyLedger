// Test: Create a family loan then list it
// Run: cd app && dart run test/grpc_loan_test.dart

import 'package:grpc/grpc.dart';
import 'package:fixnum/fixnum.dart';
import '../lib/generated/proto/loan.pbgrpc.dart';
import '../lib/generated/proto/loan.pb.dart' as pb;
import '../lib/generated/proto/loan.pbenum.dart' as pb_enum;
import '../lib/generated/proto/auth.pbgrpc.dart';
import '../lib/generated/proto/auth.pb.dart' as auth_pb;
import '../lib/generated/proto/family.pbgrpc.dart';
import '../lib/generated/proto/family.pb.dart' as family_pb;
import '../lib/generated/proto/google/protobuf/timestamp.pb.dart' as ts_pb;

void main() async {
  final channel = ClientChannel(
    '124.222.52.10',
    port: 50051,
    options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
  );

  try {
    // 1. Register + Login
    print('=== Step 1: Register & Login ===');
    final authClient = AuthServiceClient(channel);
    try {
      await authClient.register(
        auth_pb.RegisterRequest()
          ..email = 'loan_family_test@test.com'
          ..password = 'test1234',
        options: CallOptions(timeout: const Duration(seconds: 5)),
      );
      print('Registered new user');
    } catch (e) {
      print('Register: $e');
    }
    final loginResp = await authClient.login(
      auth_pb.LoginRequest()
        ..email = 'loan_family_test@test.com'
        ..password = 'test1234',
      options: CallOptions(timeout: const Duration(seconds: 5)),
    );
    final token = loginResp.accessToken;
    print('Login success, userId=${loginResp.userId}');

    final authOpts = CallOptions(
      metadata: {'authorization': 'Bearer $token'},
      timeout: const Duration(seconds: 10),
    );

    // 2. Create family
    print('\n=== Step 2: Create Family ===');
    final familyClient = FamilyServiceClient(channel);
    String familyId;
    try {
      final fResp = await familyClient.createFamily(
        family_pb.CreateFamilyRequest()..name = 'TestFamily',
        options: authOpts,
      );
      familyId = fResp.family.id;
      print('Created family: $familyId');
    } catch (e) {
      print('CreateFamily error: $e');
      print('Using hardcoded familyId for test...');
      familyId = 'will-fail';
      rethrow;
    }

    // 3. Create loan with familyId
    print('\n=== Step 3: Create Loan with familyId ===');
    final loanClient = LoanServiceClient(channel);
    final now = DateTime.now();
    final createResp = await loanClient.createLoan(
      pb.CreateLoanRequest()
        ..name = 'TestFamilyLoan'
        ..loanType = pb_enum.LoanType.LOAN_TYPE_MORTGAGE
        ..principal = Int64(10000000)
        ..annualRate = 3.85
        ..totalMonths = 360
        ..repaymentMethod = pb_enum.RepaymentMethod.REPAYMENT_METHOD_EQUAL_INSTALLMENT
        ..paymentDay = 15
        ..startDate = ts_pb.Timestamp(seconds: Int64(now.millisecondsSinceEpoch ~/ 1000))
        ..familyId = familyId,
      options: authOpts,
    );
    print('Created loan: id=${createResp.id}');
    print('  name=${createResp.name}');
    print('  familyId="${createResp.familyId}"');
    print('  userId=${createResp.userId}');

    // 4. ListLoans (personal mode - no familyId filter)
    print('\n=== Step 4: ListLoans (personal mode) ===');
    final listResp1 = await loanClient.listLoans(
      pb.ListLoansRequest(),
      options: authOpts,
    );
    print('ListLoans returned ${listResp1.loans.length} loans:');
    for (final loan in listResp1.loans) {
      print('  - ${loan.name} | familyId="${loan.familyId}"');
    }

    // 5. ListLoans (family mode)
    print('\n=== Step 5: ListLoans (family mode, familyId=$familyId) ===');
    final listResp2 = await loanClient.listLoans(
      pb.ListLoansRequest()..familyId = familyId,
      options: authOpts,
    );
    print('ListLoans returned ${listResp2.loans.length} loans:');
    for (final loan in listResp2.loans) {
      print('  - ${loan.name} | familyId="${loan.familyId}"');
    }

  } catch (e, st) {
    print('FATAL ERROR: $e');
    print('Stack: $st');
  } finally {
    await channel.shutdown();
  }
}
