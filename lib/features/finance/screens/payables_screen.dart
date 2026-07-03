import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../finance_reports.dart';

const _red = Color(0xFFEF4444);

class _VendorDue {
  final String name;
  double total = 0;
  final List<Map<String, dynamic>> bills = [];
  _VendorDue(this.name);
}

/// Payables — vendor dues grouped by vendor (expandable to the open bills), with quick
/// links to vendor payments & credit notes.
class PayablesScreen extends ConsumerStatefulWidget {
  const PayablesScreen({super.key});
  @override
  ConsumerState<PayablesScreen> createState() => _PayablesScreenState();
}

class _PayablesScreenState extends ConsumerState<PayablesScreen> {
  List<_VendorDue> _vendors = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final data = await client.get(ApiConstants.vendorOutstanding);
      final rows = (data is List ? data : (data is Map ? (data['data'] ?? data['rows'] ?? const []) : const []) as List)
          .whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      // Group open bills by vendor.
      final byVendor = <String, _VendorDue>{};
      for (final r in rows) {
        final due = _num(r['outstandingAmount'] ?? r['balanceAmount'] ?? (_num(r['totalAmount']) - _num(r['paidAmount'])));
        if (due <= 0) continue;
        final vendor = (r['vendor'] is Map ? (r['vendor'] as Map)['vendorName'] : null)?.toString() ?? r['vendorName']?.toString() ?? 'Unknown vendor';
        final v = byVendor.putIfAbsent(vendor, () => _VendorDue(vendor));
        v.total += due;
        v.bills.add(r);
      }
      final vendors = byVendor.values.toList()..sort((a, b) => b.total.compareTo(a.total));
      if (!mounted) return;
      setState(() { _vendors = vendors; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _vendors.fold<double>(0, (a, v) => a + v.total);
    final billCount = _vendors.fold<int>(0, (a, v) => a + v.bills.length);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Payables')),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    // Hero
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(gradient: LinearGradient(colors: [_red, Color(0xFFB91C1C)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                        child: Stack(children: [
                          Positioned(right: -20, top: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Total payable', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
                            const SizedBox(height: 4),
                            Text(CurrencyUtils.format(total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                            const SizedBox(height: 8),
                            Text('${_vendors.length} vendor${_vendors.length == 1 ? '' : 's'} · $billCount open bill${billCount == 1 ? '' : 's'}',
                                style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
                          ]),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Quick links → payments made & credit notes (generic report views)
                    Row(children: [
                      Expanded(child: _link('Payments', Icons.payments_outlined, const Color(0xFF059669), () => context.push('/reports/view', extra: FinanceReports.vendorPayments))),
                      const SizedBox(width: 10),
                      Expanded(child: _link('Vendor CN', Icons.assignment_return_outlined, const Color(0xFFD97706), () => context.push('/reports/view', extra: FinanceReports.vendorCreditNotes))),
                      const SizedBox(width: 10),
                      Expanded(child: _link('Customer CN', Icons.assignment_returned_outlined, const Color(0xFF7C3AED), () => context.push('/reports/view', extra: FinanceReports.customerCreditNotes))),
                    ]),
                    const SizedBox(height: 16),
                    const Text('Vendor dues', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    if (_vendors.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No outstanding vendor bills 🎉', style: TextStyle(color: AppColors.textSecondary)))),
                    ..._vendors.map(_vendorCard),
                  ]),
                ),
    );
  }

  Widget _link(String label, IconData icon, Color color, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.35))),
          child: Column(children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      );

  Widget _vendorCard(_VendorDue v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          leading: Container(
            width: 40, height: 40, alignment: Alignment.center,
            decoration: BoxDecoration(color: _red.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
            child: Text(v.name.isEmpty ? '?' : v.name.trim()[0].toUpperCase(), style: const TextStyle(color: _red, fontWeight: FontWeight.w900, fontSize: 15)),
          ),
          title: Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          subtitle: Text('${v.bills.length} open bill${v.bills.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          trailing: Text(CurrencyUtils.format(v.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: _red)),
          children: v.bills.map((b) {
            final due = _num(b['outstandingAmount'] ?? b['balanceAmount'] ?? (_num(b['totalAmount']) - _num(b['paidAmount'])));
            final date = (b['purchaseDate'] ?? b['invoiceDate'] ?? '').toString();
            final days = _num(b['daysDiff']).toInt();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                const Icon(Icons.description_outlined, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b['purchaseNumber']?.toString() ?? b['invoiceNumber']?.toString() ?? 'Bill', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text('${date.length >= 10 ? date.substring(0, 10) : date}${days > 0 ? ' · $days day${days == 1 ? '' : 's'} old' : ''}',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                ])),
                Text(CurrencyUtils.format(due), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ]),
            );
          }).toList(),
        ),
      ),
    );
  }
}
