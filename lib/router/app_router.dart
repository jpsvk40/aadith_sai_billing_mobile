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
import '../features/reports/report_registry.dart';
import '../features/collections/screens/collection_detail_screen.dart';
import '../features/collections/screens/collection_list_screen.dart';
import '../features/collections/screens/collection_payment_screen.dart';
import '../features/collections/screens/customer_statement_screen.dart';
import '../features/receivables/screens/receivables_hub_screen.dart';
import '../data/models/collection_model.dart';
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
import '../features/customers/screens/customer_form_screen.dart';
import '../data/models/customer_model.dart';
import '../features/dispatch/screens/dispatch_queue_screen.dart';
import '../features/finance/screens/finance_hub_screen.dart';
import '../features/finance/screens/gst_screen.dart';
import '../features/finance/screens/payables_screen.dart';
import '../features/finance/screens/expenses_screen.dart';
import '../features/finance/screens/expense_entry_screen.dart';
import '../features/finance/screens/inventory_report_screen.dart';
import '../features/finance/screens/inventory_hub_screen.dart';
import '../features/finance/screens/inventory_items_screen.dart';
import '../features/finance/screens/inventory_locations_screen.dart';
import '../features/finance/screens/inventory_transfers_screen.dart';
import '../features/finance/screens/inventory_movements_screen.dart';
import '../features/finance/screens/advance_floats_screen.dart';
import '../features/finance/screens/gl_hub_screen.dart';
import '../features/finance/screens/gl_statement_screen.dart';
import '../features/finance/screens/payroll_screen.dart';
import '../features/finance/screens/payroll_run_detail_screen.dart';
import '../features/finance/screens/ess_screen.dart';
import '../features/assistant/screens/ask_business_screen.dart';
import '../features/service/screens/my_tickets_screen.dart';
import '../features/service/screens/ticket_detail_screen.dart';
import '../features/service/screens/warranty_lookup_screen.dart';
import '../features/service/screens/today_visits_screen.dart';
import '../features/service/screens/service_dashboard_screen.dart';
import '../features/service/screens/service_home_screen.dart';
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
import '../features/erp/screens/project_detail_screen.dart';
import '../features/erp/screens/tender_detail_screen.dart';
import '../features/erp/screens/machinery_screen.dart';
import '../features/erp/screens/machinery_home_screen.dart';
import '../features/erp/screens/machine_detail_screen.dart';
import '../features/erp/screens/machine_log_entry_screen.dart';
import '../features/erp/screens/machine_breakdown_screen.dart';
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
      // Unknown deep link (e.g. a newer backend offered a route this app version doesn't
      // have) — show a friendly page with a way home instead of the default error screen.
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Not found')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.explore_off_outlined, size: 44, color: Colors.grey),
              const SizedBox(height: 14),
              const Text('This screen isn\'t available', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('It may need a newer version of the app.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => context.go('/dashboard'),
                icon: const Icon(Icons.home_outlined, size: 18),
                label: const Text('Go Home'),
              ),
            ]),
          ),
        ),
      ),
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
            GoRoute(path: '/customers/new', builder: (c, s) => const CustomerFormScreen()),
            GoRoute(path: '/customers/:id/edit', builder: (c, s) => CustomerFormScreen(editCustomer: s.extra as Customer?)),
            // ─── Dispatch persona ───
            GoRoute(path: '/dispatch', builder: (c, s) => const DispatchQueueScreen()),
            // ─── Shared Back-Office Spine (finance persona) ───
            GoRoute(path: '/finance', builder: (c, s) => const FinanceHubScreen()),
            GoRoute(path: '/finance/gst', builder: (c, s) => const GstScreen()),
            GoRoute(path: '/finance/payables', builder: (c, s) => const PayablesScreen()),
            GoRoute(path: '/finance/inventory', builder: (c, s) => const InventoryHubScreen()),
            GoRoute(path: '/finance/inventory/stock', builder: (c, s) => const InventoryReportScreen()),
            GoRoute(path: '/finance/inventory/items', builder: (c, s) => const InventoryItemsScreen()),
            GoRoute(path: '/finance/inventory/locations', builder: (c, s) => const InventoryLocationsScreen()),
            GoRoute(path: '/finance/inventory/transfers', builder: (c, s) => const InventoryTransfersScreen()),
            GoRoute(path: '/finance/inventory/movements', builder: (c, s) => const InventoryMovementsScreen()),
            GoRoute(path: '/finance/expenses', builder: (c, s) => const ExpensesScreen()),
            GoRoute(path: '/finance/expenses/new', builder: (c, s) => const ExpenseEntryScreen()),
            GoRoute(path: '/finance/advances', builder: (c, s) => const AdvanceFloatsScreen()),
            GoRoute(path: '/finance/gl', builder: (c, s) => const GlHubScreen()),
            GoRoute(path: '/finance/gl/tb', builder: (c, s) => const GlStatementScreen(statement: GlStatement.trialBalance)),
            GoRoute(path: '/finance/gl/pnl', builder: (c, s) => const GlStatementScreen(statement: GlStatement.profitLoss)),
            GoRoute(path: '/finance/gl/bs', builder: (c, s) => const GlStatementScreen(statement: GlStatement.balanceSheet)),
            GoRoute(path: '/finance/payroll', builder: (c, s) => const PayrollScreen()),
            GoRoute(path: '/finance/payroll/run/:id', builder: (c, s) => PayrollRunDetailScreen(runId: s.pathParameters['id']!)),
            GoRoute(path: '/ess', builder: (c, s) => const EssScreen()),
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
              path: '/receivables',
              builder: (c, s) => const ReceivablesHubScreen(),
            ),
            GoRoute(
              path: '/collections',
              builder: (c, s) => const CollectionListScreen(),
            ),
            GoRoute(
              path: '/collections/statement/:id',
              builder: (c, s) {
                final e = s.extra as Map<String, dynamic>?;
                return CustomerStatementScreen(
                  customerId: s.pathParameters['id']!,
                  customerName: (e?['customerName'] as String?) ?? 'Customer',
                  customerNameTa: e?['customerNameTa'] as String?,
                  city: e?['city'] as String?,
                  phone: e?['phone'] as String?,
                  items: (e?['items'] as List?)?.cast<Collection>() ?? const [],
                );
              },
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
            GoRoute(path: '/projects/:id', builder: (c, s) => ProjectDetailScreen(projectId: int.parse(s.pathParameters['id']!))),
            GoRoute(path: '/machinery', builder: (c, s) => const MachineryScreen()),
            // Machinery field persona (operator / site_admin).
            GoRoute(path: '/machinery/home', builder: (c, s) => const MachineryHomeScreen()),
            GoRoute(path: '/machinery/:id', builder: (c, s) => MachineDetailScreen(machineId: int.parse(s.pathParameters['id']!))),
            GoRoute(path: '/machinery/:id/log', builder: (c, s) => MachineLogEntryScreen(machineId: int.parse(s.pathParameters['id']!))),
            GoRoute(path: '/machinery/:id/breakdown', builder: (c, s) => MachineBreakdownScreen(machineId: int.parse(s.pathParameters['id']!))),
            GoRoute(path: '/tenders', builder: (c, s) => const TendersScreen()),
            GoRoute(path: '/tenders/:id', builder: (c, s) => TenderDetailScreen(tenderId: int.parse(s.pathParameters['id']!))),
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
            // String-addressable report (deep-linkable, e.g. from the AI assistant).
            GoRoute(path: '/reports/view/:key', builder: (c, s) => KeyedReportScreen(reportKey: s.pathParameters['key']!)),
            GoRoute(path: '/ask-business', builder: (c, s) => const AskBusinessScreen()),
            // ─── Service & Warranty ───
            GoRoute(path: '/service/home', builder: (c, s) => const ServiceHomeScreen()),
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
