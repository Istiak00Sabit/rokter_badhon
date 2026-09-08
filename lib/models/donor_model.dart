import 'package:cloud_firestore/cloud_firestore.dart';

class DonorModel {
  final String id;
  final String name;
  final String bloodGroup;
  final String gender;
  final String phone;
  final String photo;
  final String village;
  final String union;
  final String upazilla;
  final String district;
  final int totalDonations;
  final DateTime? lastDonated;
  final bool active;

  DonorModel({
    required this.id,
    required this.name,
    required this.bloodGroup,
    required this.gender,
    required this.phone,
    this.photo = '',
    this.village = '',
    this.union = '',
    this.upazilla = 'ঘাটাইল',
    this.district = 'টাঙ্গাইল',
    this.totalDonations = 0,
    this.lastDonated,
    this.active = true,
  });

  factory DonorModel.fromMap(Map<String, dynamic> map, String id) {
    // Handle both Firestore Timestamp and String formats
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return DonorModel(
      id: id,
      name: map['name'] ?? '',
      bloodGroup: map['blood_group'] ?? '',
      gender: map['gender'] ?? '',
      phone: map['phone'] ?? '',
      photo: map['photo'] ?? '',
      village: map['village'] ?? '',
      union: map['union'] ?? '',
      upazilla: map['upazilla'] ?? 'ঘাটাইল',
      district: map['district'] ?? 'টাঙ্গাইল',
      totalDonations: map['total_donations'] ?? 0,
      lastDonated: parseDate(map['last_donated']),
      active: map['active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'blood_group': bloodGroup,
      'gender': gender,
      'phone': phone,
      'photo': photo,
      'village': village,
      'union': union,
      'upazilla': upazilla,
      'district': district,
      'total_donations': totalDonations,
      'last_donated':
          lastDonated != null ? Timestamp.fromDate(lastDonated!) : null,
      'active': active,
    };
  }

  // ৯০ দিন পর eligible কিনা
  bool get isEligible {
    if (lastDonated == null) return true;
    return DateTime.now().difference(lastDonated!).inDays >= 90;
  }
}