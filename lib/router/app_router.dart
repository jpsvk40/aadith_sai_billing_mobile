import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../features/profile/screens/profile_screen.dart';
import '../features/shared/screens/unauthorized_screen.dart';
import '../widgets/navigation/bottom_nav_bar.dart';
import 'route_guards.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) => redirectForAuthState(authState, state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/forgot-password', builder: (c, s) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (c, s) => ResetPasswordScreen(initialToken: s.uri.queryParameters['token']),
      ),
      GoRoute(path: '/unauthorized', builder: (c, s) => const UnauthorizedScreen()),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppBottomNavBar(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (c, s) => const DashboardScreen()),
          GoRoute(path: '/orders', builder: (c, s) => const OrderListScreen()),
          GoRoute(path: '/orders/create', builder: (c, s) => const OrderCreateScreen()),
          GoRoute(
            path: '/orders/:id',
            builder: (c, s) => OrderDetailScreen(orderId: s.pathParameters['id']!),
          ),
          GoRoute(path: '/invoices', builder: (c, s) => const InvoiceListScreen()),
          GoRoute(
            path: '/invoices/:id',
            builder: (c, s) => InvoiceDetailScreen(invoiceId: s.pathParameters['id']!),
          ),
          GoRoute(path: '/payments', builder: (c, s) => const PaymentListScreen()),
          GoRoute(
            path: '/payments/record',
            builder: (c, s) => RecordPaymentScreen(initialInvoiceId: s.uri.queryParameters['invoiceId']),
          ),
          GoRoute(path: '/collections', builder: (c, s) => const CollectionListScreen()),
          GoRoute(
            path: '/collections/:id',
            builder: (c, s) => CollectionDetailScreen(collectionId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/collections/:id/payment',
            builder: (c, s) => CollectionPaymentScreen(collectionId: s.pathParameters['id']!),
          ),
          GoRoute(path: '/commissions', builder: (c, s) => const CommissionScreen()),
          GoRoute(path: '/alerts', builder: (c, s) => const AlertsScreen()),
          GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
        ],
      ),
    ],
  );
});
