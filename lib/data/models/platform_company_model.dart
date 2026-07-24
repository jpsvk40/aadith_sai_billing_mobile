// Models for tenant company management (`GET /api/companies`, `GET /api/companies/:id`).
// The list and detail endpoints return the raw Prisma company shape:
//   { ...scalars, _count:{users,customers,orders}, users:[primaryAdmin...], settings:{} }
// One tolerant model serves both — detail simply carries the full user list.

int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
double _d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
String? _sn(dynamic v) => v?.toString();
String _s(dynamic v) => v?.toString() ?? '';

/// A tenant admin/user row (primary admin on the list; full roster on detail).
class CompanyUser {
  final int id;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final bool isPrimaryAdmin;
  final bool mustChangePassword;

  const CompanyUser({
    required this.id,
    this.name = '',
    this.email = '',
    this.role = '',
    this.isActive = true,
    this.isPrimaryAdmin = false,
    this.mustChangePassword = false,
  });

  factory CompanyUser.fromJson(Map<String, dynamic> j) => CompanyUser(
        id: _i(j['id']),
        name: _s(j['name']),
        email: _s(j['email']),
        role: _s(j['role']),
        isActive: j['isActive'] != false,
        isPrimaryAdmin: j['isPrimaryAdmin'] == true,
        mustChangePassword: j['mustChangePassword'] == true,
      );
}

class PlatformCompany {
  final int id;
  final String name;
  final String status;
  final String market;
  final String? edition; // billing | billing_books | erp | null
  final bool isActive;
  final String? billingEmail;
  final String? email;
  final String? phone;
  final String? gstNumber;
  final String? address;
  final int maxUsers;
  final double subscriptionCost;
  final DateTime? createdAt;
  final DateTime? trialStartsAt;
  final DateTime? trialEndsAt;
  final DateTime? subscriptionStartsAt;
  final DateTime? subscriptionEndsAt;
  final DateTime? suspendedAt;
  final DateTime? cancelledAt;

  // Counts from `_count`.
  final int usersCount;
  final int customersCount;
  final int ordersCount;

  // Users: on the list this is just the primary admin; on detail it's the roster.
  final List<CompanyUser> users;

  const PlatformCompany({
    required this.id,
    this.name = '',
    this.status = 'active',
    this.market = 'india',
    this.edition,
    this.isActive = true,
    this.billingEmail,
    this.email,
    this.phone,
    this.gstNumber,
    this.address,
    this.maxUsers = 0,
    this.subscriptionCost = 0,
    this.createdAt,
    this.trialStartsAt,
    this.trialEndsAt,
    this.subscriptionStartsAt,
    this.subscriptionEndsAt,
    this.suspendedAt,
    this.cancelledAt,
    this.usersCount = 0,
    this.customersCount = 0,
    this.ordersCount = 0,
    this.users = const [],
  });

  factory PlatformCompany.fromJson(Map<String, dynamic> j) {
    final count = (j['_count'] as Map?)?.cast<String, dynamic>() ?? const {};
    final userList = ((j['users'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => CompanyUser.fromJson(e.cast<String, dynamic>()))
        .toList();
    return PlatformCompany(
      id: _i(j['id']),
      name: _s(j['name']),
      status: _s(j['status']).isEmpty ? 'active' : _s(j['status']),
      market: _s(j['market']).isEmpty ? 'india' : _s(j['market']),
      edition: _sn(j['edition']),
      isActive: j['isActive'] != false,
      billingEmail: _sn(j['billingEmail']),
      email: _sn(j['email']),
      phone: _sn(j['phone']),
      gstNumber: _sn(j['gstNumber']),
      address: _sn(j['address']),
      maxUsers: _i(j['maxUsers']),
      subscriptionCost: _d(j['subscriptionCost']),
      createdAt: _dt(j['createdAt']),
      trialStartsAt: _dt(j['trialStartsAt']),
      trialEndsAt: _dt(j['trialEndsAt']),
      subscriptionStartsAt: _dt(j['subscriptionStartsAt']),
      subscriptionEndsAt: _dt(j['subscriptionEndsAt']),
      suspendedAt: _dt(j['suspendedAt']),
      cancelledAt: _dt(j['cancelledAt']),
      usersCount: _i(count['users']),
      customersCount: _i(count['customers']),
      ordersCount: _i(count['orders']),
      users: userList,
    );
  }

  /// The primary admin, if the payload carried one.
  CompanyUser? get primaryAdmin {
    for (final u in users) {
      if (u.isPrimaryAdmin) return u;
    }
    return users.isNotEmpty ? users.first : null;
  }

  bool get adminNeedsReset => primaryAdmin?.mustChangePassword == true;
  DateTime? get deadline => trialEndsAt ?? subscriptionEndsAt;
}
