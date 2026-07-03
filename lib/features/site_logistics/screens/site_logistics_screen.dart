import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/site_logistics_model.dart';
import '../providers/site_logistics_provider.dart';

const _statusColors = <String, Color>{
  'DRAFT': Color(0xFF64748B), 'SUBMITTED': Color(0xFF2563EB), 'APPROVED': AppColors.success, 'REJECTED': AppColors.danger,
  'DISPATCHED': Color(0xFFD97706), 'DELIVERED': Color(0xFF2563EB), 'CONFIRMED': AppColors.success,
};

class SiteLogisticsScreen extends ConsumerStatefulWidget {
  const SiteLogisticsScreen({super.key});
  @override
  ConsumerState<SiteLogisticsScreen> createState() => _SiteLogisticsScreenState();
}

class _SiteLogisticsScreenState extends ConsumerState<SiteLogisticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(siteLogisticsProvider.notifier).load());
  }

  void _newEntry() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(leading: const Icon(Icons.straighten, color: AppColors.primary), title: const Text('New Site Survey'), onTap: () { Navigator.pop(ctx); context.push('/site-logistics/survey'); }),
          ListTile(leading: const Icon(Icons.local_shipping_outlined, color: AppColors.primary), title: const Text('New Delivery'), onTap: () { Navigator.pop(ctx); context.push('/site-logistics/delivery'); }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _confirmDelivery(SiteDelivery d) async {
    final ctrl = TextEditingController();
    final photos = <SitePhoto>[];
    var uploading = false;

    Future<void> pickAndUpload(void Function(void Function()) setLocal) async {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (bc) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Take Photo'), onTap: () => Navigator.pop(bc, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from Gallery'), onTap: () => Navigator.pop(bc, ImageSource.gallery)),
        ])),
      );
      if (source == null) return;
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 82);
      if (file == null) return;
      setLocal(() => uploading = true);
      try {
        final photo = await ref.read(siteLogisticsProvider.notifier).repo.uploadPhoto(file.path);
        setLocal(() => photos.add(photo));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo upload needs storage configured: $e'), backgroundColor: AppColors.danger));
      } finally {
        setLocal(() => uploading = false);
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Confirm ${d.deliveryNumber}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Received by (name at site)')),
              const SizedBox(height: 14),
              Row(children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: uploading ? null : () => pickAndUpload(setLocal),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(uploading ? 'Uploading…' : 'Add proof photo'),
                ),
                const SizedBox(width: 10),
                Text('${photos.length} photo(s)', style: const TextStyle(color: Colors.grey)),
              ]),
              if (photos.any((p) => p.url != null))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(spacing: 8, runSpacing: 8, children: photos.where((p) => p.url != null).map((p) => ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(p.url!, width: 52, height: 52, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image)))).toList()),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: uploading ? null : () => Navigator.pop(ctx, true), child: const Text('Confirm at site')),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await ref.read(siteLogisticsProvider.notifier).confirmDelivery(d.id, {
          'receivedBy': ctrl.text.trim(),
          if (photos.isNotEmpty) 'photos': photos.map((p) => p.toJson()).toList(),
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery confirmed.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(siteLogisticsProvider);
    final n = ref.read(siteLogisticsProvider.notifier);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Site Logistics'),
          bottom: const TabBar(
            labelColor: AppColors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.white,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [Tab(text: 'Surveys'), Tab(text: 'Deliveries')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(onPressed: _newEntry, icon: const Icon(Icons.add), label: const Text('New')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: DropdownButtonFormField<int?>(
                initialValue: s.projectId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Project', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All projects')),
                  ...s.projects.map((p) => DropdownMenuItem<int?>(value: p.id, child: Text('${p.code} · ${p.name}', overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => n.setProject(v),
              ),
            ),
            if (s.error != null) Padding(padding: const EdgeInsets.all(8), child: Text(s.error!, style: const TextStyle(color: AppColors.danger))),
            Expanded(
              child: s.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(children: [
                      _surveyList(s.surveys, n),
                      _deliveryList(s.deliveries),
                    ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String status) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: (_statusColors[status] ?? Colors.grey).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColors[status] ?? Colors.grey)),
      );

  Widget _surveyList(List<SiteSurvey> list, SiteLogisticsNotifier n) {
    if (list.isEmpty) return const Center(child: Text('No surveys yet.', style: TextStyle(color: Colors.grey)));
    return RefreshIndicator(
      onRefresh: () => n.load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        itemBuilder: (c, i) {
          final v = list[i];
          return Card(
            child: ListTile(
              title: Text(v.surveyNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${v.location ?? '—'} · ${v.items.length} item(s) · ${v.photos.length} photo(s)'),
              trailing: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                _chip(v.status),
                if (v.status == 'DRAFT') TextButton(onPressed: () => n.submitSurvey(v.id), child: const Text('Submit')),
                if (v.status == 'SUBMITTED') TextButton(onPressed: () => n.approveSurvey(v.id), child: const Text('Approve')),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _deliveryList(List<SiteDelivery> list) {
    if (list.isEmpty) return const Center(child: Text('No deliveries yet.', style: TextStyle(color: Colors.grey)));
    return RefreshIndicator(
      onRefresh: () => ref.read(siteLogisticsProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        itemBuilder: (c, i) {
          final d = list[i];
          return Card(
            child: ListTile(
              title: Text(d.deliveryNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${d.vehicleNo ?? '—'} · ${d.items.length} item(s) · ${d.photos.length} photo(s)${d.receivedBy != null ? ' · by ${d.receivedBy}' : ''}'),
              trailing: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                _chip(d.status),
                if (d.status != 'CONFIRMED') TextButton(onPressed: () => _confirmDelivery(d), child: const Text('Confirm')),
              ]),
            ),
          );
        },
      ),
    );
  }
}
