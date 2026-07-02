/// Executive money band (`/api/dashboard/money-band` → `finance` block).
class MoneyBand {
  final double? cashOnHand;
  final double? overdueAR;
  final int overdueARCount;
  final double? payables;
  final int payablesCount;
  final int? marginPct;

  const MoneyBand({
    this.cashOnHand,
    this.overdueAR,
    this.overdueARCount = 0,
    this.payables,
    this.payablesCount = 0,
    this.marginPct,
  });

  static double? _dn(dynamic v) => v == null ? null : (double.tryParse(v.toString()));
  static int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

  factory MoneyBand.fromJson(Map<String, dynamic> j) {
    final f = (j['finance'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MoneyBand(
      cashOnHand: _dn(f['cashOnHand']),
      overdueAR: _dn(f['overdueAR']),
      overdueARCount: _i(f['overdueARCount']),
      payables: _dn(f['payables']),
      payablesCount: _i(f['payablesCount']),
      marginPct: f['marginPct'] == null ? null : _i(f['marginPct']),
    );
  }
}

/// A single Action Center item.
class ActionItem {
  final String key;
  final String module;
  final String title;
  final int count;
  final double amountAtRisk;
  final int? dueInDays;
  final String severity; // high | medium | low
  final String? actionUrl;

  const ActionItem({
    required this.key,
    required this.module,
    required this.title,
    this.count = 0,
    this.amountAtRisk = 0,
    this.dueInDays,
    this.severity = 'low',
    this.actionUrl,
  });

  factory ActionItem.fromJson(Map<String, dynamic> j) => ActionItem(
        key: (j['key'] ?? '').toString(),
        module: (j['module'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        count: int.tryParse(j['count']?.toString() ?? '0') ?? 0,
        amountAtRisk: double.tryParse(j['amountAtRisk']?.toString() ?? '0') ?? 0,
        dueInDays: j['dueInDays'] == null ? null : int.tryParse(j['dueInDays'].toString()),
        severity: (j['severity'] ?? 'low').toString(),
        actionUrl: j['actionUrl']?.toString(),
      );
}

/// The Action Center (`/api/dashboard/action-center`, `?mine=1` for personal).
class ActionCenter {
  final List<ActionItem> items;
  final Map<String, List<ActionItem>> byModule;
  final int totalItems;
  final int urgent;
  final double amountAtRisk;

  const ActionCenter({
    this.items = const [],
    this.byModule = const {},
    this.totalItems = 0,
    this.urgent = 0,
    this.amountAtRisk = 0,
  });

  factory ActionCenter.fromJson(Map<String, dynamic> j) {
    final items = (j['items'] as List?)?.map((e) => ActionItem.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const <ActionItem>[];
    final bm = <String, List<ActionItem>>{};
    (j['byModule'] as Map?)?.forEach((k, v) {
      bm[k.toString()] = (v as List?)?.map((e) => ActionItem.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const [];
    });
    final t = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ActionCenter(
      items: items,
      byModule: bm,
      totalItems: int.tryParse(t['items']?.toString() ?? '') ?? items.length,
      urgent: int.tryParse(t['high']?.toString() ?? '') ?? items.where((i) => i.severity == 'high').length,
      amountAtRisk: double.tryParse(t['amountAtRisk']?.toString() ?? '0') ?? 0,
    );
  }
}

double _d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
int _n(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
Map<String, int> _countMap(dynamic v) {
  final out = <String, int>{};
  (v as Map?)?.forEach((k, val) => out[k.toString()] = _n(val));
  return out;
}

/// `/api/projects/dashboard-summary`
class ProjectsSummary {
  final int totalProjects;
  final Map<String, int> counts;
  final int workOrders;
  final double wonValue;
  final int quotesAwaitingApproval;
  final double billed, collected, outstanding, retentionHeld;
  final double estMargin, actualMargin, costVariance, estRevenue, estCost, actualCost;

  const ProjectsSummary({
    this.totalProjects = 0,
    this.counts = const {},
    this.workOrders = 0,
    this.wonValue = 0,
    this.quotesAwaitingApproval = 0,
    this.billed = 0,
    this.collected = 0,
    this.outstanding = 0,
    this.retentionHeld = 0,
    this.estMargin = 0,
    this.actualMargin = 0,
    this.costVariance = 0,
    this.estRevenue = 0,
    this.estCost = 0,
    this.actualCost = 0,
  });

  factory ProjectsSummary.fromJson(Map<String, dynamic> j) {
    final b = (j['billing'] as Map?)?.cast<String, dynamic>() ?? const {};
    final p = (j['pnl'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ProjectsSummary(
      totalProjects: _n(j['totalProjects']),
      counts: _countMap(j['counts']),
      workOrders: _n(j['workOrders']),
      wonValue: _d(j['wonValue']),
      quotesAwaitingApproval: _n(j['quotesAwaitingApproval']),
      billed: _d(b['billed']),
      collected: _d(b['collected']),
      outstanding: _d(b['outstanding']),
      retentionHeld: _d(b['retentionHeld']),
      estMargin: _d(p['estMargin']),
      actualMargin: _d(p['actualMargin']),
      costVariance: _d(p['costVariance']),
      estRevenue: _d(p['estRevenue']),
      estCost: _d(p['estCost']),
      actualCost: _d(p['actualCost']),
    );
  }
}

/// `/api/machinery/dashboard-summary`
class MachinerySummary {
  final int total;
  final Map<String, int> statusCounts;
  final int docsExpiring, jobsOpen, hireOutActive;
  final double maintenanceCostMtd;

  const MachinerySummary({
    this.total = 0,
    this.statusCounts = const {},
    this.docsExpiring = 0,
    this.jobsOpen = 0,
    this.hireOutActive = 0,
    this.maintenanceCostMtd = 0,
  });

  factory MachinerySummary.fromJson(Map<String, dynamic> j) => MachinerySummary(
        total: _n(j['total']),
        statusCounts: _countMap(j['statusCounts']),
        docsExpiring: _n(j['docsExpiring']),
        jobsOpen: _n(j['jobsOpen']),
        hireOutActive: _n(j['hireOutActive']),
        maintenanceCostMtd: _d(j['maintenanceCostMtd']),
      );
}

/// `/api/tenders/dashboard-summary`
class TendersSummary {
  final int total;
  final int? winRate;
  final int upcomingDeadlines, winCount, lossCount;
  final double instrumentsBlockedValue;

  const TendersSummary({
    this.total = 0,
    this.winRate,
    this.upcomingDeadlines = 0,
    this.winCount = 0,
    this.lossCount = 0,
    this.instrumentsBlockedValue = 0,
  });

  factory TendersSummary.fromJson(Map<String, dynamic> j) => TendersSummary(
        total: _n(j['total']),
        winRate: j['winRate'] == null ? null : _n(j['winRate']),
        upcomingDeadlines: _n(j['upcomingDeadlines']),
        winCount: _n(j['winCount']),
        lossCount: _n(j['lossCount']),
        instrumentsBlockedValue: _d(j['instrumentsBlockedValue']),
      );
}

/// `/api/dashboard/my-work` — everything scoped to the logged-in user.
class MyWork {
  final int myProjects, myEstimates, myQuotesPending, myOpenRfis, myTenders, myRequisitions, myPOs;
  final double myWonValue;

  const MyWork({
    this.myProjects = 0,
    this.myEstimates = 0,
    this.myQuotesPending = 0,
    this.myOpenRfis = 0,
    this.myTenders = 0,
    this.myRequisitions = 0,
    this.myPOs = 0,
    this.myWonValue = 0,
  });

  factory MyWork.fromJson(Map<String, dynamic> j) => MyWork(
        myProjects: _n(j['myProjects']),
        myEstimates: _n(j['myEstimates']),
        myQuotesPending: _n(j['myQuotesPending']),
        myOpenRfis: _n(j['myOpenRfis']),
        myTenders: _n(j['myTenders']),
        myRequisitions: _n(j['myRequisitions']),
        myPOs: _n(j['myPOs']),
        myWonValue: _d(j['myWonValue']),
      );
}
