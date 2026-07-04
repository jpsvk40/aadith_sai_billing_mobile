import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

const _cyan = Color(0xFF0891B2);

/// Inventory locations (read) — godowns, sites and their contacts.
class InventoryLocationsScreen extends ConsumerStatefulWidget {
  const InventoryLocationsScreen({super.key});
  @override
  ConsumerState<InventoryLocationsScreen> createState() => _InventoryLocationsScreenState();
}

class _InventoryLocationsScreenState extends ConsumerState<InventoryLocationsScreen> {
  List<Map<String, dynamic>> _all = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final data = await client.get(ApiConstants.inventoryLocations);
      if (!mounted) return;
      setState(() {
        _all = (data is List ? data : const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Locations')),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    if (_all.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: Text('No locations set up', style: TextStyle(color: AppColors.textSecondary)))),
                    ..._all.map(_card),
                  ]),
                ),
    );
  }

  Widget _card(Map<String, dynamic> l) {
    final name = (l['locationName'] ?? 'Location').toString();
    final code = (l['locationCode'] ?? '').toString();
    final type = (l['locationType'] ?? '').toString();
    final contact = (l['contactPerson'] ?? '').toString();
    final phone = (l['phone'] ?? '').toString();
    final address = (l['address'] ?? '').toString();
    final inactive = l['isActive'] == false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _cyan.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.warehouse_outlined, color: _cyan, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text([if (code.isNotEmpty) code, if (type.isNotEmpty) type].join(' · '),
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ])),
          if (inactive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.textMuted.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
              child: const Text('Inactive', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            ),
        ]),
        if (contact.isNotEmpty || phone.isNotEmpty || address.isNotEmpty) ...[
          const SizedBox(height: 10),
          if (contact.isNotEmpty || phone.isNotEmpty)
            _line(Icons.person_outline, [if (contact.isNotEmpty) contact, if (phone.isNotEmpty) phone].join(' · ')),
          if (address.isNotEmpty) _line(Icons.location_on_outlined, address),
        ],
      ]),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        ]),
      );
}
