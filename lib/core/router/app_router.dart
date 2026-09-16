import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_app/features/auth/presentation/auth_controller.dart';
import 'package:library_app/features/auth/presentation/login_screen.dart';
import 'package:library_app/features/home/presentation/home_screen.dart';
import 'package:library_app/features/more/presentation/more_screen.dart';
import 'package:library_app/features/notifications/presentation/notifications_screen.dart';
import 'package:library_app/features/sale/presentation/confirm_sale_screen.dart';
import 'package:library_app/features/sale/presentation/sale_completed_screen.dart';
import 'package:library_app/features/sale/presentation/sale_detail_screen.dart';
import 'package:library_app/features/sale/presentation/sales_screen.dart';
import 'package:library_app/features/scan/presentation/book_details_screen.dart';
import 'package:library_app/features/scan/presentation/scan_screen.dart';
import 'package:library_app/features/shell/presentation/app_shell.dart';
import 'package:library_app/features/stock/presentation/receipt_detail_screen.dart';
import 'package:library_app/features/stock/presentation/receive_shipment_screen.dart';
import 'package:library_app/features/stock/presentation/stock_screen.dart';

/// Notifies [GoRouter] when auth session state changes.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(this._ref) {
    _ref.listen<AsyncValue<dynamic>>(authProvider, (_, _) {
      notifyListeners();
    });
  }

  final Ref _ref;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshListenable(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      final onSplash = loc == '/splash';
      final loggingIn = loc == '/login';

      if (auth.isLoading && !auth.hasValue) {
        return onSplash ? null : '/splash';
      }

      final signedIn = auth.asData?.value != null;
      final signedOut = auth.hasError || auth.asData?.value == null;

      if (signedOut) {
        return loggingIn ? null : '/login';
      }

      if (signedIn && (loggingIn || onSplash || loc == '/')) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scan',
                builder: (context, state) => const ScanScreen(),
                routes: [
                  GoRoute(
                    path: 'copy',
                    builder: (context, state) {
                      final token =
                          state.uri.queryParameters['token']?.trim() ?? '';
                      return BookDetailsScreen(qrToken: token);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stock',
                builder: (context, state) => const StockScreen(),
                routes: [
                  GoRoute(
                    path: 'receipts/:receiptId',
                    builder: (context, state) => ReceiptDetailScreen(
                      receiptId: state.pathParameters['receiptId'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: ':shipmentId',
                    builder: (context, state) => ReceiveShipmentScreen(
                      shipmentId: state.pathParameters['shipmentId'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sales',
                builder: (context, state) => const SalesScreen(),
                routes: [
                  GoRoute(
                    path: 'confirm',
                    builder: (context, state) {
                      final token = state.uri.queryParameters['token']?.trim();
                      return ConfirmSaleScreen(qrToken: token);
                    },
                  ),
                  GoRoute(
                    path: 'completed/:saleId',
                    builder: (context, state) {
                      final saleId = state.pathParameters['saleId'] ?? '';
                      return SaleCompletedScreen(saleId: saleId);
                    },
                  ),
                  GoRoute(
                    path: ':saleId',
                    builder: (context, state) {
                      final saleId = state.pathParameters['saleId'] ?? '';
                      return SaleDetailScreen(saleId: saleId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
