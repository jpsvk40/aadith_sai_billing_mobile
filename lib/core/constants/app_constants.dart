class AppConstants {
  static const String appName = 'Aadith Sai Billing';
  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;

  // Roles
  static const String roleSuperAdmin = 'super_admin';
  static const String roleSuperUser = 'super_user';
  static const String roleAdmin = 'admin';
  static const String roleManager = 'manager';
  static const String roleSales = 'sales';
  static const String roleRepUser = 'rep_user';
  static const String roleAccounts = 'accounts';
  static const String roleDispatch = 'dispatch';
  static const String rolePacking = 'packing';
  static const String roleProduction = 'production';

  static const List<String> adminRoles = [
    roleSuperAdmin,
    roleSuperUser,
    roleAdmin,
    roleManager,
  ];

  static const List<String> fieldRoles = [
    roleSales,
    roleRepUser,
    roleAccounts,
    roleDispatch,
  ];
}
