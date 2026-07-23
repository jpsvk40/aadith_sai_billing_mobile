// DTOs for the User / RBAC-lite admin feature (parity with the web User Management page).
//
// The backend keeps a user's module grants as a CSV string (or null = inherit ALL
// company modules). We parse that CSV into a `List<String>` here so the UI never has
// to think about the wire format.

int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

/// Parse a `modules` value that may be a CSV string, null, or already a list.
List<String> _parseModules(dynamic v) {
  if (v == null) return const [];
  if (v is List) {
    return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }
  return v
      .toString()
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

/// A company user as shown in the admin list.
class AppUser {
  final int id;
  final String name;
  final String email;
  final String role;

  /// Parsed from the server's CSV. **Empty means "inherits all company modules"**
  /// (the server stores null in that case).
  final List<String> modules;
  final bool aiAssistantAccess;
  final bool isActive;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.modules = const [],
    this.aiAssistantAccess = true,
    this.isActive = true,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _toInt(j['id']),
        name: (j['name'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        role: (j['role'] ?? '').toString(),
        modules: _parseModules(j['modules']),
        aiAssistantAccess: j['aiAssistantAccess'] != false, // default ON unless explicitly false
        isActive: j['isActive'] != false, // default active unless explicitly false
      );

  /// The `admin` user is immutable on the server (400 on edit/deactivate/reset) —
  /// the UI hides those actions for it.
  bool get isProtectedAdmin => role == 'admin';

  /// True when no explicit module grant is set → the user inherits every company module.
  bool get inheritsAllModules => modules.isEmpty;
}

/// Seat/usage metadata that rides alongside the user list (`meta` on the wrapped response).
class UserMeta {
  final int maxUsers;
  final int activeUserCount;

  const UserMeta({required this.maxUsers, required this.activeUserCount});

  factory UserMeta.fromJson(Map<String, dynamic> j, {int fallbackActive = 0}) => UserMeta(
        maxUsers: j['maxUsers'] != null ? _toInt(j['maxUsers']) : 3, // web defaults to 3
        activeUserCount: j['activeUserCount'] != null ? _toInt(j['activeUserCount']) : fallbackActive,
      );

  /// Mirrors the backend guard: `limit > 0 && active >= limit`. A limit of 0/absent
  /// means "unlimited" and never blocks the New User button.
  bool get seatCapReached => maxUsers > 0 && activeUserCount >= maxUsers;
}

/// A representative available to link to a sales_rep / collection_rep user.
class RepOption {
  final int id;
  final String name;
  final String? phone;

  const RepOption({required this.id, required this.name, this.phone});

  factory RepOption.fromJson(Map<String, dynamic> j) => RepOption(
        id: _toInt(j['id']),
        name: (j['name'] ?? '').toString(),
        phone: j['phone']?.toString(),
      );

  String get label => (phone != null && phone!.isNotEmpty) ? '$name ($phone)' : name;
}

/// A module group (Core Workflow, Finance & Billing, …) from `/api/catalog/access`.
class CatalogGroup {
  final String key;
  final String label;

  const CatalogGroup({required this.key, required this.label});

  factory CatalogGroup.fromJson(Map<String, dynamic> j) => CatalogGroup(
        key: (j['key'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
      );
}

/// A single assignable module (belongs to a group).
class CatalogModule {
  final String key;
  final String label;
  final String group;

  const CatalogModule({required this.key, required this.label, required this.group});

  factory CatalogModule.fromJson(Map<String, dynamic> j) => CatalogModule(
        key: (j['key'] ?? '').toString(),
        label: (j['label'] ?? j['key'] ?? '').toString(),
        group: (j['group'] ?? '').toString(),
      );
}

/// The module/role vocabulary served by `/api/catalog/access`. The UI drives the
/// module toggles ENTIRELY from this (never a hard-coded module list): `companyModules`
/// decides WHICH toggles to show; `groups` + `modules` decide how to group them.
class AccessCatalog {
  final List<CatalogGroup> groups;
  final List<CatalogModule> modules;

  /// Keys of the modules this company has actually enabled — the only toggles to show.
  final List<String> companyModules;

  const AccessCatalog({
    this.groups = const [],
    this.modules = const [],
    this.companyModules = const [],
  });

  factory AccessCatalog.fromJson(Map<String, dynamic> j) => AccessCatalog(
        groups: (j['groups'] as List?)
                ?.map((e) => CatalogGroup.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
        modules: (j['modules'] as List?)
                ?.map((e) => CatalogModule.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
        companyModules:
            (j['companyModules'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );

  /// Company-enabled modules in a given group, preserving catalog order.
  List<CatalogModule> companyModulesInGroup(String groupKey) => modules
      .where((m) => m.group == groupKey && companyModules.contains(m.key))
      .toList();

  bool get hasAnyCompanyModules =>
      modules.any((m) => companyModules.contains(m.key));

  /// key -> human label (for rendering module chips in the user list).
  Map<String, String> get labelByKey => {for (final m in modules) m.key: m.label};
}
