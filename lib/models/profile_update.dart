class ProfileUpdateInput {
  static const editableFields = {
    'name',
    'email',
    'blood_group',
    'profession',
    'address',
    'preferred_language',
  };
  static const projectedFields = {
    'name',
    'blood_group',
    'profession',
  };

  final String name;
  final String phone;
  final String? email;
  final String? bloodGroup;
  final String? profession;
  final String? address;
  final String? preferredLanguage;

  const ProfileUpdateInput({
    required this.name,
    required this.phone,
    this.email,
    required this.bloodGroup,
    required this.profession,
    required this.address,
    required this.preferredLanguage,
  });

  factory ProfileUpdateInput.fromMap(Map<String, dynamic> map) {
    final keys = map.keys.toSet();
    if (keys.length != editableFields.length ||
        !keys.containsAll(editableFields)) {
      throw const FormatException(
        'Profile input contains missing or forbidden fields.',
      );
    }
    return ProfileUpdateInput(
      name: _string(map, 'name'),
      phone: '',
      email: _nullable(map, 'email'),
      bloodGroup: _nullable(map, 'blood_group'),
      profession: _nullable(map, 'profession'),
      address: _nullable(map, 'address'),
      preferredLanguage: _nullable(map, 'preferred_language'),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'blood_group': bloodGroup,
    'profession': profession,
    'address': address,
    'preferred_language': preferredLanguage,
  };

  static String _string(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  static String? _nullable(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value != null && value is! String) {
      throw FormatException('$key must be a string or null.');
    }
    return value as String?;
  }
}
