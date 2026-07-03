import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/site_logistics_model.dart';
import '../providers/site_logistics_provider.dart';

class SurveyFormScreen extends ConsumerStatefulWidget {
  const SurveyFormScreen({super.key});
  @override
  ConsumerState<SurveyFormScreen> createState() => _SurveyFormScreenState();
}

class _ItemRow {
  final openingRef = TextEditingController();
  final description = TextEditingController();
  final width = TextEditingController();
  final height = TextEditingController();
  final qty = TextEditingController(text: '1');
}

class _SurveyFormScreenState extends ConsumerState<SurveyFormScreen> {
  int? _projectId;
  final _location = TextEditingController();
  final _surveyedBy = TextEditingController();
  final List<_ItemRow> _rows = [_ItemRow()];
  final List<SitePhoto> _photos = [];
  bool _saving = false;
  bool _uploading = false;

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Take Photo'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from Gallery'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
      ])),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 82);
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final photo = await ref.read(siteLogisticsProvider.notifier).repo.uploadPhoto(file.path);
      setState(() => _photos.add(photo));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo upload needs storage configured: $e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_projectId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a project.'))); return; }
    final items = _rows.where((r) => r.description.text.trim().isNotEmpty).map((r) => {
          'openingRef': r.openingRef.text.trim(),
          'description': r.description.text.trim(),
          'width': double.tryParse(r.width.text) ?? 0,
          'height': double.tryParse(r.height.text) ?? 0,
          'quantity': double.tryParse(r.qty.text) ?? 1,
        }).toList();
    if (items.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one measured item.'))); return; }
    setState(() => _saving = true);
    try {
      final n = ref.read(siteLogisticsProvider.notifier);
      await n.repo.createSurvey({
        'projectId': _projectId,
        'location': _location.text.trim(),
        'surveyedBy': _surveyedBy.text.trim(),
        'items': items,
        'photos': _photos.map((p) => p.toJson()).toList(),
      });
      await n.load();
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Survey created.'))); context.pop(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(siteLogisticsProvider).projects;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Site Survey')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<int>(
          initialValue: _projectId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Project *', border: OutlineInputBorder()),
          items: projects.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.code} · ${p.name}', overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _projectId = v),
        ),
        const SizedBox(height: 12),
        TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location (tower / floor / area)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _surveyedBy, decoration: const InputDecoration(labelText: 'Surveyed by', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        const Text('Measured openings', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._rows.asMap().entries.map((e) => _itemCard(e.key, e.value)),
        TextButton.icon(onPressed: () => setState(() => _rows.add(_ItemRow())), icon: const Icon(Icons.add), label: const Text('Add opening')),
        const Divider(height: 24),
        Row(children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: _uploading ? null : _addPhoto,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(_uploading ? 'Uploading…' : 'Add photo'),
          ),
          const SizedBox(width: 12),
          Text('${_photos.length} photo(s)', style: const TextStyle(color: Colors.grey)),
        ]),
        if (_photos.any((p) => p.url != null))
          Padding(padding: const EdgeInsets.only(top: 10), child: Wrap(spacing: 8, children: _photos.where((p) => p.url != null).map((p) => ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(p.url!, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image)))).toList())),
        const SizedBox(height: 20),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Create survey')),
      ]),
    );
  }

  Widget _itemCard(int i, _ItemRow r) => Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(children: [
            Row(children: [
              Expanded(flex: 2, child: TextField(controller: r.openingRef, decoration: const InputDecoration(labelText: 'Ref', isDense: true))),
              const SizedBox(width: 8),
              Expanded(flex: 4, child: TextField(controller: r.description, decoration: const InputDecoration(labelText: 'Description', isDense: true))),
              if (_rows.length > 1) IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _rows.removeAt(i))),
            ]),
            Row(children: [
              Expanded(child: TextField(controller: r.width, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'W (mm)', isDense: true))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: r.height, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'H (mm)', isDense: true))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: r.qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty', isDense: true))),
            ]),
          ]),
        ),
      );
}
