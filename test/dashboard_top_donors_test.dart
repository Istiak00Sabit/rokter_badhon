import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rokter_badhon/models/donor_model.dart';
import 'package:rokter_badhon/widgets/dashboard_top_donors.dart';

DonorModel donor(String id, int count) => DonorModel(
  id: id,
  name: 'Donor $id',
  phone: '01700000000',
  bloodGroup: 'O+',
  gender: null,
  photoUrl: null,
  village: null,
  union: null,
  upazila: 'Ghatail',
  district: 'Tangail',
  profession: null,
  linkedUserId: null,
  active: true,
  lastDonatedAt: null,
  totalDonations: count,
  createdAt: DateTime.utc(2026, 1, 1),
  createdBy: 'reviewer',
  updatedAt: DateTime.utc(2026, 1, 1),
  updatedBy: 'reviewer',
);

void main() {
  testWidgets('dashboard shows top three genuine counts without inventing ranks', (tester) async {
    final donors = [donor('A', 12), donor('B', 8), donor('C', 3)];
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(body: DashboardTopDonors(
        donorsStream: Stream.value(donors),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Donor A'), findsOneWidget);
    expect(find.text('Donor B'), findsOneWidget);
    expect(find.text('Donor C'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('#3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty ranking shows honest no-records message', (tester) async {
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(body: DashboardTopDonors(
        donorsStream: Stream.value(const <DonorModel>[]),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('ranklist_empty'), findsOneWidget);
    expect(find.text('#1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
