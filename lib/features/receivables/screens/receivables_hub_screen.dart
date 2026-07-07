import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

/// Receivables Hub — a single Outstanding list. Each customer row carries inline
/// Pay + WA actions, so no separate Send-WA / Payment tabs are needed. Finance can
/// narrow by search, collection lens, and collection rep.
class ReceivablesHubScreen extends ConsumerStatefulWidget {
  const ReceivablesHubScreen({super.key});

  @override
  ConsumerState<ReceivablesHubScreen> createState() => _ReceivablesHubScreenState();
}

class _ReceivablesHubScreenState extends ConsumerState<ReceivablesHubScreen> {
  Map<String, dynamic>? _hubData;
  bool _loading = true;
  String? _error;

  final String _filterDistrict = ''; // reserved for a future area filter; inert for now
  String _filterRep = ''; // '' = all reps, '__unassigned__' = customers with an unassigned balance
  String _filterLens = 'all'; // all, unassigned, pending, partial, promised
  String _search = '';

  static const String _repUnassigned = '__unassigned__';

  final List<String> _lenses = ['All', '⚠ Unassigned', 'Pending', 'Partial', 'Promised'];
  final List<String> _lensKeys = ['all', 'unassigned', 'pending', 'partial', 'promised'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Distinct collection reps present in the loaded data (sorted), for the Rep filter dropdown.
  List<String> _repNames() {
    final customers = (_hubData?['customers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final names = <String>{};
    for (final c in customers) {
      final reps = (c['reps'] as List?)?.whereType<Map>() ?? const <Map>[];
      for (final r in reps) {
        final n = r['repName'] as String?;
        if (n != null && n.isNotEmpty) names.add(n);
      }
    }
    final list = names.toList()..sort();
    return list;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final data = await client.get(ApiConstants.customerOutstanding);
      if (!mounted) return;
      setState(() {
        _hubData = data is Map ? data.cast<String, dynamic>() : {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filterCustomers() {
    final customers = (_hubData?['customers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return customers.where((c) {
      if (_search.isNotEmpty && !(c['customerName'] as String? ?? '').toLowerCase().contains(_search.toLowerCase())) return false;
      if (_filterDistrict.isNotEmpty && (c['district'] as String? ?? '') != _filterDistrict) return false;
      if (_filterRep.isNotEmpty) {
        final reps = (c['reps'] as List?)?.whereType<Map>().toList() ?? [];
        if (_filterRep == _repUnassigned) {
          // Customers carrying an unassigned (no-rep) balance — the collection gap.
          if (((c['unassignedOutstanding'] as num?)?.toDouble() ?? 0) <= 0) return false;
        } else if (!reps.any((r) => (r['repName'] as String?) == _filterRep)) {
          return false;
        }
      }
      if (_filterLens != 'all') {
        final assigned = (c['assignedOutstanding'] as num?)?.toDouble() ?? 0;
        final unassigned = (c['unassignedOutstanding'] as num?)?.toDouble() ?? 0;
        switch (_filterLens) {
          case 'unassigned':
            if (unassigned <= 0) return false;
          case 'pending':
            if (assigned <= 0 || unassigned > 0) return false;
          case 'partial':
            if (assigned <= 0 || unassigned <= 0) return false;
          case 'promised':
            if ((c['promiseDate'] as String?) == null) return false;
          default:
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Light status-bar icons — the fixed header below is a dark gradient.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: LoadingIndicator())
                  : _error != null
                      ? ErrorStateWidget(message: _error!, onRetry: _load)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _buildOutstandingTab(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Gradient hero header (title + KPI tiles) — matches the Home dashboard style. ──
  Widget _buildHeader() {
    final summary = _hubData?['summary'] as Map<String, dynamic>? ?? {};
    final total = (summary['totalOutstanding'] as num?)?.toDouble() ?? 0;
    final coverage = (summary['coveragePct'] as num?)?.toDouble() ?? 0;
    final overdue = (summary['overdueAmount'] as num?)?.toDouble() ?? 0;
    final customers = (summary['totalCustomers'] as num?)?.toInt() ?? 0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 14, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0369A1), Color(0xFF1D4ED8), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Color(0x331D4ED8), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Outstanding & Receipts',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (customers > 0)
                Text('$customers customers',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _headerStat('Total Due', _compactInr(total), Colors.white),
              _headerStat('Coverage', '${coverage % 1 == 0 ? coverage.toStringAsFixed(0) : coverage.toStringAsFixed(1)}%', const Color(0xFF4ADE80)),
              _headerStat('Overdue', _compactInr(overdue), const Color(0xFFFCA5A5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10.5)),
          ],
        ),
      ),
    );
  }

  /// Compact Indian currency for the header tiles (₹40.3L / ₹1.2Cr) — keeps big numbers readable.
  String _compactInr(double n) {
    final a = n.abs();
    if (a >= 10000000) return '₹${(n / 10000000).toStringAsFixed(2)}Cr';
    if (a >= 100000) return '₹${(n / 100000).toStringAsFixed(2)}L';
    if (a >= 1000) return '₹${(n / 1000).toStringAsFixed(1)}K';
    return '₹${n.toStringAsFixed(0)}';
  }

  // ── Outstanding list (search / lens / rep filters + customer cards). ──
  Widget _buildOutstandingTab() {
    final filtered = _filterCustomers();
    final filteredTotal = filtered.fold<double>(0, (s, c) => s + ((c['totalOutstanding'] as num?)?.toDouble() ?? 0));

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            // Filters
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search customer...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _lenses.asMap().entries.map((e) {
                        final selected = _filterLens == _lensKeys[e.key];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: selected,
                            label: Text(e.value),
                            onSelected: (_) => setState(() => _filterLens = _lensKeys[e.key]),
                            backgroundColor: Colors.grey[200],
                            selectedColor: const Color(0xFF1D4ED8),
                            labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Rep filter — narrow to one collection rep's customers (or the unassigned gap).
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text('Rep', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _filterRep,
                            items: [
                              const DropdownMenuItem(value: '', child: Text('All reps')),
                              ..._repNames().map((n) => DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis))),
                              const DropdownMenuItem(value: _repUnassigned, child: Text('⚠ Unassigned (no rep)')),
                            ],
                            onChanged: (v) => setState(() => _filterRep = v ?? ''),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Result count line — reflects the active filters.
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${filtered.length} customer(s)', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                  Text('₹${fmt(filteredTotal)}', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            // Customer list
            if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text('No customers match filters', style: TextStyle(color: Colors.grey[600])),
                ),
              )
            else
              Column(
                children: filtered.map((c) {
                  final total = (c['totalOutstanding'] as num?)?.toDouble() ?? 0;
                  final assigned = (c['assignedOutstanding'] as num?)?.toDouble() ?? 0;
                  final unassigned = (c['unassignedOutstanding'] as num?)?.toDouble() ?? 0;
                  final rep = (c['suggestedRep'] as Map?)?.castStringDynamic();

                  return Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c['customerName'] as String? ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  if (c['city'] != null) Text(c['city'] as String, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            Text('₹${fmt(total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFDC2626))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Coverage bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: total > 0 ? assigned / total : 0,
                            minHeight: 6,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation(unassigned > 0 ? Colors.orange : Colors.green),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                assigned > 0 ? '✓ ₹${fmt(assigned)} with ${rep?['repName'] ?? 'rep'}' : '⚠ Not assigned',
                                style: TextStyle(fontSize: 11, color: assigned > 0 ? Colors.green[700] : Colors.red[700]),
                              ),
                            ),
                            if (unassigned > 0)
                              Chip(
                                label: Text('₹${fmt(unassigned)} gap'),
                                backgroundColor: Colors.orange[100],
                                labelStyle: const TextStyle(fontSize: 10),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Buttons wrapped in Expanded: an ElevatedButton.icon inside a Row with
                        // spaceEvenly/MainAxisSize.max gets measured with unbounded width, and its
                        // Material RenderPhysicalShape then throws "BoxConstraints forces an infinite
                        // width", blanking the card. Expanded gives each a tight, finite width.
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showPaymentDialog(c),
                                icon: const Icon(Icons.payment, size: 16),
                                label: const Text('Pay', style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF15803D),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showWhatsAppDialog(c),
                                icon: const Text('💬', style: TextStyle(fontSize: 14)),
                                label: const Text('WA', style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ──
  void _showPaymentDialog(Map<String, dynamic> customer) {
    final totalController = TextEditingController();
    final paymentModeItems = ['Cash', 'Card', 'Bank Transfer', 'Check', 'Other'];
    String selectedMode = paymentModeItems[0];
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Record Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer['customerName'] as String? ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Outstanding: ₹${fmt((customer['totalOutstanding'] as num?)?.toDouble() ?? 0)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 12),
                TextField(
                  controller: totalController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount Paid',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  isExpanded: true,
                  value: selectedMode,
                  items: paymentModeItems.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => selectedMode = v ?? selectedMode),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving || totalController.text.isEmpty
                  ? null
                  : () => _recordPayment(ctx, customer, totalController.text, selectedMode),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
              child: Text(saving ? 'Saving...' : 'Pay', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordPayment(BuildContext ctx, Map<String, dynamic> customer, String amount, String mode) async {
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      await client.post(ApiConstants.recordPayment, data: {
        'customerId': customer['customerId'],
        'amount': double.parse(amount),
        'paymentMode': mode,
      });
      if (!mounted) return;
      Navigator.pop(ctx);
      _load();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showWhatsAppDialog(Map<String, dynamic> customer) {
    final nameCtrl = TextEditingController(text: customer['phone'] as String?);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send WhatsApp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Phone (or override)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendWhatsAppPdf(customer, override: nameCtrl.text.isEmpty ? null : nameCtrl.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            child: const Text('Send PDF', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendWhatsAppPdf(Map<String, dynamic> customer, {String? override}) async {
    final id = customer['customerId'];
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing customer id')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending statement…')));
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      // Server-side: builds the statement PDF and sends it on WhatsApp. Passing `to` overrides the
      // customer's stored WhatsApp/phone. (The old /whatsapp-print endpoint needed caller-rendered
      // HTML, which the mobile can't produce — hence the "html is required" error.)
      await client.post(
        ApiConstants.collectionStatementWhatsapp('$id'),
        data: {if (override != null && override.trim().isNotEmpty) 'to': override.trim()},
        timeout: const Duration(seconds: 90), // PDF render + WhatsApp upload can be slow on a cold server
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Statement sent on WhatsApp')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

extension on Map {
  Map<String, dynamic> castStringDynamic() => cast<String, dynamic>();
}

String fmt(double n) => n.toStringAsFixed(2).replaceAll(RegExp(r'\.0$'), '');
