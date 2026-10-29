import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rokter_badhon/controllers/administration_controller.dart';
import 'package:rokter_badhon/models/audit_log_model.dart';
import 'package:rokter_badhon/models/registration_request_model.dart';
import 'package:rokter_badhon/services/administration_service.dart';
import 'package:rokter_badhon/views/registration_review_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('bn');
    await initializeDateFormatting('en');
  });

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

  testWidgets('pending request offers guarded review actions and its UID can be copied', (
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
    expect(find.text('registration_admin_actions_note'), findsOneWidget);
    expect(find.text('Synthetic Applicant'), findsOneWidget);
    // Only the trusted callable performs privileged writes.
    expect(find.text('approve'), findsOneWidget);
    expect(find.text('reject'), findsOneWidget);

    String? copiedUid;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments as Map<Object?, Object?>;
          copiedUid = arguments['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.tap(find.text('Synthetic Applicant'));
    await tester.pumpAndSettle();
    expect(copiedUid, 'synthetic-uid');
    expect(find.text('registration_uid_copied'), findsOneWidget);
  });

  testWidgets('reject dialog cancels safely with keyboard open and never changes pending data', (
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

    await tester.tap(find.text('reject'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'A reviewed rejection reason');
    await tester.pump();

    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Synthetic Applicant'), findsOneWidget);
    expect(find.text('reject'), findsOneWidget);
    expect(service.calls, 1);
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
  Future<List<RegistrationRequestModel>> reviewedRegistrations({int limit = 50}) async {
    return const <RegistrationRequestModel>[];
  }

  @override
  Future<List<AuditLogModel>> auditLogs({int limit = 100}) async {
    return const <AuditLogModel>[];
  }
}
