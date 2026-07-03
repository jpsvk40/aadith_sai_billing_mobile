import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/machine_detail_models.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/machinery_providers.dart';

const _purple = Color(0xFF7C3AED);

/// Report a breakdown from the field with AI-powered diagnosis: describe the symptom,
/// get severity / causes / likely parts / a safety checklist, then submit — the office
/// is alerted (in-app + push) and a PENDING breakdown job is opened. No costs here.
class MachineBreakdownScreen extends ConsumerStatefulWidget {
  final int machineId;
  const MachineBreakdownScreen({super.key, required this.machineId});
  @override
  ConsumerState<MachineBreakdownScreen> createState() => _MachineBreakdownScreenState();
}

class _MachineBreakdownScreenState extends ConsumerState<MachineBreakdownScreen> {
  final _symptom = TextEditingController();
  MachineDiagnosis? _diag;
  bool _diagnosing = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _symptom.dispose();
    super.dispose();
  }

  Future<void> _runDiagnosis() async {
    final text = _symptom.text.trim();
    if (text.length < 8) {
      setState(() => _error = 'Describe the problem in a few words first.');
      return;
    }
    setState(() { _diagnosing = true; _error = null; });
    try {
      final d = await ref.read(machineryRepositoryProvider).aiDiagnose(machineId: widget.machineId, symptom: text);
      setState(() => _diag = d);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _diagnosing = false);
    }
  }

  Future<void> _submit() async {
    final text = _symptom.text.trim();
    if (text.length < 8) {
      setState(() => _error = 'Describe the problem in a few words first.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final desc = _diag != null && _diag!.faultCategory.isNotEmpty ? '[${_diag!.faultCategory}] $text' : text;
      final job = await ref.read(machineryRepositoryProvider).reportBreakdown(widget.machineId, description: desc);
      ref.invalidate(machineDetailProvider(widget.machineId));
      ref.invalidate(machinerySummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${job.jobCode} reported — your manager has been notified')));
        context.pop(true);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(machineDetailProvider(widget.machineId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Report breakdown')),
      body: async.when(
        loading: () => const LoadingIndicator(message: 'Loading machine…'),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(machineDetailProvider(widget.machineId))),
        data: (m) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.agriculture_outlined, size: 20, color: _purple),
                const SizedBox(width: 10),
                Expanded(child: Text('${m.name} · ${m.machineCode}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
              ]),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _symptom,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'What happened? *',
                hintText: 'e.g. Hydraulic hose burst near the boom cylinder, oil leaking fast',
                alignLabelWithHint: true,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 12),
            // Inline AI Diagnosis (same UX as the service ticket AI card).
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDDD6FE))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisSize: MainAxisSize.max, children: [
                  const Icon(Icons.auto_awesome, size: 17, color: _purple),
                  const SizedBox(width: 7),
                  const Text('AI Diagnosis', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _purple)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _diagnosing ? null : _runDiagnosis,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        _diagnosing ? 'Diagnosing…' : (_diag == null ? 'Get AI diagnosis' : 'Refresh'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                ]),
                if (_diag != null) ...[
                  const SizedBox(height: 12),
                  _severityBanner(_diag!),
                  const SizedBox(height: 10),
                  if (_diag!.faultCategory.isNotEmpty) _line('Fault', _diag!.faultCategory),
                  if (_diag!.estimatedDowntimeHours > 0) _line('Est. downtime', '${_diag!.estimatedDowntimeHours} hrs'),
                  if (_diag!.probableCauses.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Probable causes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    ..._diag!.probableCauses.map((c) => Padding(padding: const EdgeInsets.only(top: 3), child: Text('• $c', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)))),
                  ],
                  if (_diag!.suggestedParts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Likely parts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _diag!.suggestedParts
                          .map((p) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFFDDD6FE))),
                                child: Text(p, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _purple)),
                              ))
                          .toList(),
                    ),
                  ],
                  if (_diag!.safetyChecklist.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Do this first (safety)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    ..._diag!.safetyChecklist.map((c) => Padding(padding: const EdgeInsets.only(top: 3), child: Text('☑ $c', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)))),
                  ],
                ],
              ]),
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
              onTap: _submitting ? null : _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _submitting ? AppColors.textMuted : AppColors.danger,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [BoxShadow(color: AppColors.danger.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Text(_submitting ? 'Reporting…' : 'Submit breakdown report', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Your manager is alerted immediately. Repair costs and parts are handled by the office.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _severityBanner(MachineDiagnosis d) {
    final (color, bg, label, icon) = switch (d.severity) {
      'STOP_OPERATION' => (const Color(0xFFB91C1C), const Color(0xFFFEF2F2), 'STOP OPERATION NOW', Icons.dangerous_outlined),
      'MONITOR' => (const Color(0xFF1D4ED8), const Color(0xFFEFF6FF), 'SAFE TO RUN — MONITOR', Icons.visibility_outlined),
      _ => (const Color(0xFF92400E), const Color(0xFFFFFBEB), 'RUN WITH CAUTION', Icons.warning_amber_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.max, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: color))),
      ]),
    );
  }

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(mainAxisSize: MainAxisSize.max, children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
        ]),
      );
}
