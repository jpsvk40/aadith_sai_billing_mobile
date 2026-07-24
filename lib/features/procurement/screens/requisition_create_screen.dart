import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/procurement_models.dart';
import '../providers/procurement_providers.dart';

/// New Material Requisition — mirrors the web create flow: project (optional),
/// department, priority, required-by date, notes and one or more line items.
/// On success it opens the created requisition's detail (like the web).
class RequisitionCreateScreen extends ConsumerStatefulWidget {
  const RequisitionCreateScreen({super.key});

  @override
  ConsumerState<RequisitionCreateScreen> createState() => _RequisitionCreateScreenState();
}

class _ReqItemRow {
  final TextEditingController desc = TextEditingController();
  final TextEditingController unit = TextEditingController(text: 'nos');
  final TextEditingController qty = TextEditingController();
  void dispose() {
    desc.dispose();
    unit.dispose();
    qty.dispose();
  }
}

class _RequisitionCreateScreenState extends ConsumerState<RequisitionCreateScreen> {
  final _deptCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _priority = 'NORMAL';
  String? _projectId;
  DateTime? _requiredBy;
  final List<_ReqItemRow> _items = [_ReqItemRow()];
  bool _busy = false;

  @override
  void dispose() {
    _deptCtrl.dispose();
    _notesCtrl.dispose();
    for (final r in _items) {
      r.dispose();
    }
    super.dispose();
  }

  void _addItem() => setState(() => _items.add(_ReqItemRow()));
  void _removeItem(int i) => setState(() {
        _items.removeAt(i).dispose();
      });

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _requiredBy ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _requiredBy = picked);
  }

  Future<void> _submit() async {
    final items = _items
        .where((r) => r.desc.text.trim().isNotEmpty && (double.tryParse(r.qty.text.trim()) ?? 0) > 0)
        .map((r) => {
              'itemDescription': r.desc.text.trim(),
              'unit': r.unit.text.trim().isEmpty ? 'nos' : r.unit.text.trim(),
              'quantity': double.parse(r.qty.text.trim()),
            })
        .toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item with a quantity.'), backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final mr = await ref.read(procurementRepositoryProvider).createRequisition(
            projectId: _projectId,
            department: _deptCtrl.text,
            priority: _priority,
            requiredByDate: _requiredBy != null ? AppDateUtils.formatApi(_requiredBy!) : null,
            notes: _notesCtrl.text,
            items: items,
          );
      // Refresh hub counts/lists in the background.
      ref.read(procurementHubProvider.notifier).load();
      if (!mounted) return;
      if (mr.id > 0) {
        context.pushReplacement('/procurement/requisitions/${mr.id}');
      } else {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.startsWith('Exception: ') ? s.substring(11) : s), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(procurementProjectsProvider).valueOrNull ?? const <ProcProject>[];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Requisition')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (projects.isNotEmpty) ...[
            _label('Project (optional)'),
            DropdownButtonFormField<String>(
              initialValue: _projectId,
              isExpanded: true,
              decoration: _dec(),
              hint: const Text('— None —'),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('— None —')),
                ...projects.map((p) => DropdownMenuItem<String>(value: '${p.id}', child: Text(p.label, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => _projectId = v),
            ),
            const SizedBox(height: 14),
          ],
          _label('Department'),
          TextField(controller: _deptCtrl, decoration: _dec(hint: 'e.g. Site / Fabrication')),
          const SizedBox(height: 14),
          _label('Priority'),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            isExpanded: true,
            decoration: _dec(),
            items: const [
              DropdownMenuItem(value: 'LOW', child: Text('LOW')),
              DropdownMenuItem(value: 'NORMAL', child: Text('NORMAL')),
              DropdownMenuItem(value: 'HIGH', child: Text('HIGH')),
            ],
            onChanged: (v) => setState(() => _priority = v ?? 'NORMAL'),
          ),
          const SizedBox(height: 14),
          _label('Required by (optional)'),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: _dec(),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Text(
                    _requiredBy == null ? 'Any' : AppDateUtils.formatDisplay(_requiredBy),
                    style: TextStyle(color: _requiredBy == null ? AppColors.textMuted : AppColors.textPrimary),
                  ),
                  const Spacer(),
                  if (_requiredBy != null)
                    GestureDetector(onTap: () => setState(() => _requiredBy = null), child: const Icon(Icons.clear, size: 16, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _label('Notes (optional)'),
          TextField(controller: _notesCtrl, maxLines: 2, decoration: _dec(hint: 'Anything the buyer should know')),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Items / Materials', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const Spacer(),
              TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add, size: 18), label: const Text('Add item')),
            ],
          ),
          const SizedBox(height: 6),
          ..._items.asMap().entries.map((e) => _itemCard(e.key)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create requisition', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _itemCard(int i) {
    final row = _items[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Row(
            children: [
              Text('Item ${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const Spacer(),
              if (_items.length > 1)
                InkWell(onTap: () => _removeItem(i), child: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(controller: row.desc, decoration: _dec(hint: 'Material description')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(controller: row.unit, decoration: _dec(hint: 'Unit')),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: row.qty,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: _dec(hint: 'Qty'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      );

  InputDecoration _dec({String? hint}) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
      );
}
