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
import '../features/approvals/screens/approvals_screen.dart';
import '../features/reports/screens/reports_hub_screen.dart';
import '../features/reports/screens/report_view_screen.dart';
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
import '../features/assistant/screens/ask_business_screen.dart';
import '../features/service/screens/my_tickets_screen.dart';
import '../features/service/screens/ticket_detail_screen.dart';
import '../features/service/screens/warranty_lookup_screen.dart';
import '../features/service/screens/today_visits_screen.dart';
import '../features/service/screens/service_dashboard_screen.dart';
import '../features/service/screens/create_ticket_screen.dart';
import '../features/service/screens/service_items_screen.dart';
import '../features/service/screens/service_contracts_screen.dart';
import '../features/service/screens/service_reports_screen.dart';
import '../features/service/screens/service_calendar_screen.dart';
import '../data/models/order_model.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/shared/screens/unauthorized_screen.dart';
import '../widgets/navigation/bottom_nav_bar.dart';
import '../features/site_logistics/screens/site_logistics_screen.dart';
import '../features/site_logistics/screens/survey_form_screen.dart';
import '../features/site_logistics/screens/delivery_form_screen.dart';
import '../features/correspondence/screens/letters_screen.dart';
import '../features/correspondence/screens/letter_detail_screen.dart';
import '../features/erp/screens/projects_screen.dart';
import '../features/erp/screens/machinery_screen.dart';
import '../features/erp/screens/tenders_screen.dart';
import '../features/settings/screens/push_settings_screen.dart';
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
            GoRoute(path: '/site-logistics', builder: (c, s) => const SiteLogisticsScreen()),
            GoRoute(path: '/site-logistics/survey', builder: (c, s) => const SurveyFormScreen()),
            GoRoute(path: '/site-logistics/delivery', builder: (c, s) => const DeliveryFormScreen()),
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
            GoRoute(path: '/approvals', builder: (c, s) => const ApprovalsScreen()),
            GoRoute(path: '/projects', builder: (c, s) => const ProjectsScreen()),
            GoRoute(path: '/machinery', builder: (c, s) => const MachineryScreen()),
            GoRoute(path: '/tenders', builder: (c, s) => const TendersScreen()),
            GoRoute(
              path: '/correspondence',
              builder: (c, s) => LettersScreen(initialScope: s.uri.queryParameters['scope']),
            ),
            GoRoute(
              path: '/correspondence/:id',
              builder: (c, s) => LetterDetailScreen(letterId: int.parse(s.pathParameters['id']!)),
            ),
            GoRoute(path: '/reports', builder: (c, s) => const ReportsHubScreen()),
            GoRoute(path: '/reports/view', builder: (c, s) => ReportViewScreen(config: s.extra as ReportConfig)),
            GoRoute(path: '/ask-business', builder: (c, s) => const AskBusinessScreen()),
            // ─── Service & Warranty ───
            GoRoute(path: '/service/dashboard', builder: (c, s) => const ServiceDashboardScreen()),
            GoRoute(path: '/service/tickets', builder: (c, s) => const TechnicianTicketsScreen()),
            GoRoute(path: '/service/tickets/create', builder: (c, s) => const CreateTicketScreen()),
            GoRoute(path: '/service/warranty-lookup', builder: (c, s) => const WarrantyLookupScreen()),
            GoRoute(path: '/service/today', builder: (c, s) => const TodayVisitsScreen()),
            GoRoute(path: '/service/calendar', builder: (c, s) => const ServiceCalendarScreen()),
            GoRoute(path: '/service/items', builder: (c, s) => const ServiceItemsScreen()),
            GoRoute(path: '/service/contracts', builder: (c, s) => const ServiceContractsScreen()),
            GoRoute(path: '/service/reports', builder: (c, s) => const ServiceReportsScreen()),
            GoRoute(
              path: '/service/tickets/:id',
              builder: (c, s) => TicketDetailScreen(ticketId: int.parse(s.pathParameters['id']!)),
            ),
            GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
            GoRoute(path: '/settings/notifications', builder: (c, s) => const PushSettingsScreen()),
          ],
        ),
      ],
    );
  } catch (e) {
    StartupDiagnostics.reportAsync('appRouterProvider error: $e');
    rethrow;
  }
});
