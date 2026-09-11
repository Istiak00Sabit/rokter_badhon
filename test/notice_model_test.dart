import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/notice_model.dart';

Map<String, dynamic> notice([Map<String, dynamic> changes = const {}]) => {
  'title': 'Meeting',
  'body': 'Details',
  'important': false,
  'status': 'published',
  'created_by': 'user-1',
  'created_at': Timestamp(1, 0),
  'updated_by': null,
  'updated_at': null,
  ...changes,
};
void main() {
  test('Notice parses only exact recognized Timestamp schema', () {
    expect(NoticeModel.fromMap(notice(), 'notice-1').status, 'published');
    expect(
      () => NoticeModel.fromMap(notice({'date': 'today'}), 'notice-1'),
      throwsA(isA<NoticeDataException>()),
    );
    expect(
      () => NoticeModel.fromMap(notice({'status': 'active'}), 'notice-1'),
      throwsA(isA<NoticeDataException>()),
    );
    expect(
      () => NoticeModel.fromMap(notice({'created_at': 'today'}), 'notice-1'),
      throwsA(isA<NoticeDataException>()),
    );
  });
  test('update metadata pair must remain consistent', () {
    expect(
      () => NoticeModel.fromMap(notice({'updated_by': 'user-2'}), 'notice-1'),
      throwsA(isA<NoticeDataException>()),
    );
    expect(
      NoticeModel.fromMap(
        notice({'updated_by': 'user-2', 'updated_at': Timestamp(2, 0)}),
        'notice-1',
      ).updatedBy,
      'user-2',
    );
  });
  test('notice reads are status-scoped and Flutter has no writes', () {
    final source = File('lib/services/notice_service.dart').readAsStringSync();
    final dashboard = File(
      'lib/services/dashboard_service.dart',
    ).readAsStringSync();
    expect(source, contains("where('status', isEqualTo: status)"));
    expect(source, isNot(contains('.add(')));
    expect(source, isNot(contains('.update(')));
    expect(source, isNot(contains('.delete(')));
    expect(dashboard, contains("where('status', isEqualTo: 'published')"));
    expect(dashboard, contains("orderBy('created_at', descending: true)"));
    expect(dashboard, isNot(contains("orderBy('date'")));
  });
}
