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
  // Home is the landing screen for everyone (role-aware overview).
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
