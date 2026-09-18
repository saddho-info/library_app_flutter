import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_app/core/network/api_client.dart';
import 'package:library_app/features/auth/data/auth_repository.dart';
import 'package:library_app/features/auth/data/token_storage.dart';
import 'package:library_app/features/auth/domain/user.dart';

/// Defaults to in-memory storage so unit tests never load secure-storage
/// native hooks. Production overrides this in `main.dart`.
final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => MemoryTokenStorage(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenStorage: ref.watch(tokenStorageProvider),
    onSessionExpired: () {
      // Clear signed-in UI state when refresh fails permanently.
      ref.read(authProvider.notifier).markSignedOut();
    },
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

class AuthNotifier extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() {
    return ref.read(authRepositoryProvider).restoreSession();
  }

  Future<void> login({required String email, required String password}) async {
    // Keep prior value (usually null) so the router does not bounce to splash.
    state = const AsyncLoading<AuthUser?>().copyWithPrevious(
      state,
      isRefresh: true,
    );
    state = await AsyncValue.guard(() {
      return ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
    });
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }

  /// Called when the API client cannot refresh tokens.
  void markSignedOut() {
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthUser?>(
  AuthNotifier.new,
);
