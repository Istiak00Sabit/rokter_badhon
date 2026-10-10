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
  _FakeRegistrationService({this.denyReads = false});

  final bool denyReads;
  int calls = 0;

  @override
  Future<List<RegistrationRequestModel>> pendingRegistrations() async {
    calls++;
    if (denyReads) {
      throw const AdministrationServiceException('permission_denied');
    }
    return const <RegistrationRequestModel>[];
  }

  @override
  Future<List<AuditLogModel>> auditLogs({int limit = 100}) async {
    return const <AuditLogModel>[];
  }
}
