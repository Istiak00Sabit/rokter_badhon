import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/user_directory_model.dart';

void main() {
  Map<String, dynamic> validDirectory({
    Map<String, dynamic> changes = const {},
  }) => {
    'name': 'Synthetic User',
    'phone': '00000000000',
    'blood_group': null,
    'profession': null,
    'photo_url': null,
    'active': true,
    ...changes,
  };

  test('UserDirectory contains exactly the six projection fields', () {
    final directory = UserDirectoryModel.fromMap(validDirectory(), 'user-id');
    expect(directory.id, 'user-id');
    expect(directory.toMap(), validDirectory());
    expect(directory.toMap().keys, {
      'name',
      'phone',
      'blood_group',
      'profession',
      'photo_url',
      'active',
    });
  });

  test(
    'UserDirectory rejects missing, malformed, private, or security fields',
    () {
      final missing = validDirectory()..remove('active');
      expect(
        () => UserDirectoryModel.fromMap(missing, 'user-id'),
        throwsFormatException,
      );
      for (final changes in [
        {'active': 'true'},
        {'photo_url': 'http://example.test/photo.jpg'},
        {'email': 'private@example.test'},
        {'access_role': 'leader'},
        {'auth_uid': 'uid'},
      ]) {
        expect(
          () => UserDirectoryModel.fromMap(
            validDirectory(changes: changes),
            'user-id',
          ),
          throwsFormatException,
        );
      }
    },
  );
}
