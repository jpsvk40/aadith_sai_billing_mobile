import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/app_user_model.dart';
import '../providers/user_admin_providers.dart';

/// Create / edit a company user — parity with the web User Management invite form:
/// Name*, Email* (create only), Password* (create only), Role, grouped module toggles
/// (driven by /api/catalog/access), AI Assistant switch, and a Representative picker
/// (only for sales_rep / collection_rep, create only).
class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({super.key, this.editUser});
  final AppUser? editUser;
  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  late String _role;
  final Set<String> _modules = {};
  bool _ai = true;

  List<RepOption> _reps = const [];
  int? _repId;
  bool _repsLoading = false;
  bool _saving = false;

  // Assignable roles (never `admin`) — a fixed vocabulary the backend validates against.
  static const _assignableRoles = <(String, String)>[
    ('sales_rep', 'Sales Rep'),
    ('collection_rep', 'Collection Rep'),
    ('production', 'Production'),
    ('packing', 'Packing'),
    ('dispatch', 'Dispatch'),
    ('accounts', 'Accounts'),
    ('accountant', 'Accountant'),
    ('manager', 'Manager'),
    ('technician', 'Technician'),
    ('estimator', 'Estimator'),
    ('operator', 'Operator'),
    ('store_manager', 'Store Manager'),
    ('cashier', 'Cashier'),
    ('godown_keeper', 'Godown Keeper'),
    ('wholesale_manager', 'Wholesale Manager'),
    ('mill_supervisor', 'Mill Supervisor'),
  ];

  bool get _isEdit => widget.editUser != null;
  bool get _needsRep => _role == 'sales_rep' || _role == 'collection_rep';

  @override
  void initState() {
    super.initState();
    final e = widget.editUser;
    if (e != null) {
      _name.text = e.name;
      _email.text = e.email;
      _role = _assignableRoles.any((r) => r.$1 == e.role) ? e.role : 'sales_rep';
      _modules.addAll(e.modules);
      _ai = e.aiAssistantAccess;
    } else {
      _role = 'sales_rep';
      // Representative link is only requested on create for rep roles.
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadReps());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadReps() async {
    if (!_needsRep) {
      setState(() {
        _reps = const [];
        _repId = null;
      });
      return;
    }
    setState(() => _repsLoading = true);
    try {
      final reps = await ref.read(userAdminRepositoryProvider).availableReps(_role);
      if (mounted) setState(() => _reps = reps);
    } catch (_) {
      if (mounted) setState(() => _reps = const []);
    } finally {
      if (mounted) setState(() => _repsLoading = false);
    }
  }

  void _onRoleChanged(String? r) {
    if (r == null) return;
    setState(() {
      _role = r;
      _repId = null;
      _reps = const [];
    });
    if (!_isEdit && _needsRep) _loadReps();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.danger : AppColors.success),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Name is required.', error: true);
      return;
    }
    if (!_isEdit) {
      if (_email.text.trim().isEmpty) {
        _snack('Email is required.', error: true);
        return;
      }
      if (_password.text.length < 6) {
        _snack('Password must be at least 6 characters.', error: true);
        return;
      }
      if (_needsRep && _repId == null) {
        _snack('Select a representative to link with this user.', error: true);
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(userAdminRepositoryProvider);
      // Empty selection → inherit ALL company modules (null on create by omission, null on edit to clear).
      final modulesCsv = _modules.isEmpty ? null : _modules.join(',');

      if (_isEdit) {
        await repo.updateUser(widget.editUser!.id, {
          'name': name,
          'role': _role,
          'modules': modulesCsv, // null clears the grant → inherit all company modules
          'aiAssistantAccess': _ai,
        });
      } else {
        await repo.createUser({
          'name': name,
          'email': _email.text.trim(),
          'password': _password.text,
          'role': _role,
          if (modulesCsv != null) 'modules': modulesCsv,
          'aiAssistantAccess': _ai,
          if (_needsRep && _repId != null) 'representativeId': _repId,
        });
      }
      if (!mounted) return;
      ref.invalidate(usersProvider);
      _snack(_isEdit ? 'User updated.' : 'User created.');
      context.pop();
    } catch (e) {
      if (mounted) _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(accessCatalogProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? 'Edit User' : 'New User')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _section('Details', Icons.person_outline, [
          _field(_name, 'Name *'),
          _field(_email, 'Email *', keyboard: TextInputType.emailAddress, enabled: !_isEdit),
          if (!_isEdit) _field(_password, 'Password * (min 6 characters)', obscure: true),
          DropdownButtonFormField<String>(
            initialValue: _role,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder(), isDense: true),
            items: _assignableRoles
                .map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)))
                .toList(),
            onChanged: _onRoleChanged,
          ),
          const SizedBox(height: 14),
          if (!_isEdit && _needsRep) _repPicker(),
        ]),
        _section('Module Access', Icons.tune, [
          const Text(
            'Choose which modules this user can access. Leave empty for access to all company modules.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          catalogAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (e, _) => Text('Could not load modules: $e', style: const TextStyle(fontSize: 12, color: AppColors.danger)),
            data: (cat) => _moduleGroups(cat),
          ),
          const SizedBox(height: 6),
        ]),
        _section('AI Assistant', Icons.auto_awesome, [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _ai,
            onChanged: (v) => setState(() => _ai = v),
            title: const Text('Allow "Ask your business" AI assistant', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            subtitle: const Text('On by default. Turn off to block the assistant for this user.', style: TextStyle(fontSize: 11.5)),
          ),
        ]),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : (_isEdit ? 'Update User' : 'Create User')),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _repPicker() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DropdownButtonFormField<int>(
        initialValue: _repId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: _role == 'collection_rep' ? 'Link to Collection Rep *' : 'Link to Sales Rep *',
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: _repsLoading
              ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
              : null,
        ),
        items: _reps.map((r) => DropdownMenuItem(value: r.id, child: Text(r.label, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => _repId = v),
      ),
      if (!_repsLoading && _reps.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'No unlinked representatives found. Create one on the web portal first.',
            style: TextStyle(fontSize: 11.5, color: AppColors.danger),
          ),
        ),
      const SizedBox(height: 14),
    ]);
  }

  Widget _moduleGroups(AccessCatalog cat) {
    if (!cat.hasAnyCompanyModules) {
      return const Text(
        'No company modules are enabled to assign.',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      );
    }
    final groupWidgets = <Widget>[];
    for (final g in cat.groups) {
      final mods = cat.companyModulesInGroup(g.key);
      if (mods.isEmpty) continue;
      groupWidgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          g.label.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: AppColors.textMuted),
        ),
      ));
      groupWidgets.add(Wrap(
        spacing: 8,
        runSpacing: 4,
        children: mods.map((m) {
          final selected = _modules.contains(m.key);
          return FilterChip(
            label: Text(m.label, style: const TextStyle(fontSize: 12)),
            selected: selected,
            onSelected: (v) => setState(() => v ? _modules.add(m.key) : _modules.remove(m.key)),
            showCheckmark: true,
            selectedColor: AppColors.primaryLight,
            checkmarkColor: AppColors.primary,
          );
        }).toList(),
      ));
      groupWidgets.add(const SizedBox(height: 12));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: groupWidgets);
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 17, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ]),
      );

  Widget _field(TextEditingController c, String label, {TextInputType? keyboard, bool obscure = false, bool enabled = true}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          obscureText: obscure,
          enabled: enabled,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        ),
      );
}
