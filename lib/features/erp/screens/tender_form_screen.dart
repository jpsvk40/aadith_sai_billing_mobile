import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../providers/erp_providers.dart';

const _kTenderStatuses = ['IDENTIFIED', 'SEEN', 'APPROVED_TO_BID', 'PURCHASED', 'PREBID', 'SUBMITTED', 'OPENED', 'NEGOTIATION', 'WON', 'LOST', 'DROPPED'];
const _kTenderTypes = ['OPEN', 'LIMITED', 'EOI', 'RFP', 'NOMINATION'];

/// Create / edit a tender (ERP Tender & Bid) — mirrors the web tender form.
/// PATCH edits fields; status changes go through the dedicated status endpoint.
class TenderFormScreen extends ConsumerStatefulWidget {
  final int? editId;
  const TenderFormScreen({super.key, this.editId});
  @override
  ConsumerState<TenderFormScreen> createState() => _TenderFormScreenState();
}

class _TenderFormScreenState extends ConsumerState<TenderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  // Basics
  final _titleCtrl = TextEditingController();
  final _authorityCtrl = TextEditingController();
  final _nitCtrl = TextEditingController();
  final _scopeCtrl = TextEditingController();
  String _tenderType = 'OPEN';
  String? _status;
  String? _originalStatus;
  // Commercials
  final _estValueCtrl = TextEditingController();
  final _emdCtrl = TextEditingController();
  final _tenderFeeCtrl = TextEditingController();
  final _processingFeeCtrl = TextEditingController();
  // Key dates
  DateTime? _publishDate;
  DateTime? _prebidDate;
  DateTime? _submissionDeadline;
  DateTime? _openingDate;
  final _deliveryPeriodCtrl = TextEditingController();
  // Source & notes
  final _sourceCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.editId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl, _authorityCtrl, _nitCtrl, _scopeCtrl,
      _estValueCtrl, _emdCtrl, _tenderFeeCtrl, _processingFeeCtrl,
      _deliveryPeriodCtrl, _sourceCtrl, _websiteCtrl, _remarksCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _apiDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String? _str(TextEditingController c) { final t = c.text.trim(); return t.isEmpty ? null : t; }
  num? _num(TextEditingController c) { final t = c.text.trim(); return t.isEmpty ? null : num.tryParse(t); }
  String _pretty(String s) => s.replaceAll('_', ' ');

  Future<void> _load() async {
    try {
      final t = await ref.read(erpRepositoryProvider).getTender(widget.editId!);
      String s(dynamic v) => (v ?? '').toString();
      _titleCtrl.text = s(t['title']);
      _authorityCtrl.text = s(t['authority']);
      _nitCtrl.text = s(t['nitNumber']);
      _scopeCtrl.text = s(t['scopeSummary']);
      if (_kTenderTypes.contains(t['tenderType'])) _tenderType = s(t['tenderType']);
      _status = _kTenderStatuses.contains(t['status']) ? s(t['status']) : null;
      _originalStatus = _status;
      _estValueCtrl.text = t['estimatedValue'] != null ? s(t['estimatedValue']) : '';
      _emdCtrl.text = t['emdAmount'] != null ? s(t['emdAmount']) : '';
      _tenderFeeCtrl.text = t['tenderFeeAmount'] != null ? s(t['tenderFeeAmount']) : '';
      _processingFeeCtrl.text = t['processingFee'] != null ? s(t['processingFee']) : '';
      _publishDate = DateTime.tryParse(s(t['publishDate']));
      _prebidDate = DateTime.tryParse(s(t['prebidDate']));
      _submissionDeadline = DateTime.tryParse(s(t['submissionDeadline']));
      _openingDate = DateTime.tryParse(s(t['openingDate']));
      _deliveryPeriodCtrl.text = s(t['deliveryPeriod']);
      _sourceCtrl.text = s(t['source']);
      _websiteCtrl.text = s(t['websiteUrl']);
      _remarksCtrl.text = s(t['remarks']);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(e.toString(), error: true);
      }
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) { _snack('Tender title is required', error: true); return; }
    final body = <String, dynamic>{
      'title': title,
      'tenderType': _tenderType,
    };
    void put(String k, dynamic v) { if (v != null) body[k] = v; }
    put('nitNumber', _str(_nitCtrl));
    put('authority', _str(_authorityCtrl));
    put('scopeSummary', _str(_scopeCtrl));
    put('estimatedValue', _num(_estValueCtrl));
    put('emdAmount', _num(_emdCtrl));
    put('tenderFeeAmount', _num(_tenderFeeCtrl));
    put('processingFee', _num(_processingFeeCtrl));
    put('publishDate', _publishDate != null ? _apiDate(_publishDate!) : null);
    put('prebidDate', _prebidDate != null ? _apiDate(_prebidDate!) : null);
    put('submissionDeadline', _submissionDeadline != null ? _apiDate(_submissionDeadline!) : null);
    put('openingDate', _openingDate != null ? _apiDate(_openingDate!) : null);
    put('deliveryPeriod', _str(_deliveryPeriodCtrl));
    put('source', _str(_sourceCtrl));
    put('websiteUrl', _str(_websiteCtrl));
    put('remarks', _str(_remarksCtrl));
    // NOTE: status is intentionally NOT in the create/PATCH body — it is changed
    // via the dedicated status endpoint after the fields are saved.

    setState(() => _saving = true);
    try {
      final repo = ref.read(erpRepositoryProvider);
      if (_isEdit) {
        await repo.updateTender(widget.editId!, body);
        if (_status != null && _status != _originalStatus) {
          await repo.setTenderStatus(widget.editId!, _status!);
        }
      } else {
        await repo.createTender(body);
      }
      if (!mounted) return;
      _snack('Tender "$title" ${_isEdit ? 'updated' : 'created'}');
      context.pop(true);
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppColors.danger : AppColors.success));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Tender' : 'New Tender')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle('Basics'),
                  _field('Title', _titleCtrl, required: true),
                  _field('Authority', _authorityCtrl),
                  _field('NIT number', _nitCtrl),
                  _dropdown('Tender type', _tenderType, _kTenderTypes, (v) => setState(() => _tenderType = v ?? 'OPEN')),
                  _field('Scope summary', _scopeCtrl, maxLines: 3),
                  if (_isEdit)
                    _dropdown('Status', _status, _kTenderStatuses, (v) => setState(() => _status = v), hint: 'Select status', nullable: true),

                  _sectionTitle('Commercials'),
                  Row(children: [
                    Expanded(child: _field('Estimated value', _estValueCtrl, hint: '0.00', numeric: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _field('EMD amount', _emdCtrl, hint: '0.00', numeric: true)),
                  ]),
                  Row(children: [
                    Expanded(child: _field('Tender fee', _tenderFeeCtrl, hint: '0.00', numeric: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _field('Processing fee', _processingFeeCtrl, hint: '0.00', numeric: true)),
                  ]),

                  _sectionTitle('Key Dates'),
                  _dateField('Publish date', _publishDate, () => _pickDate((d) => _publishDate = d, _publishDate), onClear: _publishDate == null ? null : () => setState(() => _publishDate = null)),
                  const SizedBox(height: 14),
                  _dateField('Pre-bid date', _prebidDate, () => _pickDate((d) => _prebidDate = d, _prebidDate), onClear: _prebidDate == null ? null : () => setState(() => _prebidDate = null)),
                  const SizedBox(height: 14),
                  _dateField('Submission deadline', _submissionDeadline, () => _pickDate((d) => _submissionDeadline = d, _submissionDeadline), onClear: _submissionDeadline == null ? null : () => setState(() => _submissionDeadline = null)),
                  const SizedBox(height: 14),
                  _dateField('Opening date', _openingDate, () => _pickDate((d) => _openingDate = d, _openingDate), onClear: _openingDate == null ? null : () => setState(() => _openingDate = null)),
                  const SizedBox(height: 14),
                  _field('Delivery period', _deliveryPeriodCtrl, hint: 'e.g. 6 months'),

                  _sectionTitle('Source & Notes'),
                  _field('Source', _sourceCtrl),
                  _field('Website URL', _websiteCtrl),
                  _field('Remarks', _remarksCtrl, maxLines: 3),

                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check),
                      label: Text(_saving ? 'Saving…' : (_isEdit ? 'Save Changes' : 'Create Tender')),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Future<void> _pickDate(ValueChanged<DateTime> onPicked, DateTime? current) async {
    final picked = await showDatePicker(context: context, initialDate: current ?? DateTime.now(), firstDate: DateTime(2015), lastDate: DateTime(2100));
    if (picked != null) setState(() => onPicked(picked));
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 12),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      );

  Widget _field(String label, TextEditingController c, {String? hint, bool numeric = false, int maxLines = 1, bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(required ? '$label *' : label),
        TextFormField(
          controller: c,
          maxLines: maxLines,
          keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
          style: const TextStyle(fontSize: 13),
          decoration: _dec(hint ?? label),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _dropdown(String label, String? value, List<String> options, ValueChanged<String?> onChanged, {String? hint, bool nullable = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: _dec(hint ?? 'Select'),
          hint: nullable ? Text(hint ?? 'Select', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)) : null,
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(_pretty(o), style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap, {VoidCallback? onClear}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(value != null ? AppDateUtils.formatDisplay(value) : 'Select', style: TextStyle(fontSize: 13, color: value != null ? AppColors.textPrimary : AppColors.textMuted))),
              if (value != null && onClear != null) InkWell(onTap: onClear, child: const Icon(Icons.close, size: 16, color: AppColors.textMuted)),
            ]),
          ),
        ),
      ],
    );
  }

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
}
