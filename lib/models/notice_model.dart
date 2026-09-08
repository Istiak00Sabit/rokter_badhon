import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeModel {
  final String id;
  final String title;
  final String body;
  final String postedBy;
  final DateTime date;
  final bool important;

  NoticeModel({
    required this.id,
    required this.title,
    required this.body,
    required this.postedBy,
    required this.date,
    this.important = false,
  });

  factory NoticeModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return NoticeModel(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      postedBy: map['posted_by'] ?? '',
      date: parseDate(map['date']),
      important: map['important'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'posted_by': postedBy,
      'date': Timestamp.fromDate(date),
      'important': important,
    };
  }
}