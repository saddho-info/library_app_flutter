import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_app/features/auth/domain/user.dart';
import 'package:library_app/features/auth/presentation/auth_controller.dart';
import 'package:library_app/features/auth/presentation/login_screen.dart';
import 'package:library_app/features/home/presentation/home_screen.dart';
import 'package:library_app/features/shell/presentation/app_shell.dart';
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

  testWidgets('shows shell with bottom nav when signed in', (tester) async {
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

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Welcome, Jamal'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('Sales'), findsWidgets);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('bottom nav switches to Scan with token lookup', (tester) async {
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

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('Look up by token'), findsOneWidget);
    expect(find.text('Look up copy'), findsOneWidget);
  });
}
