import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

/// Post a stock entry — Initial Stock / Inward / Outward / Adjust In / Adjust Out —
/// per godown, one or many item lines. Mirrors the web "Stock Entries" screen.
/// Quantity is always a positive magnitude; the server derives the sign from the type.
class StockEntryScreen extends ConsumerStatefulWidget {
  const StockEntryScreen({super.key});
  @override
  ConsumerState<StockEntryScreen> createState() => _StockEntryScreenState();
}

class _InvItem {
  final int id;
  final String name;
  final String code;
  final String unit;
  final double stock;
  _InvItem(this.id, this.name, this.code, this.unit, this.stock);
  String get label => code.isEmpty ? name : '$name ($code)';
}

class _InvLocation {
  final int id;
  final String name;
  _InvLocation(this.id, this.name);
}

class _EntryLine {
  _InvItem? item;
  final qtyCtrl = TextEditingController();
  final remarksCtrl = TextEditingController();
  void dispose() {
    qtyCtrl.dispose();
    remarksCtrl.dispose();
  }
}

const _txnTypes = ['OPENING', 'INWARD', 'OUTWARD', 'ADJUST_IN', 'ADJUST_OUT'];

String _txnLabel(String t) => t == 'OPENING' ? 'Initial Stock' : t.replaceAll('_', ' ');

class _StockEntryScreenState extends ConsumerState<StockEntryScreen> {
  late final ApiClient _client;
  List<_InvItem> _items = [];
  List<_InvLocation> _locations = [];
  bool _loading = true;
  String? _loadError;
  bool _saving = false;

  String _type = 'INWARD';
  DateTime _date = DateTime.now();
  int? _locationId;
  final _notesCtrl = TextEditingController();
  final List<_EntryLine> _lines = [_EntryLine()];

