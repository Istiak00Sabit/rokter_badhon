import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rokter_badhon/controllers/administration_controller.dart';
import 'package:rokter_badhon/models/audit_log_model.dart';
import 'package:rokter_badhon/models/registration_request_model.dart';
import 'package:rokter_badhon/services/administration_service.dart';
import 'package:rokter_badhon/views/registration_review_screen.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  testWidgets('empty pending list reads once and loads again only on Retry', (
    tester,
  ) async {
    final service = _FakeRegistrationService();
    Get.put(
      AdministrationController(service: service),
      tag: 'registrations',
    );

    await tester.pumpWidget(
      const GetMaterialApp(home: RegistrationReviewScreen()),
    );
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(find.text('no_pending_registrations'), findsOneWidget);

    // Ordinary rebuilds must never issue an additional Firestore query.
    await tester.pump(const Duration(milliseconds: 100));
    expect(service.calls, 1);

    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
  });

  testWidgets('pending request is review-only and its UID can be copied', (
    tester,
  ) async {
    final service = _FakeRegistrationService(hasPending: true);
    Get.put(
      AdministrationController(service: service),
      tag: 'registrations',
    );

    await tester.pumpWidget(
      const GetMaterialApp(home: RegistrationReviewScreen()),
    );
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(find.text('registration_operator_only'), findsOneWidget);
    expect(find.text('Synthetic Applicant'), findsOneWidget);
    // No direct approve or reject controls: privileged changes require
    // operator authentication and an audited trusted transaction.
    expect(find.text('approve'), findsNothing);
    expect(find.text('reject'), findsNothing);

    await tester.tap(find.text('Synthetic Applicant'));
    await tester.pump();
    expect(find.text('registration_uid_copied'), findsOneWidget);
  });

  testWidgets('query failures do not cause automatic retry loops', (
    tester,
  ) async {
    final service = _FakeRegistrationService(denyReads: true);
    Get.put(
      AdministrationController(service: service),
      tag: 'registrations',
    );

    await tester.pumpWidget(
      const GetMaterialApp(home: RegistrationReviewScreen()),
    );
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(find.text('permission_denied'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    expect(service.calls, 1);

    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
  });
}

class _FakeRegistrationService implements AdministrationService {
  _FakeRegistrationService({this.denyReads = false, this.hasPending = false});

  final bool denyReads;
  final bool hasPending;
  int calls = 0;

  @override
  Future<List<RegistrationRequestModel>> pendingRegistrations() async {
    calls++;
    if (denyReads) {
      throw const AdministrationServiceException('permission_denied');
    }
    if (hasPending) {
      return [
        RegistrationRequestModel(
          authUid: 'synthetic-uid',
          name: 'Synthetic Applicant',
          phone: '01700000000',
          email: null,
          bloodGroup: 'O+',
          profession: null,
          address: null,
          union: 'ঘাটাইল',
          village: 'নরজনা',
          status: RegistrationRequestStatus.pending,
          requestedAt: DateTime.utc(2026, 10, 10),
          approvedBy: null,
          approvedAt: null,
          rejectedBy: null,
          rejectedAt: null,
          linkedUserId: null,
        ),
      ];
    }
    return const <RegistrationRequestModel>[];
  }

  @override
  Future<List<AuditLogModel>> auditLogs({int limit = 100}) async {
    return const <AuditLogModel>[];
  }
}
