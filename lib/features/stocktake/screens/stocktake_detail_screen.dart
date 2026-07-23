import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/stocktake_model.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/stocktake_providers.dart';

/// Stock-take detail + count. Shows status + per-status actions (freeze / save
/// counts / approve / cancel). Once FROZEN, each frozen line gets a counted-qty +
/// reason field. A Scan button resolves a barcode (best-effort via POS scan) and
/// jumps to the matching line, degrading to a manual line search.
class StocktakeDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const StocktakeDetailScreen({super.key, required this.id});
  @override
  ConsumerState<StocktakeDetailScreen> createState() => _StocktakeDetailScreenState();
}

class _StocktakeDetailScreenState extends ConsumerState<StocktakeDetailScreen> {
  int get _id => int.tryParse(widget.id) ?? 0;

  Stocktake? _stocktake;
  bool _loading = true;
  String? _loadError;
  bool _busy = false;

  List<StocktakeLine> _lines = const [];
  final Map<int, TextEditingController> _counted = {};
  final Map<int, TextEditingController> _reason = {};
  final Map<int, FocusNode> _focusNodes = {};
  final Map<int, GlobalKey> _keys = {};
  final Map<int, double?> _origCounted = {};
  final Map<int, String> _origReason = {};
  int? _focusLineId;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _disposeLineControllers();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _disposeLineControllers() {
    for (final c in _counted.values) {
      c.dispose();
    }
    for (final c in _reason.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    _counted.clear();
    _reason.clear();
    _focusNodes.clear();
    _keys.clear();
    _origCounted.clear();
    _origReason.clear();
  }

  String _qtyText(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  void _hydrate(Stocktake st) {
    _disposeLineControllers();
    _lines = st.lines;
    for (final l in _lines) {
      _counted[l.id] = TextEditingController(text: l.countedQty == null ? '' : _qtyText(l.countedQty!));
      _reason[l.id] = TextEditingController(text: l.varianceReason ?? '');
      _focusNodes[l.id] = FocusNode();
      _keys[l.id] = GlobalKey();
      _origCounted[l.id] = l.countedQty;
      _origReason[l.id] = l.varianceReason ?? '';
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final st = await ref.read(stocktakeRepositoryProvider).getStocktake(_id);
      if (!mounted) return;
      setState(() {
        _stocktake = st;
        _hydrate(st);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadError = e.toString(); _loading = false; });
    }
  }

  Future<bool> _confirm(String title, String message, String confirmLabel, {bool danger = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel, style: TextStyle(color: danger ? AppColors.danger : AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _runAction(Future<Stocktake> Function() action, String successMsg) async {
    setState(() => _busy = true);
    try {
      final st = await action();
      if (!mounted) return;
      setState(() {
        _stocktake = st;
        _hydrate(st);
        _busy = false;
      });
      _snack(successMsg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.toString(), error: true);
    }
  }

  Future<void> _freeze() async {
    if (!await _confirm('Freeze book stock', 'This snapshots the current on-hand quantity for every item at this location. You can then count.', 'Freeze')) return;
    await _runAction(() => ref.read(stocktakeRepositoryProvider).freeze(_id), 'Book stock frozen — start counting');
  }

  Future<void> _approve() async {
    if (!await _confirm('Approve & post', 'Variance adjustments will be posted to stock. This cannot be undone.', 'Approve', danger: true)) return;
    await _runAction(() => ref.read(stocktakeRepositoryProvider).approve(_id), 'Approved — variances posted');
  }

  Future<void> _cancel() async {
    if (!await _confirm('Cancel stock-take', 'This discards the count. Book stock is unchanged.', 'Cancel stock-take', danger: true)) return;
    await _runAction(() => ref.read(stocktakeRepositoryProvider).cancel(_id), 'Stock-take cancelled');
  }

  Future<void> _saveCounts() async {
    final changed = <Map<String, dynamic>>[];
    for (final l in _lines) {
      final ctext = _counted[l.id]!.text.trim();
      final rtext = _reason[l.id]!.text.trim();
      final curCounted = ctext.isEmpty ? null : double.tryParse(ctext);
      final countedChanged = curCounted != _origCounted[l.id];
      final reasonChanged = rtext != (_origReason[l.id] ?? '');
      if (countedChanged || reasonChanged) {
        changed.add({
          'itemId': l.itemId,
          'countedQty': curCounted,
          if (rtext.isNotEmpty) 'varianceReason': rtext,
        });
      }
    }
    if (changed.isEmpty) { _snack('No changes to save'); return; }
    await _runAction(() => ref.read(stocktakeRepositoryProvider).saveCounts(_id, changed), 'Saved ${changed.length} count${changed.length == 1 ? '' : 's'}');
  }

  Future<void> _scan() async {
    final st = _stocktake;
    if (st == null || !st.isCountable) return;
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScannerPage()));
    if (code == null || code.isEmpty || !mounted) return;
    // Best-effort POS resolve (gracefully degrades if retail_pos is off / unknown).
    final resolved = await ref.read(stocktakeRepositoryProvider).resolveBarcode(code);
    if (!mounted) return;
    final name = resolved?['name']?.toString();
    final sku = resolved?['sku']?.toString();
    for (final t in [sku, name, code]) {
      if (t == null || t.trim().isEmpty) continue;
      final line = _findLine(t);
      if (line != null) { _focusLine(line.id); return; }
    }
    // No line matched — let the user pick manually over the frozen lines.
    _pickLineManually(initialQuery: name ?? sku ?? code);
  }

  StocktakeLine? _findLine(String term) {
    final q = term.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final l in _lines) {
      if (l.itemCode.isNotEmpty && l.itemCode.toLowerCase() == q) return l;
    }
    for (final l in _lines) {
      if (l.itemCode.toLowerCase().contains(q) || l.itemName.toLowerCase().contains(q)) return l;
    }
    return null;
  }

  void _focusLine(int lineId) {
    setState(() => _focusLineId = lineId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[lineId]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.1);
      }
      _focusNodes[lineId]?.requestFocus();
    });
  }

  Future<void> _pickLineManually({String? initialQuery}) async {
    final chosen = await showModalBottomSheet<StocktakeLine>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => _LinePicker(lines: _lines, initialQuery: initialQuery),
    );
    if (chosen != null) _focusLine(chosen.id);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppColors.danger : AppColors.success, duration: Duration(seconds: error ? 5 : 2)));
  }

  @override
  Widget build(BuildContext context) {
    final st = _stocktake;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(st == null ? 'Stock-take' : 'Stock-take #${st.id}'),
        actions: [
          if (st != null && st.isCountable)
            IconButton(onPressed: _busy ? null : _scan, icon: const Icon(Icons.qr_code_scanner), tooltip: 'Scan barcode'),
        ],
      ),
      body: _loading
          ? const LoadingIndicator(message: 'Loading stock-take…')
          : _loadError != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load: $_loadError', style: const TextStyle(color: AppColors.danger))))
              : st == null
                  ? const SizedBox.shrink()
                  : ListView(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      children: [
                        _headerCard(st),
                        const SizedBox(height: 14),
                        _actions(st),
                        if (st.isCountable) ...[
                          const SizedBox(height: 20),
                          Row(children: [
                            const Text('Lines', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            const Spacer(),
                            Text('${_lines.length} item${_lines.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ]),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _scan,
                            icon: const Icon(Icons.qr_code_scanner, size: 18),
                            label: const Text('Scan barcode'),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                          ),
                          const SizedBox(height: 10),
                          if (_lines.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: Text('No lines snapshotted.', style: TextStyle(color: AppColors.textMuted))),
                            )
                          else
                            ...List.generate(_lines.length, (i) => _lineCard(_lines[i])),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
    );
  }

  Widget _headerCard(Stocktake st) {
    final c = StocktakeStatus.color(st.status);
    final sm = st.summary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(st.locationName ?? (st.locationId != null ? 'Location #${st.locationId}' : 'Stock-take'),
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(st.status, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: c)),
          ),
        ]),
        if (st.notes != null && st.notes!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(st.notes!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        ],
        if (sm != null) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 6, children: [
            _stat('Lines', sm.totalLines.toString()),
            _stat('Counted', sm.counted.toString()),
            _stat('Variances', sm.variances.toString()),
            _stat('Net units', '${sm.netUnits >= 0 ? '+' : ''}${_qtyText(sm.netUnits)}'),
          ]),
        ],
      ]),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        ],
      );

  Widget _actions(Stocktake st) {
    final buttons = <Widget>[];
    if (st.isDraft) {
      buttons.add(_primaryBtn('Freeze book stock', Icons.ac_unit, _freeze));
    }
    if (st.isCountable) {
      buttons.add(_primaryBtn('Save counts', Icons.save_outlined, _saveCounts));
    }
    if (st.isCounting) {
      buttons.add(_successBtn('Approve & post', Icons.check_circle_outline, _approve));
    }
    if (!st.isTerminal) {
      buttons.add(_dangerBtn('Cancel', Icons.close, _cancel));
    }
    if (buttons.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Text(
          st.status == 'APPROVED' ? 'This stock-take is approved and its variances have been posted.' : 'This stock-take was cancelled.',
          style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
      );
    }
    return Column(children: [
      for (int i = 0; i < buttons.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: buttons[i]),
      ],
    ]);
  }

  Widget _primaryBtn(String label, IconData icon, VoidCallback onTap) => ElevatedButton.icon(
        onPressed: _busy ? null : onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
      );

  Widget _successBtn(String label, IconData icon, VoidCallback onTap) => ElevatedButton.icon(
        onPressed: _busy ? null : onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
      );

  Widget _dangerBtn(String label, IconData icon, VoidCallback onTap) => OutlinedButton.icon(
        onPressed: _busy ? null : onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger), padding: const EdgeInsets.symmetric(vertical: 13)),
      );

  Widget _lineCard(StocktakeLine l) {
    final focused = _focusLineId == l.id;
    final ct = double.tryParse(_counted[l.id]!.text.trim());
    final variance = ct == null ? null : ct - l.systemQty;
    Color varColor = AppColors.textMuted;
    if (variance != null) {
      varColor = variance == 0 ? AppColors.textMuted : (variance > 0 ? AppColors.success : AppColors.danger);
    }
    return Container(
      key: _keys[l.id],
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: focused ? AppColors.primary : AppColors.border, width: focused ? 1.6 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text(l.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 4),
        Text('System: ${_qtyText(l.systemQty)}${l.unit.isNotEmpty ? ' ${l.unit}' : ''}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(flex: 4, child: _miniField('Counted', _counted[l.id]!, numeric: true, focusNode: _focusNodes[l.id], onChanged: (_) => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(flex: 6, child: _miniField('Variance reason', _reason[l.id]!)),
        ]),
        if (variance != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              variance == 0 ? 'No variance' : 'Variance ${variance > 0 ? '+' : ''}${_qtyText(variance)}${l.unit.isNotEmpty ? ' ${l.unit}' : ''}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: varColor),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _miniField(String label, TextEditingController c, {bool numeric = false, FocusNode? focusNode, ValueChanged<String>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 3),
        TextField(
          controller: c,
          focusNode: focusNode,
          keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
      ],
    );
  }
}

