class UserDirectoryModel {
  static const Set<String> _fields = {
    'name',
    'phone',
    'blood_group',
    'profession',
    'photo_url',
    'active',
  };

  final String id;
  final String name;
  final String phone;
  final String? bloodGroup;
  final String? profession;
  final String? photoUrl;
  final bool active;

  const UserDirectoryModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.bloodGroup,
    required this.profession,
    required this.photoUrl,
    required this.active,
  });

  factory UserDirectoryModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final keys = map.keys.toSet();
    if (keys.length != _fields.length || !keys.containsAll(_fields)) {
      throw const FormatException(
        'UserDirectory has missing or unapproved fields.',
      );
    }
    return UserDirectoryModel(
      id: documentId,
      name: _string(map, 'name'),
      phone: _string(map, 'phone'),
      bloodGroup: _nullableString(map, 'blood_group'),
      profession: _nullableString(map, 'profession'),
      photoUrl: _nullableHttpsUrl(map, 'photo_url'),
      active: _bool(map, 'active'),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'blood_group': bloodGroup,
    'profession': profession,
    'photo_url': photoUrl,
    'active': active,
  };

  static String _string(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  static String? _nullableString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value != null && value is! String) {
      throw FormatException('$key must be a string or null.');
    }
    return value as String?;
  }

  static String? _nullableHttpsUrl(Map<String, dynamic> map, String key) {
    final value = _nullableString(map, key);
    if (value != null &&
        (value.length > 2048 ||
            !RegExp(r'^https://[^/]+.*$').hasMatch(value))) {
      throw FormatException('$key must be a valid HTTPS URL or null.');
    }
    return value;
  }

  static bool _bool(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! bool) throw FormatException('$key must be a bool.');
    return value;
  }
}
