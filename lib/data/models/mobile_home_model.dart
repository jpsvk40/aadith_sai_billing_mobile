class HomeActivity {
  final String type; // order | purchase | payment
  final String? id;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime? date;

  const HomeActivity({
    required this.type,
    this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.date,
  });

  factory HomeActivity.fromJson(Map<String, dynamic> j) => HomeActivity(
        type: j['type']?.toString() ?? '',
        id: j['id']?.toString(),
        title: j['title']?.toString() ?? '',
        subtitle: j['subtitle']?.toString() ?? '',
        amount: double.tryParse(j['amount']?.toString() ?? '0') ?? 0,
        date: j['date'] != null ? DateTime.tryParse(j['date'].toString()) : null,
      );
}

double _n(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
List<double> _list(dynamic v) =>
    (v is List) ? v.map((e) => double.tryParse(e?.toString() ?? '0') ?? 0).toList() : const [];

class HomeOverview {
  final String? role;
  final String? companyName;
  final String? companyLogo;
  // financials
  final double revenueThisMonth;
  final double receivablesOutstanding;
  final double payablesOutstanding;
  final double collectedThisMonth;
  final int ordersThisMonth;
  // deltas (% vs last month)
  final double deltaRevenue;
  final double deltaCollected;
  final double deltaOrders;
  final double deltaNet;
  // P&L
  final double plIncome;
  final double plPurchases;
  final double plExpenses;
  final double plPayroll;
  final double plNet;
  // counts
  final int pendingApprovals;
  final int overdueInvoices;
  // orders by status
  final int stTotal;
  final int stInProduction;
  final int stReadyToPack;
  final int stReadyToDispatch;
  final int stDelivered;
  // AR aging
  final double aging0_30;
  final double aging31_60;
  final double aging61_90;
  final double aging90;
  // cash flow
  final double cashInflow;
  final double cashOutflow;
  final double cashNet;
  // trends
  final List<double> trendRevenue;
  final List<double> trendCollected;
  final List<double> trendOrders;
  // rep-scoped (sales_rep / collection_rep)
  final bool isRep;
  final String? repName;
  final String? repType;
  final bool repCanSell;
  final bool repCanCollect;
  final double repSales;
  final int repOrders;
  final int repCustomers;
  final double repCommissionMonth;
  final double repCommissionPending;
  final double repToCollect;
  final double repCollected;
  final int repPendingAssignments;
  final List<HomeActivity> recentActivity;

  const HomeOverview({
    this.role,
    this.companyName,
    this.companyLogo,
    this.revenueThisMonth = 0,
    this.receivablesOutstanding = 0,
    this.payablesOutstanding = 0,
    this.collectedThisMonth = 0,
    this.ordersThisMonth = 0,
    this.deltaRevenue = 0,
    this.deltaCollected = 0,
    this.deltaOrders = 0,
    this.deltaNet = 0,
    this.plIncome = 0,
    this.plPurchases = 0,
    this.plExpenses = 0,
    this.plPayroll = 0,
    this.plNet = 0,
    this.pendingApprovals = 0,
    this.overdueInvoices = 0,
    this.stTotal = 0,
    this.stInProduction = 0,
    this.stReadyToPack = 0,
    this.stReadyToDispatch = 0,
    this.stDelivered = 0,
    this.aging0_30 = 0,
    this.aging31_60 = 0,
    this.aging61_90 = 0,
    this.aging90 = 0,
    this.cashInflow = 0,
    this.cashOutflow = 0,
    this.cashNet = 0,
    this.trendRevenue = const [],
    this.trendCollected = const [],
    this.trendOrders = const [],
    this.isRep = false,
    this.repName,
    this.repType,
    this.repCanSell = false,
    this.repCanCollect = false,
    this.repSales = 0,
    this.repOrders = 0,
    this.repCustomers = 0,
    this.repCommissionMonth = 0,
    this.repCommissionPending = 0,
    this.repToCollect = 0,
    this.repCollected = 0,
    this.repPendingAssignments = 0,
    this.recentActivity = const [],
  });

  factory HomeOverview.fromJson(Map<String, dynamic> j) {
    final f = (j['financials'] as Map?) ?? const {};
    final c = (j['counts'] as Map?) ?? const {};
    final pl = (j['pl'] as Map?) ?? const {};
    final company = (j['company'] as Map?) ?? const {};
    final d = (j['deltas'] as Map?) ?? const {};
    final s = (j['ordersByStatus'] as Map?) ?? const {};
    final a = (j['aging'] as Map?) ?? const {};
    final cf = (j['cashFlow'] as Map?) ?? const {};
    final t = (j['trends'] as Map?) ?? const {};
    final caps = (j['caps'] as Map?) ?? const {};
    final salesM = (j['sales'] as Map?) ?? const {};
    final collM = (j['collection'] as Map?) ?? const {};
    final acts = (j['recentActivity'] as List?) ?? const [];
    return HomeOverview(
      role: j['role']?.toString(),
      isRep: j['isRep'] as bool? ?? false,
      repName: j['repName']?.toString(),
      repType: j['repType']?.toString(),
      repCanSell: caps['canSell'] as bool? ?? false,
      repCanCollect: caps['canCollect'] as bool? ?? false,
      repSales: _n(salesM['salesThisMonth']),
      repOrders: _i(salesM['ordersThisMonth']),
      repCustomers: _i(salesM['customersCount']),
      repCommissionMonth: _n(salesM['commissionThisMonth']),
      repCommissionPending: _n(salesM['commissionPending']),
      repToCollect: _n(collM['toCollect']),
      repCollected: _n(collM['collectedThisMonth']),
      repPendingAssignments: _i(collM['pendingAssignments']),
      companyName: company['name']?.toString(),
      companyLogo: company['logo']?.toString(),
      revenueThisMonth: _n(f['revenueThisMonth']),
      receivablesOutstanding: _n(f['receivablesOutstanding']),
      payablesOutstanding: _n(f['payablesOutstanding']),
      collectedThisMonth: _n(f['collectedThisMonth']),
      ordersThisMonth: _i(f['ordersThisMonth']),
      deltaRevenue: _n(d['revenue']),
      deltaCollected: _n(d['collected']),
      deltaOrders: _n(d['orders']),
      deltaNet: _n(d['net']),
      plIncome: _n(pl['income']),
      plPurchases: _n(pl['purchases']),
      plExpenses: _n(pl['expenses']),
      plPayroll: _n(pl['payroll']),
      plNet: _n(pl['net']),
      pendingApprovals: _i(c['pendingApprovals']),
      overdueInvoices: _i(c['overdueInvoices']),
      stTotal: _i(s['total']),
      stInProduction: _i(s['inProduction']),
      stReadyToPack: _i(s['readyToPack']),
      stReadyToDispatch: _i(s['readyToDispatch']),
      stDelivered: _i(s['delivered']),
      aging0_30: _n(a['d0_30']),
      aging31_60: _n(a['d31_60']),
      aging61_90: _n(a['d61_90']),
      aging90: _n(a['d90']),
      cashInflow: _n(cf['inflow']),
      cashOutflow: _n(cf['outflow']),
      cashNet: _n(cf['net']),
      trendRevenue: _list(t['revenue']),
      trendCollected: _list(t['collected']),
      trendOrders: _list(t['orders']),
      recentActivity: acts.map((e) => HomeActivity.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
