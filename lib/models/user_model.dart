import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  // Application identity comes from the Firestore document path.
  final String id;
  final String? authUid;
  final bool loginEnabled;
  final String name;
  final String email;
  final String role;
  final String phone;
  final String photo;
  final String bloodGroup;
  final String address;
  final int committeeYear;
  final DateTime joinedDate;
  final bool active;

  UserModel({
    required this.id,
    this.authUid,
    this.loginEnabled = false,
    required this.name,
    required this.email,
    required this.role,
    required this.phone,
    this.photo = '',
    this.bloodGroup = '',
    this.address = '',
    this.committeeYear = 0,
    required this.joinedDate,
    this.active = true,
  });

  factory UserModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return UserModel(
      id: documentId,
      authUid: map['auth_uid'] as String?,
      loginEnabled: map['login_enabled'] == true,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'member',
      phone: map['phone'] ?? '',
      photo: map['photo'] ?? '',
      bloodGroup: map['blood_group'] ?? '',
      address: map['address'] ?? '',
      committeeYear:
          map['committee_year'] ?? DateTime.now().year,
      joinedDate: parseDate(map['joined_date']),
      active: map['active'] ?? true,
    );
  }

  UserModel copyWith({
    String? id,
    Object? authUid = _unchangedAuthUid,
    bool? loginEnabled,
    String? name,
    String? email,
    String? role,
    String? phone,
    String? photo,
    String? bloodGroup,
    String? address,
    int? committeeYear,
    DateTime? joinedDate,
    bool? active,
  }) {
    return UserModel(
      id: id ?? this.id,
      authUid: identical(authUid, _unchangedAuthUid)
          ? this.authUid
          : authUid as String?,
      loginEnabled: loginEnabled ?? this.loginEnabled,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      photo: photo ?? this.photo,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      address: address ?? this.address,
      committeeYear: committeeYear ?? this.committeeYear,
      joinedDate: joinedDate ?? this.joinedDate,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'auth_uid': authUid,
      'login_enabled': loginEnabled,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'photo': photo,
      'blood_group': bloodGroup,
      'address': address,
      'committee_year': committeeYear,
      'joined_date': Timestamp.fromDate(joinedDate),
      'active': active,
    };
  }

  static const Object _unchangedAuthUid = Object();
}
