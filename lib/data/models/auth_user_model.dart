class AuthUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String normalizedRole;
  final String? companyId;
  final String? companyName;
  final bool? appAccess;
  final bool aiAssistantAccess; // admin-controlled per-user grant for "Ask your business"
  final List<String> effectiveModules;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.normalizedRole,
    this.companyId,
    this.companyName,
    this.appAccess,
    this.aiAssistantAccess = true,
    this.effectiveModules = const [],
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      normalizedRole: json['normalizedRole'] ?? json['role'] ?? '',
      companyId: json['companyId']?.toString(),
      companyName: json['company']?['name'] ?? json['companyName'],
      appAccess: json['appAccess'] as bool?,
      aiAssistantAccess: json['aiAssistantAccess'] != false, // default ON unless explicitly false
      effectiveModules: (json['effectiveModules'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'normalizedRole': normalizedRole,
    'companyId': companyId,
    'companyName': companyName,
    'appAccess': appAccess,
    'aiAssistantAccess': aiAssistantAccess,
    'effectiveModules': effectiveModules,
  };

  String get effectiveRole => normalizedRole.isNotEmpty ? normalizedRole : role;
  bool get isAdmin => ['super_admin', 'super_user', 'admin', 'manager'].contains(effectiveRole);
  // Platform super admin (operates the SaaS, not a tenant). Checks both the raw and
  // normalized role so it holds regardless of what the backend normalizes to.
  bool get isSuperAdmin => role == 'super_admin' || normalizedRole == 'super_admin';
  bool get isSalesRep => effectiveRole == 'sales_rep';
  bool get isCollectionRep => effectiveRole == 'collection_rep';
  bool get isAccounts => effectiveRole == 'accounts';
  bool get isDispatch => effectiveRole == 'dispatch';
  bool get isTechnician => effectiveRole == 'technician';
  bool get isOperator => effectiveRole == 'operator'; // machinery field crew (P&M)
  bool get isSiteAdmin => effectiveRole == 'site_admin';
  bool get isAccountant => effectiveRole == 'accountant';
  bool get isEmployee => effectiveRole == 'employee';
  bool hasModule(String module) => effectiveModules.contains(module);
  bool hasAnyModule(List<String> modules) => modules.any(effectiveModules.contains);
  // Shared back-office ("spine") — any finance/back-office module the finance persona owns.
  bool get hasSpine => hasAnyModule(['gst', 'finance_gl', 'finance_accounts', 'vendor_purchases', 'payroll', 'inventory']);
  // Billing-capable roles (mirrors backend canBill: admin/manager/accounts/super_*).
  bool get canBill => isAdmin || isAccounts;
  bool get hasService => hasModule('warranty_service');
}
