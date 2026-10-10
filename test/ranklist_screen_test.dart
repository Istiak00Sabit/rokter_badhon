import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rokter_badhon/models/donor_model.dart';
import 'package:rokter_badhon/views/ranklist_screen.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('ranklist does not refetch when the widget rebuilds', (tester) async {
    var calls = 0;
    Future<List<DonorModel>> load() async {
      calls++;
      return const <DonorModel>[];
    }

    await tester.pumpWidget(GetMaterialApp(home: RanklistScreen(loadRanklist: load)));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('ranklist_empty'), findsOneWidget);

    // Updating the app's inherited theme must not trigger another query.
    await tester.pumpWidget(GetMaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: RanklistScreen(loadRanklist: load),
    ));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('ranklist error retry starts one new query, and can recover', (tester) async {
    var calls = 0;
    Future<List<DonorModel>> load() async {
      calls++;
      if (calls == 1) throw StateError('synthetic network failure');
      return const <DonorModel>[];
    }

    await tester.pumpWidget(GetMaterialApp(home: RanklistScreen(loadRanklist: load)));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('ranklist_error'), findsOneWidget);

    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('ranklist_empty'), findsOneWidget);
  });
}
