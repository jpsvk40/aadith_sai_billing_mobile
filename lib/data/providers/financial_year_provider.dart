import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../widgets/common/list_controls.dart';

/// Financial years for the current company, used to power the Financial Year
/// filter in list screens' filter sheets. Mirrors the web `/financial-years`
/// call: `{ years: [{id, label, ...}], currentYear: {id, ...} }`.
class FinancialYearsData {
  final List<FinancialYearOption> years;
  final String? currentYearId;
  const FinancialYearsData({this.years = const [], this.currentYearId});
}

/// Cached for the session — years change rarely. Falls back to an empty list on
/// any error so the FY filter simply doesn't appear rather than breaking a screen.
final financialYearsProvider = FutureProvider<FinancialYearsData>((ref) async {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  try {
    final data = await client.get(ApiConstants.financialYears);
    if (data is! Map) return const FinancialYearsData();
    final raw = (data['years'] ?? data['allYears'] ?? const []);
    final years = (raw is List ? raw : const [])
        .whereType<Map>()
        .map((y) => FinancialYearOption(
              id: (y['id']).toString(),
              label: (y['label'] ?? '').toString(),
            ))
        .where((y) => y.label.isNotEmpty && y.id.isNotEmpty && y.id != 'null')
        .toList();
    final cur = data['currentYear'];
    final currentYearId = (cur is Map && cur['id'] != null) ? cur['id'].toString() : null;
    return FinancialYearsData(years: years, currentYearId: currentYearId);
  } catch (_) {
    return const FinancialYearsData();
  }
});
