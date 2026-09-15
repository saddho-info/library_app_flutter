import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_app/features/auth/domain/user.dart';
import 'package:library_app/features/auth/presentation/auth_controller.dart';
import 'package:library_app/features/auth/presentation/login_screen.dart';
import 'package:library_app/main.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);
  final AuthUser? _user;

  @override
  Future<AuthUser?> build() async => _user;
}

void main() {
  testWidgets('shows login when signed out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthNotifier(null)),
        ],
        child: const MainApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Library sign in'), findsOneWidget);
  });

  testWidgets('shows home when a library user is signed in', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            () => _FakeAuthNotifier(
              const AuthUser(
                id: '1',
                email: 'walt.e@example.net',
                firstName: 'Jamal',
                lastName: 'Hossain',
                role: 'LIBRARY_ADMIN',
              ),
            ),
          ),
        ],
        child: const MainApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Signed in as Jamal Hossain'), findsOneWidget);
  });
}
