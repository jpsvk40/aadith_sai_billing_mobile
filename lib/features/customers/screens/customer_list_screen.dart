import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/customer_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/customer_list_provider.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});
  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(customerListProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Customer> _filtered(CustomerListState s) {
    final q = s.search.trim().toLowerCase();
    if (q.isEmpty) return s.customers;
    return s.customers.where((c) =>
        c.name.toLowerCase().contains(q) ||
        (c.phone ?? '').toLowerCase().contains(q) ||
        (c.city ?? '').toLowerCase().contains(q)).toList();
  }

  Color _avatarColor(String name) {
    const palette = [Color(0xFF0D6EFD), Color(0xFF198754), Color(0xFFF59E0B), Color(0xFF7C3AED), Color(0xFF0891B2), Color(0xFFDB2777)];
    return palette[name.isEmpty ? 0 : name.codeUnitAt(0) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerListProvider);
    final visible = _filtered(state);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Customers')),
      body: state.isLoading && state.customers.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.customers.isEmpty
              ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(customerListProvider.notifier).load())
              : RefreshIndicator(
                  onRefresh: () => ref.read(customerListProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: visible.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) return _searchHeader(state, visible.length);
                      return _customerCard(visible[i - 1]);
                    },
                  ),
                ),
    );
  }

  Widget _searchHeader(CustomerListState s, int shown) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => ref.read(customerListProvider.notifier).setSearch(v),
            decoration: InputDecoration(
              hintText: 'Search customer, phone, city...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              suffixIcon: s.search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () {
                      _searchCtrl.clear();
                      ref.read(customerListProvider.notifier).setSearch('');
                    })
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Text('$shown customer${shown == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _customerCard(Customer c) {
    final color = _avatarColor(c.name);
    final initials = c.name.trim().isEmpty
        ? '?'
        : c.name.trim().split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
    final place = [c.city, c.district].where((e) => e != null && e.isNotEmpty).join(', ');
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44, height: 44, alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)),
              child: Text(initials, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  if (place.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Flexible(child: Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                    ]),
                  ],
                  if (c.phone != null && c.phone!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(c.phone!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            if (c.phone != null && c.phone!.isNotEmpty)
              InkWell(
                onTap: () => launchUrl(Uri.parse('tel:${c.phone}')),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(19)),
                  child: const Icon(Icons.call, color: AppColors.primary, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
