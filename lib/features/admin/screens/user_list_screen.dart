import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/app_user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/user_admin_providers.dart';

/// User / RBAC-lite admin — mirrors the web User Management page:
/// list (Name · Email · Role · Module Access chips · Status · Actions), a seat banner,
/// a New User FAB (disabled at seat cap), and per-row Edit / Reset Password / Deactivate.
///
/// Admin-only: the whole surface is gated to `role == 'admin'` (the backend also enforces
/// `authorize('admin')`).
class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});
  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen> {
  int? _resettingId;

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.danger : AppColors.success),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(usersProvider);
    await ref.read(usersProvider.future);
  }

  Future<void> _openForm({AppUser? edit}) async {
    if (edit == null) {
      await context.push('/settings/users/new');
    } else {
      await context.push('/settings/users/${edit.id}/edit', extra: edit);
    }
    if (mounted) ref.invalidate(usersProvider);
  }

  Future<void> _toggleActive(AppUser u) async {
    try {
      await ref.read(userAdminRepositoryProvider).updateUser(u.id, {'isActive': !u.isActive});
      if (!mounted) return;
      _snack('User ${u.isActive ? 'deactivated' : 'activated'}.');
      ref.invalidate(usersProvider);
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _confirmReset(AppUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: Text(
          'Issue a one-time temporary password for ${u.name} (${u.email})?\n\n'
          'Their old password stops working right away. No email is sent — you hand the new one over directly.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _resettingId = u.id);
    try {
      final temp = await ref.read(userAdminRepositoryProvider).resetPassword(u.id);
      if (!mounted) return;
      await _showTempPassword(u, temp);
    } catch (e) {
      if (mounted) _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _resettingId = null);
    }
  }

  /// Shows the temp password ONCE with a copy-to-clipboard button.
  Future<void> _showTempPassword(AppUser u, String temp) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Temporary password ready'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Give this to ${u.name} (${u.email}). They sign in with it right away, then set '
              'their own under Change Password.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                Expanded(
                  child: SelectableText(
                    temp.isEmpty ? '—' : temp,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: AppColors.textPrimary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy, size: 20, color: AppColors.primary),
                  onPressed: temp.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: temp));
                          _snack('Temporary password copied.');
                        },
                ),
              ]),
            ),
            const SizedBox(height: 10),
            const Text(
              'Shown only once. Their old password no longer works.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;

    // RBAC gate — this whole surface is admin-only.
    if (currentUser?.role != 'admin') {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Users')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline, size: 46, color: AppColors.textMuted),
              SizedBox(height: 14),
              Text('Only an admin can manage users',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            ]),
          ),
        ),
      );
    }

    final usersAsync = ref.watch(usersProvider);
    final labels = ref.watch(accessCatalogProvider).valueOrNull?.labelByKey ?? const <String, String>{};
    final data = usersAsync.valueOrNull;
    final capReached = data?.$2.seatCapReached ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Users')),
      floatingActionButton: data == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: capReached ? AppColors.textMuted : null,
              onPressed: capReached
                  ? () => _snack(
                        'Seat limit reached (${data.$2.activeUserCount}/${data.$2.maxUsers}). '
                        'Increase the company user limit to add another user.',
                        error: true,
                      )
                  : () => _openForm(),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('New User'),
            ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _error('$e'),
        data: (tuple) {
          final users = tuple.$1;
          final meta = tuple.$2;
          return Column(children: [
            _seatBanner(meta),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: users.isEmpty
                    ? _empty()
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) => _userCard(users[i], labels),
                      ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _seatBanner(UserMeta meta) {
    final reached = meta.seatCapReached;
    final bg = reached ? const Color(0xFFFFF3CD) : const Color(0xFFEEF6FF);
    final fg = reached ? const Color(0xFF92400E) : const Color(0xFF1D4ED8);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        'Active users: ${meta.activeUserCount} / ${meta.maxUsers}'
        '${reached ? '  —  user limit reached for this company.' : ''}',
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _userCard(AppUser u, Map<String, String> labels) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(u.email, style: const TextStyle(fontSize: 12, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(width: 8),
            _roleBadge(u.role),
            if (!u.isProtectedAdmin) _actionsMenu(u) else const _ProtectedChip(),
          ]),
          const SizedBox(height: 10),
          _moduleChips(u, labels),
          const SizedBox(height: 8),
          Row(children: [
            _statusBadge(u.isActive),
            if (!u.isProtectedAdmin && !u.aiAssistantAccess) ...[
              const SizedBox(width: 6),
              _pill('AI off', const Color(0xFF991B1B), const Color(0xFFFEF2F2)),
            ],
            if (_resettingId == u.id) ...[
              const Spacer(),
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 6),
              const Text('Resetting…', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _moduleChips(AppUser u, Map<String, String> labels) {
    if (u.inheritsAllModules) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _pill('All Modules', const Color(0xFF065F46), const Color(0xFFECFDF5)),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: u.modules
          .map((m) => _pill(labels[m] ?? m, AppColors.primary, AppColors.primaryLight))
          .toList(),
    );
  }

  Widget _actionsMenu(AppUser u) => PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
        onSelected: (v) {
          switch (v) {
            case 'edit':
              _openForm(edit: u);
              break;
            case 'reset':
              _confirmReset(u);
              break;
            case 'toggle':
              _toggleActive(u);
              break;
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'reset', child: Text('Reset Password')),
          PopupMenuItem(value: 'toggle', child: Text(u.isActive ? 'Deactivate' : 'Activate')),
        ],
      );

  Widget _roleBadge(String role) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: _pill(_roleLabel(role), AppColors.primary, AppColors.primaryLight),
      );

  Widget _statusBadge(bool active) => _pill(
        active ? 'Active' : 'Inactive',
        active ? const Color(0xFF065F46) : const Color(0xFF991B1B),
        active ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
      );

  Widget _pill(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
      );

  Widget _empty() => ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.group_outlined, size: 46, color: AppColors.textMuted),
          SizedBox(height: 12),
          Center(child: Text('No users yet. Create your first user.', style: TextStyle(color: AppColors.textMuted))),
        ],
      );

  Widget _error(String e) => ListView(
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.error_outline, size: 42, color: AppColors.danger),
          const SizedBox(height: 12),
          Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(e, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)))),
        ],
      );

  static String _roleLabel(String role) {
    const labels = {
      'admin': 'Admin',
      'sales_rep': 'Sales Rep',
      'collection_rep': 'Collection Rep',
      'production': 'Production',
      'packing': 'Packing',
      'dispatch': 'Dispatch',
      'accounts': 'Accounts',
      'accountant': 'Accountant',
      'manager': 'Manager',
      'technician': 'Technician',
      'estimator': 'Estimator',
      'operator': 'Operator',
      'store_manager': 'Store Manager',
      'cashier': 'Cashier',
      'godown_keeper': 'Godown Keeper',
      'wholesale_manager': 'Wholesale Manager',
      'mill_supervisor': 'Mill Supervisor',
    };
    return labels[role] ?? role;
  }
}

class _ProtectedChip extends StatelessWidget {
  const _ProtectedChip();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(left: 4),
        child: Tooltip(
          message: 'The admin account is managed by a Super Admin',
          child: Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted),
        ),
      );
}
