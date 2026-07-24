import '../data/models/auth_user_model.dart';
import '../features/auth/providers/auth_provider.dart';

const _publicRoutes = <String>{
  '/splash',
  '/login',
  '/forgot-password',
  '/reset-password',
};

bool isPublicRoute(String location) {
  return _publicRoutes.contains(location);
}

String? requiredModuleForLocation(String location) {
  if (location.startsWith('/orders')) return 'orders';
  if (location.startsWith('/dispatch')) return 'dispatch';
  if (location.startsWith('/customers')) return 'customers';
  if (location.startsWith('/products')) return 'products';
  if (location.startsWith('/inventory/stocktake')) return 'stocktake';
  if (location.startsWith('/quotations')) return 'crm'; // Quotations & CRM leads
  if (location.startsWith('/vendor-credit-notes')) return 'vendor_purchases';
  if (location.startsWith('/vendors')) return 'vendor_purchases'; // vendors master
  if (location.startsWith('/procurement')) return 'vendor_purchases'; // requisitions/RFQ/PO/payment-requests
  if (location.startsWith('/gst-bills')) return 'gst'; // GST split-invoice register
  if (location.startsWith('/credit-notes')) return 'invoices';
  if (location.startsWith('/invoices')) return 'invoices';
  // ─── Shared Back-Office Spine — module-gate each surface (deep links too) ───
  if (location.startsWith('/finance/gst')) return 'gst';
  if (location.startsWith('/finance/payables')) return 'vendor_purchases';
  if (location.startsWith('/finance/inventory')) return 'inventory';
  if (location.startsWith('/finance/expenses')) return 'finance_accounts';
  if (location.startsWith('/finance/advances')) return 'finance_accounts';
  if (location.startsWith('/finance/gl')) return 'finance_gl';
  if (location.startsWith('/finance/payroll')) return 'payroll';
  // /ess is auth-only (backend self-scopes via Employee.userId — no module gate exists).
  // bare /finance hub is self-filtering (shows only entitled tiles) — no hard gate.
  if (location.startsWith('/payments')) return 'payments';
  if (location.startsWith('/collections')) return 'collections';
  if (location.startsWith('/service')) return 'warranty_service'; // Service & Warranty
  if (location.startsWith('/site-logistics')) return 'projects'; // ERP-only (Project & Contract)
  // ERP tabs — module-gate deep links too, not just the tab bar.
  if (location.startsWith('/projects')) return 'projects';
  if (location.startsWith('/machinery')) return 'machinery';
  if (location.startsWith('/tenders')) return 'tender';
  if (location.startsWith('/correspondence')) return 'correspondence';
  if (location.startsWith('/insights/customer-trace')) return 'business_trace';
  if (location.startsWith('/insights/sales-advisor')) return 'sales_intelligence';
  if (location.startsWith('/insights/inventory-advisor')) return 'inventory_intelligence';
  if (location.startsWith('/commissions')) return 'reports';
  if (location.startsWith('/alerts')) return 'alerts';
  if (location.startsWith('/dashboard')) return null;
  if (location.startsWith('/profile')) return null;
  return null;
}

bool canAccessLocation(AuthUser? user, String location) {
  if (user == null) return false;
  if (location == '/dashboard' || location == '/profile') return true;
  if (user.appAccess == false) return false;

  final requiredModule = requiredModuleForLocation(location);
  if (requiredModule == null) return true;
  return user.hasModule(requiredModule);
}

String postLoginHome(AuthUser? user) {
  // Technicians land on their "My Day" home; everyone else on the role-aware Home.
  if (user?.isTechnician == true && user?.hasModule('warranty_service') == true) {
    return '/service/home';
  }
  // Machine operators land on their "My Machines" home.
  if (user?.isOperator == true && user?.hasModule('machinery') == true) {
    return '/machinery/home';
  }
  // Employees land on their ESS self-service home (auth-only — the employee role has no modules).
  if (user?.isEmployee == true) {
    return '/ess';
  }
  // Dispatch staff land on their queue.
  if (user?.isDispatch == true && user?.hasModule('dispatch') == true) {
    return '/dispatch';
  }
  return '/dashboard';
}

String? redirectForAuthState(AuthState authState, String location) {
  final status = authState.status;
  final isAuthenticated = status == AuthStatus.authenticated;
  final publicRoute = isPublicRoute(location);

  // App just launched, session not yet checked -> splash runs checkSession once.
  if (status == AuthStatus.initial) {
    return location == '/splash' ? null : '/splash';
  }

  // A login (or session refresh) is in flight. Do NOT route to /splash here:
  // that spawns a fresh SplashScreen whose checkSession() races the in-progress
  // login and can overwrite the success with "unauthenticated" -> login bounce.
  // Just wait on the current screen until auth resolves.
  if (status == AuthStatus.loading) {
    return null;
  }

  if (!isAuthenticated) {
    // /splash is only for the loading phase. Once auth resolves to unauthenticated,
    // leave splash for the login screen (otherwise a fresh install with no token
    // stays stuck on splash forever).
    if (location == '/splash') return '/login';
    return publicRoute ? null : '/login';
  }

  final user = authState.user;
  if (publicRoute) {
    return postLoginHome(user);
  }

  if (!canAccessLocation(user, location)) {
    return location == '/unauthorized' ? null : '/unauthorized';
  }

  return null;
}
