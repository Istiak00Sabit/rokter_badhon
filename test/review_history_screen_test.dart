import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rokter_badhon/views/review_history_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('bn');
    await initializeDateFormatting('en');
  });

  testWidgets('approved and rejected requests remain visible in history', (tester) async {
    await tester.pumpWidget(GetMaterialApp(
      home: ReviewHistoryScreen(
        kind: ReviewHistoryKind.registration,
        loader: () async => [
          ReviewHistoryEntry(
            name: 'Approved Member',
            phone: '01700000000',
            status: 'approved',
            decidedAt: DateTime.utc(2026, 10, 30),
          ),
          ReviewHistoryEntry(
            name: 'Rejected Member',
            phone: '01800000000',
            status: 'rejected',
            decidedAt: DateTime.utc(2026, 10, 29),
            reason: 'Duplicate account registration',
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Approved Member'), findsOneWidget);
    expect(find.text('Rejected Member'), findsOneWidget);
    expect(find.textContaining('Duplicate account registration'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty review history shows a proper empty page, not red error', (tester) async {
    await tester.pumpWidget(GetMaterialApp(
      home: ReviewHistoryScreen(
        kind: ReviewHistoryKind.donor,
        loader: () async => const <ReviewHistoryEntry>[],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('review_history_empty'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