  @override
  void initState() {
    super.initState();
    _client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final itemsData = await _client.get(ApiConstants.inventoryItems);
      final locData = await _client.get(ApiConstants.inventoryLocations);
      final items = (itemsData is List ? itemsData : const [])
          .whereType<Map>()
          .map((e) => _InvItem(
                e['id'] as int,
                (e['displayName'] ?? e['itemName'] ?? '').toString(),
                (e['itemCode'] ?? '').toString(),
                (e['unit'] ?? '').toString(),
                _num(e['totalQuantity']),
              ))
          .toList();
      final locs = (locData is List ? locData : const [])
          .whereType<Map>()
          .map((e) => _InvLocation(e['id'] as int, (e['locationName'] ?? e['locationCode'] ?? 'Location').toString()))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _locations = locs;
        _locationId = locs.isNotEmpty ? locs.first.id : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadError = e.toString(); _loading = false; });
    }
  }

  String _apiDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickItem(_EntryLine line) async {
    final chosen = await showModalBottomSheet<_InvItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => _ItemPicker(items: _items),
    );
    if (chosen != null) setState(() => line.item = chosen);
  }

  Future<void> _submit() async {
    if (_locationId == null) { _snack('Pick a location', error: true); return; }
    final valid = _lines.where((l) => l.item != null && (_num(l.qtyCtrl.text) > 0)).toList();
    if (valid.isEmpty) { _snack('Add at least one item with a quantity', error: true); return; }
    setState(() => _saving = true);
    try {
      await _client.post(ApiConstants.inventoryTransactions, data: {
        'txnType': _type,
        'txnDate': _apiDate(_date),
        'locationId': _locationId,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
        'lines': valid
            .map((l) => {
                  'itemId': l.item!.id,
                  'quantity': _num(l.qtyCtrl.text),
                  if (l.remarksCtrl.text.trim().isNotEmpty) 'remarks': l.remarksCtrl.text.trim(),
                })
            .toList(),
      });
      if (!mounted) return;
      _snack('Stock entry posted');
      context.pop();
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppColors.danger : AppColors.success, duration: Duration(seconds: error ? 5 : 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Stock Entry'),
        actions: [
          IconButton(
            tooltip: 'Entry history',
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/finance/inventory/entries/history'),
          ),
        ],
      ),
      body: _loading
          ? const LoadingIndicator(message: 'Loading items & godowns…')
          : _loadError != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load: $_loadError', style: const TextStyle(color: AppColors.danger))))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      _type == 'OPENING'
                          ? 'Use Initial Stock only when setting the starting balance for an item at this godown.'
                          : 'Quantity is a positive number; ${_txnLabel(_type)} decides whether it adds or removes stock.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    _label('Entry type'),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      isExpanded: true,
                      decoration: _dec('Entry type'),
                      items: _txnTypes.map((t) => DropdownMenuItem(value: t, child: Text(_txnLabel(t)))).toList(),
                      onChanged: (v) => setState(() => _type = v ?? 'INWARD'),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _dateField()),
                      const SizedBox(width: 12),
                      Expanded(child: _locationField()),
                    ]),
                    const SizedBox(height: 14),
                    _label('Notes'),
                    TextFormField(controller: _notesCtrl, decoration: _dec('Reason / reference (optional)')),
                    const SizedBox(height: 20),
                    Row(children: [
                      const Text('Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const Spacer(),
                      Text('${_lines.length} line${_lines.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ]),
                    const SizedBox(height: 10),
                    ...List.generate(_lines.length, (i) => _lineCard(i)),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _lines.add(_EntryLine())),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add line'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check),
                        label: Text(_saving ? 'Posting…' : 'Post Entry'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _lineCard(int i) {
    final l = _lines[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 22, height: 22, alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
            child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => _pickItem(l),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  Icon(l.item != null ? Icons.inventory_2_outlined : Icons.add_box_outlined, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(l.item?.label ?? 'Select item', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: l.item != null ? AppColors.textPrimary : AppColors.textMuted, fontWeight: l.item != null ? FontWeight.w600 : FontWeight.w400))),
                  const Icon(Icons.expand_more, size: 18, color: AppColors.textMuted),
                ]),
              ),
            ),
          ),
          if (_lines.length > 1)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
              onPressed: () => setState(() => _lines.removeAt(i).dispose()),
            ),
        ]),
        if (l.item != null && l.item!.stock != 0)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 30),
            child: Text('In stock: ${l.item!.stock.toStringAsFixed(l.item!.stock == l.item!.stock.roundToDouble() ? 0 : 2)}${l.item!.unit.isNotEmpty ? ' ${l.item!.unit}' : ''}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(flex: 4, child: _miniField('Quantity *', l.qtyCtrl, numeric: true)),
          const SizedBox(width: 8),
          Expanded(flex: 6, child: _miniField('Remarks', l.remarksCtrl)),
        ]),
      ]),
    );
  }

  Widget _dateField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Date'),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (picked != null) setState(() => _date = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(_apiDate(_date), style: const TextStyle(fontSize: 13)),
              ]),
            ),
          ),
        ],
      );

  Widget _locationField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Location *'),
          DropdownButtonFormField<int>(
            initialValue: _locationId,
            isExpanded: true,
            decoration: _dec('Godown'),
            items: _locations.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _locationId = v),
          ),
        ],
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      );

  Widget _miniField(String label, TextEditingController c, {bool numeric = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 3),
        TextFormField(
          controller: c,
          keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
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

/// Searchable inventory-item picker (client-side filter over the loaded list).
class _ItemPicker extends StatefulWidget {
  final List<_InvItem> items;
  const _ItemPicker({required this.items});
  @override
  State<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends State<_ItemPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty ? widget.items : widget.items.where((p) => p.label.toLowerCase().contains(q)).toList();
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
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'Search items…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true, filled: true, fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No items', style: TextStyle(color: AppColors.textMuted)))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final p = filtered[i];
                      return ListTile(
                        dense: true,
                        title: Text(p.name, style: const TextStyle(fontSize: 13)),
                        subtitle: Text('${p.code.isNotEmpty ? '${p.code} · ' : ''}stock ${p.stock.toStringAsFixed(p.stock == p.stock.roundToDouble() ? 0 : 2)}${p.unit.isNotEmpty ? ' ${p.unit}' : ''}',
                            style: const TextStyle(fontSize: 11)),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
