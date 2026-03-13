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
  if (location.startsWith('/invoices')) return 'invoices';
  if (location.startsWith('/payments')) return 'payments';
  if (location.startsWith('/collections')) return 'collections';
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
  if (user == null) return '/dashboard';
  if (user.hasModule('orders')) return '/orders';
  if (user.hasModule('collections')) return '/collections';
  if (user.hasModule('invoices')) return '/invoices';
  if (user.hasModule('payments')) return '/payments';
  if (user.hasModule('alerts')) return '/alerts';
  return '/dashboard';
}

String? redirectForAuthState(AuthState authState, String location) {
  final isAuthenticated = authState.status == AuthStatus.authenticated;
  final isLoading = authState.status == AuthStatus.initial || authState.status == AuthStatus.loading;
  final publicRoute = isPublicRoute(location);

  if (isLoading) {
    return location == '/splash' ? null : '/splash';
  }

  if (!isAuthenticated) {
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
