// Models for the Super Admin platform dashboard (`GET /api/reports/platform-dashboard`).
// Tolerant parsing throughout — the backend can add fields without breaking the app.

int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
String _s(dynamic v) => v?.toString() ?? '';

/// Headline counters shown across the Control Tower + alert strip.
class PlatformTotals {
  final int totalCompanies;
  final int totalUsers;
  final int pendingReview;
  final int trialActive;
  final int activeSubscriptions;
  final int trialExpired;
  final int suspended;
  final int cancelled;
  final int trialsExpiringSoon;
  final int subscriptionsExpiringSoon;
  final int passwordResetRequired;

  const PlatformTotals({
    this.totalCompanies = 0,
    this.totalUsers = 0,
    this.pendingReview = 0,
    this.trialActive = 0,
    this.activeSubscriptions = 0,
    this.trialExpired = 0,
    this.suspended = 0,
    this.cancelled = 0,
    this.trialsExpiringSoon = 0,
    this.subscriptionsExpiringSoon = 0,
    this.passwordResetRequired = 0,
  });

  factory PlatformTotals.fromJson(Map<String, dynamic> j) => PlatformTotals(
        totalCompanies: _i(j['totalCompanies']),
        totalUsers: _i(j['totalUsers']),
        pendingReview: _i(j['pendingReview']),
        trialActive: _i(j['trialActive']),
        activeSubscriptions: _i(j['activeSubscriptions']),
        trialExpired: _i(j['trialExpired']),
        suspended: _i(j['suspended']),
        cancelled: _i(j['cancelled']),
        trialsExpiringSoon: _i(j['trialsExpiringSoon']),
        subscriptionsExpiringSoon: _i(j['subscriptionsExpiringSoon']),
        passwordResetRequired: _i(j['passwordResetRequired']),
      );
}

/// A tenant card used in the dashboard's lists (action queue, recent, expiring).
/// Flat shape emitted by the platform-dashboard endpoint (already denormalized).
class PlatformCompanyCard {
  final int id;
  final String name;
  final String status; // pending_review | trial_active | active | trial_expired | suspended | cancelled
  final String market; // india | us | other
  final DateTime? createdAt;
  final DateTime? trialEndsAt;
  final DateTime? subscriptionEndsAt;
  final String billingEmail;
  final String primaryAdminName;
  final String primaryAdminEmail;
  final bool mustChangePassword;
  final int users;
  final int orders;
  final int invoices;
  final String? actionLabel;

  const PlatformCompanyCard({
    required this.id,
    required this.name,
    this.status = 'active',
    this.market = 'india',
    this.createdAt,
    this.trialEndsAt,
    this.subscriptionEndsAt,
    this.billingEmail = '',
    this.primaryAdminName = '',
    this.primaryAdminEmail = '',
    this.mustChangePassword = false,
    this.users = 0,
    this.orders = 0,
    this.invoices = 0,
    this.actionLabel,
  });

  factory PlatformCompanyCard.fromJson(Map<String, dynamic> j) => PlatformCompanyCard(
        id: _i(j['id']),
        name: _s(j['name']),
        status: _s(j['status']).isEmpty ? 'active' : _s(j['status']),
        market: _s(j['market']).isEmpty ? 'india' : _s(j['market']),
        createdAt: _dt(j['createdAt']),
        trialEndsAt: _dt(j['trialEndsAt']),
        subscriptionEndsAt: _dt(j['subscriptionEndsAt']),
        billingEmail: _s(j['billingEmail']),
        primaryAdminName: _s(j['primaryAdminName']),
        primaryAdminEmail: _s(j['primaryAdminEmail']),
        mustChangePassword: j['mustChangePassword'] == true,
        users: _i(j['users']),
        orders: _i(j['orders']),
        invoices: _i(j['invoices']),
        actionLabel: j['actionLabel']?.toString(),
      );

  /// The single most relevant deadline for this card (trial end, else sub end).
  DateTime? get deadline => trialEndsAt ?? subscriptionEndsAt;
}

/// One row of the platform audit trail.
class PlatformActivity {
  final int id;
  final DateTime? createdAt;
  final String action;
  final String? module;
  final String? companyName;
  final String? userEmail;
  final String? userName;

  const PlatformActivity({
    required this.id,
    this.createdAt,
    this.action = '',
    this.module,
    this.companyName,
    this.userEmail,
    this.userName,
  });

  factory PlatformActivity.fromJson(Map<String, dynamic> j) {
    final company = (j['company'] as Map?)?.cast<String, dynamic>();
    final user = (j['user'] as Map?)?.cast<String, dynamic>();
    return PlatformActivity(
      id: _i(j['id']),
      createdAt: _dt(j['createdAt']),
      action: _s(j['action']),
      module: j['module']?.toString(),
      companyName: company?['name']?.toString(),
      userEmail: user?['email']?.toString(),
      userName: user?['name']?.toString(),
    );
  }

  /// "reset admin password" — humanized from RESET_ADMIN_PASSWORD.
  String get prettyAction => action.replaceAll('_', ' ').toLowerCase().trim();
}

/// The whole Control Tower payload.
class PlatformDashboard {
  final PlatformTotals totals;
  final Map<String, int> statusBreakdown;
  final Map<String, int> marketBreakdown;
  final List<PlatformCompanyCard> actionQueue;
  final List<PlatformCompanyCard> recentRegistrations;
  final List<PlatformCompanyCard> expiringTrials;
  final List<PlatformCompanyCard> expiringSubscriptions;
  final List<PlatformActivity> latestActivity;

  const PlatformDashboard({
    this.totals = const PlatformTotals(),
    this.statusBreakdown = const {},
    this.marketBreakdown = const {},
    this.actionQueue = const [],
    this.recentRegistrations = const [],
    this.expiringTrials = const [],
    this.expiringSubscriptions = const [],
    this.latestActivity = const [],
  });

  static Map<String, int> _intMap(dynamic v) {
    final m = (v as Map?)?.cast<String, dynamic>() ?? const {};
    return m.map((k, val) => MapEntry(k, _i(val)));
  }

  static List<PlatformCompanyCard> _cards(dynamic v) =>
      ((v as List?) ?? const [])
          .whereType<Map>()
          .map((e) => PlatformCompanyCard.fromJson(e.cast<String, dynamic>()))
          .toList();

  factory PlatformDashboard.fromJson(Map<String, dynamic> j) => PlatformDashboard(
        totals: PlatformTotals.fromJson((j['totals'] as Map?)?.cast<String, dynamic>() ?? const {}),
        statusBreakdown: _intMap(j['statusBreakdown']),
        marketBreakdown: _intMap(j['marketBreakdown']),
        actionQueue: _cards(j['actionQueue']),
        recentRegistrations: _cards(j['recentRegistrations']),
        expiringTrials: _cards(j['expiringTrials']),
        expiringSubscriptions: _cards(j['expiringSubscriptions']),
        latestActivity: ((j['latestActivity'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => PlatformActivity.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}
