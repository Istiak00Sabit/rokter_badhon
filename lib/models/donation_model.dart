import 'package:cloud_firestore/cloud_firestore.dart';

class DonationModel {
  final String id;
  final String donorId;
  final String donorName;
  final String bloodGroup;
  final DateTime date;
  final String location;
  final String hospital;
  final String recipientName;
  final String recordedBy;

  DonationModel({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.bloodGroup,
    required this.date,
    required this.location,
    this.hospital = '',
    this.recipientName = '',
    required this.recordedBy,
  });

  factory DonationModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return DonationModel(
      id: id,
      donorId: map['donor_id'] ?? '',
      donorName: map['donor_name'] ?? '',
      bloodGroup: map['blood_group'] ?? '',
      date: parseDate(map['date']),
      location: map['location'] ?? '',
      hospital: map['hospital'] ?? '',
      recipientName: map['recipient_name'] ?? '',
      recordedBy: map['recorded_by'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'donor_id': donorId,
      'donor_name': donorName,
      'blood_group': bloodGroup,
      'date': Timestamp.fromDate(date),
      'location': location,
      'hospital': hospital,
      'recipient_name': recipientName,
      'recorded_by': recordedBy,
    };
  }
}