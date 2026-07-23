import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/credit_note_model.dart';
import '../providers/credit_note_providers.dart';

/// Vendor Credit Notes list — parity with the web report: rows show vendor, CN #,
/// source bill, date, reason and amount. Each note is always against one purchase.
class VendorCreditNoteListScreen extends ConsumerWidget {
  const VendorCreditNoteListScreen({super.key});

  String _shortDate(String? d) => (d == null || d.length < 10) ? (d ?? '—') : d.substring(0, 10);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vendorCreditNoteListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Vendor Credit Notes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/vendor-credit-notes/create');
          ref.invalidate(vendorCreditNoteListProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)))),
        data: (notes) => notes.isEmpty
            ? _empty()
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(vendorCreditNoteListProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _row(notes[i]),
                ),
              ),
      ),
    );
  }

  Widget _row(VendorCreditNote n) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(n.creditNoteNumber.isEmpty ? 'Credit note' : n.creditNoteNumber, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                const SizedBox(width: 8),
                Text('· ${n.billLabel}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ]),
              const SizedBox(height: 4),
              Text(n.vendorName, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${_shortDate(n.creditNoteDate)}${(n.reason != null && n.reason!.isNotEmpty) ? '  ·  ${n.reason}' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          Text(CurrencyUtils.format(n.totalAmount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ]),
      );

  Widget _empty() => ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.assignment_return_outlined, size: 46, color: AppColors.textMuted),
          SizedBox(height: 12),
          Center(child: Text('No vendor credit notes yet.', style: TextStyle(color: AppColors.textMuted))),
        ],
      );
}
