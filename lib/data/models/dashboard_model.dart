class DashboardStats {
  final double totalRevenue;
  final double monthlyRevenue;
  final int totalOrders;
  final int pendingOrders;
  final double outstandingAmount;
  final int totalCustomers;
  final int unreadAlerts;
  final List<RevenuePoint> revenueChart;

  const DashboardStats({
    required this.totalRevenue,
    required this.monthlyRevenue,
    required this.totalOrders,
    required this.pendingOrders,
    required this.outstandingAmount,
    required this.totalCustomers,
    required this.unreadAlerts,
    this.revenueChart = const [],
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final revenueTrend = (json['revenueTrend'] as List<dynamic>?)
            ?.map((e) => RevenuePoint.fromJson(e as Map<String, dynamic>))
            .toList() ??
        (json['revenueChart'] as List<dynamic>?)
                ?.map((e) => RevenuePoint.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const <RevenuePoint>[];
    final recentAlerts = (json['recentAlerts'] as List<dynamic>?) ?? const [];
    final monthlyRevenue = double.tryParse(
          json['monthlyRevenue']?.toString() ?? json['thisMonthRevenue']?.toString() ?? '0',
        ) ??
        0;

    return DashboardStats(
      totalRevenue: double.tryParse(
            json['totalRevenue']?.toString() ??
                json['thisMonthRevenue']?.toString() ??
                json['monthlyRevenue']?.toString() ??
                '0',
          ) ??
          monthlyRevenue,
      monthlyRevenue: monthlyRevenue,
      totalOrders: int.tryParse(
            json['totalOrders']?.toString() ??
                json['thisMonthOrders']?.toString() ??
                json['todayOrders']?.toString() ??
                '0',
          ) ??
          0,
      pendingOrders: int.tryParse(json['pendingOrders']?.toString() ?? '') ??
          ((json['inProduction'] ?? 0) as num).toInt() +
              ((json['pendingPacking'] ?? 0) as num).toInt() +
              ((json['pendingDispatch'] ?? 0) as num).toInt(),
      outstandingAmount: double.tryParse(
            json['outstandingAmount']?.toString() ??
                json['totalOutstanding']?.toString() ??
                '0',
          ) ??
          0,
      totalCustomers: int.tryParse(json['totalCustomers']?.toString() ?? '0') ?? 0,
      unreadAlerts: int.tryParse(json['unreadAlerts']?.toString() ?? '') ??
          recentAlerts
              .where((alert) => alert is Map<String, dynamic> && alert['isRead'] != true)
              .length,
      revenueChart: revenueTrend,
    );
  }

  factory DashboardStats.empty() => const DashboardStats(
    totalRevenue: 0, monthlyRevenue: 0, totalOrders: 0,
    pendingOrders: 0, outstandingAmount: 0, totalCustomers: 0, unreadAlerts: 0,
  );
}

class RevenuePoint {
  final String label;
  final double amount;

  const RevenuePoint({required this.label, required this.amount});

  factory RevenuePoint.fromJson(Map<String, dynamic> json) {
    return RevenuePoint(
      label: json['label'] ?? json['month'] ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? json['revenue']?.toString() ?? '0') ?? 0,
    );
  }
}
