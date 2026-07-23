// Sales Advisor + Inventory Advisor DTOs — mirror the web SalesAdvisorPage /
// InventoryAdvisorPage. Both are two-step: a GET returns a cached result OR
// {hasAnalysis:false}; a POST /run computes it. fromJson is tolerant.

double _toD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
double? _toDN(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
int _toI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
String? _str(dynamic v) => v?.toString();
List<String> _strList(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];

// ─── Sales Advisor ──────────────────────────────────────────────────────────

class SalesCustomerRow {
  final String? customerId;
  final String customerName;
  final String? phone;
  final String? city;
  final String? district;
  final String? representativeName;
  final int orderCurrentPeriod;
  final int orderPriorPeriod;
  final String? lastOrderDate;
  final double revenueCurrentPeriod;
  final double outstandingBalance;
  final double overdueAmount;
  final double? avgPaymentDelayDays;
  final String classification;
  final String? aiRecommendation;
  final String? nextBestAction;

  const SalesCustomerRow({
    this.customerId,
    required this.customerName,
    this.phone,
    this.city,
    this.district,
    this.representativeName,
    this.orderCurrentPeriod = 0,
    this.orderPriorPeriod = 0,
    this.lastOrderDate,
    this.revenueCurrentPeriod = 0,
    this.outstandingBalance = 0,
    this.overdueAmount = 0,
    this.avgPaymentDelayDays,
    this.classification = 'HEALTHY',
    this.aiRecommendation,
    this.nextBestAction,
  });

  factory SalesCustomerRow.fromJson(Map<String, dynamic> j) => SalesCustomerRow(
        customerId: _str(j['customerId']),
        customerName: (j['customerName'] ?? '').toString(),
        phone: _str(j['phone']),
        city: _str(j['city']),
        district: _str(j['district']),
        representativeName: _str(j['representativeName']),
        orderCurrentPeriod: _toI(j['orderCurrentPeriod']),
        orderPriorPeriod: _toI(j['orderPriorPeriod']),
        lastOrderDate: _str(j['lastOrderDate']),
        revenueCurrentPeriod: _toD(j['revenueCurrentPeriod']),
        outstandingBalance: _toD(j['outstandingBalance']),
        overdueAmount: _toD(j['overdueAmount']),
        avgPaymentDelayDays: _toDN(j['avgPaymentDelayDays']),
        classification: (j['classification'] ?? 'HEALTHY').toString(),
        aiRecommendation: _str(j['aiRecommendation']),
        nextBestAction: _str(j['nextBestAction']),
      );

  /// AI text with a graceful fallback to the next-best-action string.
  String get advice => (aiRecommendation?.isNotEmpty == true)
      ? aiRecommendation!
      : (nextBestAction?.isNotEmpty == true ? nextBestAction! : '');
}

class SalesProductRow {
  final String? productId;
  final String productName;
  final String? unit;
  final String? category;
  final double revenueCurrentPeriod;
  final double? revenueGrowthPct;
  final double revenueContributionPct;
  final double quantitySold90;
  final double quantityCurrentPeriod;
  final int uniqueCustomersCurrent;
  final String classification;
  final String? aiRecommendation;

  const SalesProductRow({
    this.productId,
    required this.productName,
    this.unit,
    this.category,
    this.revenueCurrentPeriod = 0,
    this.revenueGrowthPct,
    this.revenueContributionPct = 0,
    this.quantitySold90 = 0,
    this.quantityCurrentPeriod = 0,
    this.uniqueCustomersCurrent = 0,
    this.classification = 'HEALTHY',
    this.aiRecommendation,
  });

  factory SalesProductRow.fromJson(Map<String, dynamic> j) => SalesProductRow(
        productId: _str(j['productId']),
        productName: (j['productName'] ?? '').toString(),
        unit: _str(j['unit']),
        category: _str(j['category']),
        revenueCurrentPeriod: _toD(j['revenueCurrentPeriod']),
        revenueGrowthPct: _toDN(j['revenueGrowthPct']),
        revenueContributionPct: _toD(j['revenueContributionPct']),
        quantitySold90: _toD(j['quantitySold90']),
        quantityCurrentPeriod: _toD(j['quantityCurrentPeriod']),
        uniqueCustomersCurrent: _toI(j['uniqueCustomersCurrent']),
        classification: (j['classification'] ?? 'HEALTHY').toString(),
        aiRecommendation: _str(j['aiRecommendation']),
      );

  /// "Name — Unit" so same-name products of different sizes don't look duplicated.
  String get displayName => (unit != null && unit!.isNotEmpty) ? '$productName — $unit' : productName;
}

class SalesCustomerCounts {
  final int total, highRiskDebt, creditWarning, churning, declining, newCount, champion, loyal, slowPayer, healthy, inactive;
  const SalesCustomerCounts({
    this.total = 0,
    this.highRiskDebt = 0,
    this.creditWarning = 0,
    this.churning = 0,
    this.declining = 0,
    this.newCount = 0,
    this.champion = 0,
    this.loyal = 0,
    this.slowPayer = 0,
    this.healthy = 0,
    this.inactive = 0,
  });
  factory SalesCustomerCounts.fromJson(Map<String, dynamic> j) => SalesCustomerCounts(
        total: _toI(j['total']),
        highRiskDebt: _toI(j['highRiskDebt']),
        creditWarning: _toI(j['creditWarning']),
        churning: _toI(j['churning']),
        declining: _toI(j['declining']),
        newCount: _toI(j['new']),
        champion: _toI(j['champion']),
        loyal: _toI(j['loyal']),
        slowPayer: _toI(j['slowPayer']),
        healthy: _toI(j['healthy']),
        inactive: _toI(j['inactive']),
      );
}

class SalesProductCounts {
  final int total, star, rising, workhorse, fading, stalled, niche, healthy;
  const SalesProductCounts({
    this.total = 0,
    this.star = 0,
    this.rising = 0,
    this.workhorse = 0,
    this.fading = 0,
    this.stalled = 0,
    this.niche = 0,
    this.healthy = 0,
  });
  factory SalesProductCounts.fromJson(Map<String, dynamic> j) => SalesProductCounts(
        total: _toI(j['total']),
        star: _toI(j['star']),
        rising: _toI(j['rising']),
        workhorse: _toI(j['workhorse']),
        fading: _toI(j['fading']),
        stalled: _toI(j['stalled']),
        niche: _toI(j['niche']),
        healthy: _toI(j['healthy']),
      );
}

class SalesAdvisor {
  final bool hasAnalysis;
  final String? generatedAt;
  final String? periodLabel;
  final String? currentPeriodStart;
  final String? currentPeriodEnd;
  final String? aiError;
  final String? summary;
  final List<String> topActions;
  final List<SalesCustomerRow> customers;
  final List<SalesProductRow> products;
  final SalesCustomerCounts customerCounts;
  final SalesProductCounts productCounts;

  const SalesAdvisor({
    this.hasAnalysis = true,
    this.generatedAt,
    this.periodLabel,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.aiError,
    this.summary,
    this.topActions = const [],
    this.customers = const [],
    this.products = const [],
    this.customerCounts = const SalesCustomerCounts(),
    this.productCounts = const SalesProductCounts(),
  });

  /// The cached-empty sentinel — GET returned {hasAnalysis:false}.
  bool get isEmpty => !hasAnalysis;

  factory SalesAdvisor.fromJson(Map<String, dynamic> j) => SalesAdvisor(
        hasAnalysis: j['hasAnalysis'] != false,
        generatedAt: _str(j['generatedAt']),
        periodLabel: _str(j['periodLabel']),
        currentPeriodStart: _str(j['currentPeriodStart']),
        currentPeriodEnd: _str(j['currentPeriodEnd']),
        aiError: _str(j['aiError']),
        summary: _str(j['summary']),
        topActions: _strList(j['topActions']),
        customers: (j['customers'] as List<dynamic>?)
                ?.map((e) => SalesCustomerRow.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
        products: (j['products'] as List<dynamic>?)
                ?.map((e) => SalesProductRow.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
        customerCounts: SalesCustomerCounts.fromJson((j['customerCounts'] as Map?)?.cast<String, dynamic>() ?? const {}),
        productCounts: SalesProductCounts.fromJson((j['productCounts'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );
}

// ─── Inventory Advisor ──────────────────────────────────────────────────────

class InventoryItemRow {
  final String? itemId;
  final String itemName;
  final String? category;
  final String? unit;
  final double currentStock;
  final double? reorderLevel;
  final double? maxLevel;
  final double demandTrailing30;
  final double demandPrior30;
  final double? velocityChangePct;
  final double? daysOfStock;
  final double? procuredTrailing30;
  final bool hasLinkedProduct;
  final String classification;
  final String? aiRecommendation;

  const InventoryItemRow({
    this.itemId,
    required this.itemName,
    this.category,
    this.unit,
    this.currentStock = 0,
    this.reorderLevel,
    this.maxLevel,
    this.demandTrailing30 = 0,
    this.demandPrior30 = 0,
    this.velocityChangePct,
    this.daysOfStock,
    this.procuredTrailing30,
    this.hasLinkedProduct = false,
    this.classification = 'HEALTHY',
    this.aiRecommendation,
  });

  factory InventoryItemRow.fromJson(Map<String, dynamic> j) => InventoryItemRow(
        itemId: _str(j['itemId']),
        itemName: (j['itemName'] ?? '').toString(),
        category: _str(j['category']),
        unit: _str(j['unit']),
        currentStock: _toD(j['currentStock']),
        reorderLevel: _toDN(j['reorderLevel']),
        maxLevel: _toDN(j['maxLevel']),
        demandTrailing30: _toD(j['demandTrailing30']),
        demandPrior30: _toD(j['demandPrior30']),
        velocityChangePct: _toDN(j['velocityChangePct']),
        daysOfStock: _toDN(j['daysOfStock']),
        procuredTrailing30: _toDN(j['procuredTrailing30']),
        hasLinkedProduct: j['hasLinkedProduct'] as bool? ?? false,
        classification: (j['classification'] ?? 'HEALTHY').toString(),
        aiRecommendation: _str(j['aiRecommendation']),
      );
}

class InventoryCounts {
  final int total, hotLowStock, reorderSoon, lowStockOnly, hotOk, hotOverstocked, slowOverstocked, deadstock, healthy;
  const InventoryCounts({
    this.total = 0,
    this.hotLowStock = 0,
    this.reorderSoon = 0,
    this.lowStockOnly = 0,
    this.hotOk = 0,
    this.hotOverstocked = 0,
    this.slowOverstocked = 0,
    this.deadstock = 0,
    this.healthy = 0,
  });
  factory InventoryCounts.fromJson(Map<String, dynamic> j) => InventoryCounts(
        total: _toI(j['total']),
        hotLowStock: _toI(j['hotLowStock']),
        reorderSoon: _toI(j['reorderSoon']),
        lowStockOnly: _toI(j['lowStockOnly']),
        hotOk: _toI(j['hotOk']),
        hotOverstocked: _toI(j['hotOverstocked']),
        slowOverstocked: _toI(j['slowOverstocked']),
        deadstock: _toI(j['deadstock']),
        healthy: _toI(j['healthy']),
      );
}

class InventoryAdvisor {
  final bool hasAnalysis;
  final String? generatedAt;
  final String? aiError;
  final String? summary;
  final List<String> topActions;
  final List<InventoryItemRow> items;
  final InventoryCounts counts;

  const InventoryAdvisor({
    this.hasAnalysis = true,
    this.generatedAt,
    this.aiError,
    this.summary,
    this.topActions = const [],
    this.items = const [],
    this.counts = const InventoryCounts(),
  });

  bool get isEmpty => !hasAnalysis;

  factory InventoryAdvisor.fromJson(Map<String, dynamic> j) => InventoryAdvisor(
        hasAnalysis: j['hasAnalysis'] != false,
        generatedAt: _str(j['generatedAt']),
        aiError: _str(j['aiError']),
        summary: _str(j['summary']),
        topActions: _strList(j['topActions']),
        items: (j['items'] as List<dynamic>?)
                ?.map((e) => InventoryItemRow.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
        counts: InventoryCounts.fromJson((j['counts'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );
}
