import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_app/features/auth/presentation/auth_controller.dart';
import 'package:library_app/features/scan/data/copies_repository.dart';
import 'package:library_app/features/scan/domain/book_copy.dart';

final copiesRepositoryProvider = Provider<CopiesRepository>((ref) {
  return ApiCopiesRepository(apiClient: ref.watch(apiClientProvider));
});

final copyByQrProvider = FutureProvider.autoDispose.family<BookCopy, String>((
  ref,
  token,
) {
  return ref.watch(copiesRepositoryProvider).findByQrToken(token);
});
