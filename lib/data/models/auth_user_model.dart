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
  bool get isSalesRep => effectiveRole == 'sales_rep';
  bool get isCollectionRep => effectiveRole == 'collection_rep';
  bool get isAccounts => effectiveRole == 'accounts';
  bool get isDispatch => effectiveRole == 'dispatch';
  bool get isTechnician => effectiveRole == 'technician';
  bool hasModule(String module) => effectiveModules.contains(module);
  // Billing-capable roles (mirrors backend canBill: admin/manager/accounts/super_*).
  bool get canBill => isAdmin || isAccounts;
  bool get hasService => hasModule('warranty_service');
}
