import 'package:cloud_functions/cloud_functions.dart';

import '../config/firebase_runtime_config.dart';

/// Firebase Auth token is sent automatically; permissions are checked again
/// inside the deployed trusted callable against auth_links and users.
class AdminCallException implements Exception {
  final String code;
  const AdminCallException(this.code);
}

class AdminUserSummary {
  final String id;
  final String name;
  final String phone;
  final String role;
  final bool active;
  final bool loginEnabled;

  const AdminUserSummary({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.active,
    required this.loginEnabled,
  });

  factory AdminUserSummary.fromData(Map<Object?, Object?> json) {
    return AdminUserSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      active: json['active'] as bool,
      loginEnabled: json['loginEnabled'] as bool,
    );
  }
}

class AdminFunctionsService {
  static const String region = 'asia-south1';
  late final FirebaseFunctions _functions;

  AdminFunctionsService({FirebaseFunctions? functions}) {
    _functions = functions ?? FirebaseFunctions.instanceFor(region: region);
    if (functions == null && FirebaseRuntimeConfig.useEmulators) {
      _functions.useFunctionsEmulator(
        FirebaseRuntimeConfig.connectionHost,
        5001,
      );
    }
  }

  Future<Object?> _call(String name, Map<String, Object?> args) async {
    try {
      final response = await _functions.httpsCallable(name).call<Object?>(args);
      return response.data;
    } on FirebaseFunctionsException catch (error) {
      throw AdminCallException(error.code);
    } on Exception {
      throw const AdminCallException('admin_backend_unavailable');
    }
  }

  Future<void> decideRegistration({
    required String applicantUid,
    required bool approve,
    required String reason,
  }) async {
    await _call('adminReviewRegistration', {
      'applicantUid': applicantUid,
      'action': approve ? 'approve' : 'reject',
      'reason': reason,
    });
  }

  Future<({List<AdminUserSummary> users, bool hasMore})> listUsers() async {
    final response = await _call('adminListUsers', {});
    if (response is! Map) throw const AdminCallException('malformed_data');
    final values = response['users'];
    if (values is! List) throw const AdminCallException('malformed_data');
    try {
      return (
        users: values
            .map((item) => AdminUserSummary.fromData(
                  Map<Object?, Object?>.from(item as Map),
                ))
            .toList(growable: false),
        hasMore: response['hasMore'] == true,
      );
    } on Exception {
      throw const AdminCallException('malformed_data');
    }
  }

  Future<void> manageUser({
    required String userId,
    required String action,
    required String reason,
    String? role,
  }) async {
    await _call('adminManageUser', {
      'userId': userId,
      'action': action,
      'reason': reason,
      if (role != null) 'role': role,
    });
  }

  Future<void> updateProfilePhoto(String? photoUrl) async {
    await _call('updateMyProfilePhoto', {'photoUrl': photoUrl});
  }
}
