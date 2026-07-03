import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/machinery_providers.dart';

/// Daily logbook entry — designed to take <30s in the field: opening meter pre-filled
/// from the machine, hours auto-computed from the closing reading, fuel cost from
/// qty × rate. Client-side meter validation mirrors the API rule.
class MachineLogEntryScreen extends ConsumerStatefulWidget {
  final int machineId;
  const MachineLogEntryScreen({super.key, required this.machineId});
  @override
  ConsumerState<MachineLogEntryScreen> createState() => _MachineLogEntryScreenState();
}

class _MachineLogEntryScreenState extends ConsumerState<MachineLogEntryScreen> {
  final _opening = TextEditingController();
  final _closing = TextEditingController();
  final _idle = TextEditingController();
  final _fuelQty = TextEditingController();
  final _fuelRate = TextEditingController();
  final _remarks = TextEditingController();
  DateTime _date = DateTime.now();
  String _shift = 'DAY';
  bool _prefilled = false;
  bool _saving = false;
  String? _error;

  double? get _openingVal => double.tryParse(_opening.text.trim());
  double? get _closingVal => double.tryParse(_closing.text.trim());
  double get _hours {
    final o = _openingVal, c = _closingVal;
    if (o == null || c == null || c < o) return 0;
    return c - o;
  }

  double get _fuelCost {
    final q = double.tryParse(_fuelQty.text.trim()) ?? 0;
    final r = double.tryParse(_fuelRate.text.trim()) ?? 0;
    return q * r;
  }

  @override
  void dispose() {
    for (final c in [_opening, _closing, _idle, _fuelQty, _fuelRate, _remarks]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final o = _openingVal, c = _closingVal;
    if (o == null || c == null) {
      setState(() => _error = 'Enter the opening and closing meter readings.');
      return;
    }
    if (c < o) {
      setState(() => _error = 'Closing meter ($c) cannot be less than opening meter ($o).');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(machineryRepositoryProvider).createLog(
            widget.machineId,
            logDate: _date,
            shift: _shift,
            openingMeter: o,
            closingMeter: c,
            idleHours: double.tryParse(_idle.text.trim()),
            fuelQty: double.tryParse(_fuelQty.text.trim()),
            fuelRate: double.tryParse(_fuelRate.text.trim()),
            remarks: _remarks.text.trim(),
          );
      ref.invalidate(machineDetailProvider(widget.machineId));
      ref.invalidate(machinerySummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logbook entry saved')));
        context.pop(true);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(machineDetailProvider(widget.machineId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Log usage')),
      body: async.when(
        loading: () => const LoadingIndicator(message: 'Loading machine…'),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(machineDetailProvider(widget.machineId))),
        data: (m) {
          if (!_prefilled) {
            _prefilled = true;
            _opening.text = m.currentMeter % 1 == 0 ? '${m.currentMeter.toInt()}' : '${m.currentMeter}';
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  const Icon(Icons.agriculture_outlined, size: 20, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${m.name} · ${m.machineCode}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                  Text('Meter: ${m.currentMeter.toInt()} ${m.meterUnit}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _dateField()),
                const SizedBox(width: 10),
                Expanded(child: _shiftChips()),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _num('Opening meter *', _opening)),
                const SizedBox(width: 10),
                Expanded(child: _num('Closing meter *', _closing)),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timelapse, size: 15, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Text('Working: ${_hours.toStringAsFixed(_hours % 1 == 0 ? 0 : 1)} ${m.meterUnit}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _num('Idle hours', _idle)),
                const SizedBox(width: 10),
                Expanded(child: _num('Fuel qty (L)', _fuelQty)),
                const SizedBox(width: 10),
                Expanded(child: _num('Fuel rate ₹/L', _fuelRate)),
              ]),
              if (_fuelCost > 0) ...[
                const SizedBox(height: 8),
                Text('Fuel cost: ₹${_fuelCost.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _remarks,
                maxLines: 2,
                decoration: _dec('Remarks (optional)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
                  child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
                ),
              ],
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _saving ? AppColors.textMuted : AppColors.primary,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Text(_saving ? 'Saving…' : 'Save logbook entry', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      );

  Widget _num(String label, TextEditingController c) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: _dec(label),
      );

  Widget _dateField() => GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now());
          if (picked != null) setState(() => _date = picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text('${_date.day}/${_date.month}/${_date.year}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ]),
        ),
      );

  Widget _shiftChips() => Row(
        mainAxisSize: MainAxisSize.min,
        children: ['DAY', 'NIGHT'].map((s) {
          final on = _shift == s;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _shift = s),
              child: Container(
                margin: EdgeInsets.only(right: s == 'DAY' ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? const Color(0xFF7C3AED) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: on ? Colors.transparent : AppColors.border),
                ),
                child: Text(s, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: on ? Colors.white : AppColors.textSecondary)),
              ),
            ),
          );
        }).toList(),
      );
}
