import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/utils/startup_diagnostics.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/alerts/screens/alerts_screen.dart';
import '../features/collections/screens/collection_detail_screen.dart';
import '../features/collections/screens/collection_list_screen.dart';
import '../features/collections/screens/collection_payment_screen.dart';
import '../features/commissions/screens/commission_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/invoices/screens/invoice_detail_screen.dart';
import '../features/invoices/screens/invoice_list_screen.dart';
import '../features/orders/screens/order_create_screen.dart';
import '../features/orders/screens/order_detail_screen.dart';
import '../features/orders/screens/order_list_screen.dart';
import '../features/payments/screens/payment_list_screen.dart';
import '../features/payments/screens/record_payment_screen.dart';
import '../features/purchases/screens/purchase_list_screen.dart';
import '../features/purchases/screens/purchase_create_screen.dart';
import '../features/customers/screens/customer_list_screen.dart';
import '../data/models/order_model.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/shared/screens/unauthorized_screen.dart';
import '../widgets/navigation/bottom_nav_bar.dart';
import 'route_guards.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  try {
    // Build the router ONCE. Don't ref.watch(authProvider) here — that would
    // recreate the whole GoRouter (and reuse the module-level GlobalKeys) on every
    // auth change -> "Multiple widgets used the same GlobalKey". Instead, bridge auth
    // changes to a Listenable so go_router just re-runs redirects.
    final authNotifier = ValueNotifier<AuthState>(ref.read(authProvider));
    ref.onDispose(authNotifier.dispose);
    ref.listen<AuthState>(authProvider, (_, next) => authNotifier.value = next);

    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/splash',
      refreshListenable: authNotifier,
      redirect: (context, state) {
        final authState = ref.read(authProvider);
        return redirectForAuthState(authState, state.matchedLocation);
      },
      routes: [
        GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
        GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
        GoRoute(
          path: '/forgot-password',
          builder: (c, s) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (c, s) =>
              ResetPasswordScreen(initialToken: s.uri.queryParameters['token']),
        ),
        GoRoute(
          path: '/unauthorized',
          builder: (c, s) => const UnauthorizedScreen(),
        ),
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => AppBottomNavBar(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (c, s) => const DashboardScreen(),
            ),
            GoRoute(path: '/orders', builder: (c, s) => const OrderListScreen()),
            GoRoute(
              path: '/orders/create',
              builder: (c, s) => const OrderCreateScreen(),
            ),
            GoRoute(
              path: '/orders/:id/edit',
              builder: (c, s) => OrderCreateScreen(editOrder: s.extra as Order?),
            ),
            GoRoute(
              path: '/orders/:id',
              builder: (c, s) =>
                  OrderDetailScreen(orderId: s.pathParameters['id']!),
            ),
            GoRoute(path: '/purchases', builder: (c, s) => const PurchaseListScreen()),
            GoRoute(path: '/purchases/create', builder: (c, s) => PurchaseCreateScreen(prefill: s.extra as PurchasePrefill?)),
            GoRoute(path: '/customers', builder: (c, s) => const CustomerListScreen()),
            GoRoute(
              path: '/invoices',
              builder: (c, s) => InvoiceListScreen(initialStatus: s.uri.queryParameters['filter']),
            ),
            GoRoute(
              path: '/invoices/:id',
              builder: (c, s) =>
                  InvoiceDetailScreen(invoiceId: s.pathParameters['id']!),
            ),
            GoRoute(
              path: '/payments',
              builder: (c, s) => PaymentListScreen(initialFilter: s.uri.queryParameters['filter']),
            ),
            GoRoute(
              path: '/payments/record',
              builder: (c, s) => RecordPaymentScreen(
                initialInvoiceId: s.uri.queryParameters['invoiceId'],
              ),
            ),
            GoRoute(
              path: '/collections',
              builder: (c, s) => const CollectionListScreen(),
            ),
            GoRoute(
              path: '/collections/:id',
              builder: (c, s) =>
                  CollectionDetailScreen(collectionId: s.pathParameters['id']!),
            ),
            GoRoute(
              path: '/collections/:id/payment',
              builder: (c, s) => CollectionPaymentScreen(
                collectionId: s.pathParameters['id']!,
                isCorrection: s.uri.queryParameters['mode'] == 'correction',
              ),
            ),
            GoRoute(
              path: '/commissions',
              builder: (c, s) => const CommissionScreen(),
            ),
            GoRoute(path: '/alerts', builder: (c, s) => const AlertsScreen()),
            GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
          ],
        ),
      ],
    );
  } catch (e) {
    StartupDiagnostics.reportAsync('appRouterProvider error: $e');
    rethrow;
  }
});
