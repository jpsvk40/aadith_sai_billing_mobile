import '../network/api_client.dart';
import '../models/customer_trace_model.dart';
import '../models/advisor_model.dart';

/// AI / insight READ endpoints — Customer Trace (business_trace), Sales Advisor
/// (sales_intelligence), Inventory Advisor (inventory_intelligence). Paths are
/// inline (these surfaces are not in api_constants.dart). The advisor /run
/// endpoints can be slow (AI + heavy aggregation) so they use a long timeout.
class InsightsRepository {
  final ApiClient _client;
  InsightsRepository(this._client);

  static const _runTimeout = Duration(seconds: 120);

  // ─── Customer Trace ───────────────────────────────────────────────────────

  Future<CustomerTrace> customerTrace(String customerId, String comparisonMode) async {
    final data = await _client.get(
      '/api/business-trace/customer/$customerId',
      queryParams: {'comparisonMode': comparisonMode},
    );
    return CustomerTrace.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Typeahead — min 2 chars. Returns [] for short/empty queries.
  Future<List<CustomerSuggestion>> customerSuggestions(String q) async {
    final query = q.trim();
    if (query.length < 2) return const [];
    final data = await _client.get(
      '/api/business-trace/customer-suggestions',
      queryParams: {'q': query, 'limit': 10},
    );
    final list = data is Map ? (data['suggestions'] ?? const []) : const [];
    if (list is List) {
      return list.map((e) => CustomerSuggestion.fromJson((e as Map).cast<String, dynamic>())).toList();
    }
    return const [];
  }

  // ─── Sales Advisor ────────────────────────────────────────────────────────

  /// Returns the cached analysis, or a sentinel with hasAnalysis=false. Never computes.
  Future<SalesAdvisor> salesAdvisorGet(String comparisonMode) async {
    final data = await _client.get(
      '/api/ai/sales-advisor',
      queryParams: {'comparisonMode': comparisonMode},
    );
    return SalesAdvisor.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Computes + caches the analysis (long-running).
  Future<SalesAdvisor> salesAdvisorRun(String comparisonMode) async {
    final data = await _client.post(
      '/api/ai/sales-advisor/run',
      data: {'comparisonMode': comparisonMode},
      timeout: _runTimeout,
    );
    return SalesAdvisor.fromJson((data as Map).cast<String, dynamic>());
  }

  // ─── Inventory Advisor ────────────────────────────────────────────────────

  Future<InventoryAdvisor> inventoryAdvisorGet() async {
    final data = await _client.get('/api/ai/inventory-advisor');
    return InventoryAdvisor.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<InventoryAdvisor> inventoryAdvisorRun() async {
    final data = await _client.post(
      '/api/ai/inventory-advisor/run',
      data: const {},
      timeout: _runTimeout,
    );
    return InventoryAdvisor.fromJson((data as Map).cast<String, dynamic>());
  }
}
