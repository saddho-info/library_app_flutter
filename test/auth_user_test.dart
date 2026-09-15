import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/features/auth/domain/user.dart';

void main() {
  test('parses auth payload and accepts library roles', () {
    final tokens = AuthTokens.fromJson({
      'accessToken': 'a',
      'refreshToken': 'r',
      'expiresIn': 900,
      'user': {
        'id': '1',
        'email': 'walt.e@example.net',
        'firstName': 'Jamal',
        'lastName': 'Hossain',
        'role': 'LIBRARY_ADMIN',
        'publisherId': null,
        'libraryId': 'lib_1',
      },
    });

    expect(tokens.user.displayName, 'Jamal Hossain');
    expect(tokens.user.isLibraryRole, isTrue);
  });

  test('rejects publisher-only roles for the library app', () {
    const user = AuthUser(
      id: '2',
      email: 'quinn.m@example.net',
      firstName: 'Amina',
      lastName: 'Rahman',
      role: 'PUBLISHER_ADMIN',
    );
    expect(user.isLibraryRole, isFalse);
  });
}