/// Searchable picker over the frozen stock-take lines (fallback when a scanned
/// barcode can't be auto-matched).
class _LinePicker extends StatefulWidget {
  final List<StocktakeLine> lines;
  final String? initialQuery;
  const _LinePicker({required this.lines, this.initialQuery});
  @override
  State<_LinePicker> createState() => _LinePickerState();
}

class _LinePickerState extends State<_LinePicker> {
  late String _q = widget.initialQuery ?? '';
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialQuery ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty ? widget.lines : widget.lines.where((l) => l.label.toLowerCase().contains(q)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'Search lines…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true, filled: true, fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No matching line', style: TextStyle(color: AppColors.textMuted)))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final l = filtered[i];
                      return ListTile(
                        dense: true,
                        title: Text(l.itemName, style: const TextStyle(fontSize: 13)),
                        subtitle: Text('${l.itemCode.isNotEmpty ? '${l.itemCode} · ' : ''}system ${l.systemQty == l.systemQty.roundToDouble() ? l.systemQty.toInt() : l.systemQty}${l.unit.isNotEmpty ? ' ${l.unit}' : ''}',
                            style: const TextStyle(fontSize: 11)),
                        onTap: () => Navigator.pop(context, l),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

/// Full-screen camera scanner; pops the first decoded barcode value.
/// (Same pattern as the Service warranty-lookup scanner.)
class _ScannerPage extends StatefulWidget {
  const _ScannerPage();
  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  bool _done = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return;
          final code = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
          if (code != null && code.isNotEmpty) {
            _done = true;
            Navigator.of(context).pop(code);
          }
        },
      ),
    );
  }
}
