import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/platform_company_model.dart';
import '../../../data/repositories/super_admin_repository.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/super_admin_providers.dart';
import '../widgets/sa_kit.dart';

/// Super Admin · Company detail — the full-screen lifecycle manager for one
/// tenant. Header + primary admin + stats up top; a "LIFECYCLE" action deck
/// (status-aware primary action + a grid of one-tap operations); and a
/// confirm-gated danger zone at the bottom. Every mutation confirms first,
/// then refreshes this screen + the companies list + the platform dashboard.
class CompanyDetailScreen extends ConsumerStatefulWidget {
  final int companyId;
  const CompanyDetailScreen({super.key, required this.companyId});

  @override
  ConsumerState<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends ConsumerState<CompanyDetailScreen> {
  bool _busy = false;

  SuperAdminRepository get _repo => ref.read(superAdminRepositoryProvider);

  // ─── Action plumbing ───

  Future<bool?> _confirm(String title, String body, {String confirmLabel = 'Confirm', bool danger = false}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text(body, style: const TextStyle(fontSize: 13.5, height: 1.4, color: saSlate)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: saMuted, fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: danger ? saRose : saIndigo),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  /// Runs [action], showing feedback and refreshing dependent providers.
  /// (Confirmation, if any, is handled by the caller.)
  Future<void> _perform(Future<void> Function() action, String successMsg) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(companyDetailProvider(widget.companyId));
      ref.invalidate(companiesProvider);
      ref.invalidate(platformDashboardProvider);
      messenger.showSnackBar(_snack(successMsg, ok: true));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(_snack(_errText(e), ok: false));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndRun({
    required String title,
    required String body,
    required Future<void> Function() action,
    required String successMsg,
    String confirmLabel = 'Confirm',
    bool danger = false,
  }) async {
    final ok = await _confirm(title, body, confirmLabel: confirmLabel, danger: danger);
    if (ok != true) return;
    await _perform(action, successMsg);
  }

  SnackBar _snack(String msg, {required bool ok}) => SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
        content: Row(
          children: [
            Icon(ok ? Icons.check_circle_outline : Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Text(msg,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      );

  String _errText(Object e) {
    var s = e.toString();
    if (s.startsWith('Exception: ')) s = s.substring('Exception: '.length);
    s = s.trim();
    return s.isEmpty ? 'Something went wrong' : s;
  }

  // ─── Dialog-gated actions (own dialog is the confirmation) ───

  Future<void> _pickEdition(PlatformCompany c) async {
    const options = ['billing', 'billing_books', 'erp'];
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: saSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(color: saBorder, borderRadius: BorderRadius.circular(3)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Plan & edition',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: saInk)),
              ),
            ),
            for (final opt in options)
              ListTile(
                onTap: () => Navigator.pop(ctx, opt),
                leading: Icon(Icons.workspace_premium_outlined,
                    color: opt == c.edition ? saEmerald : saMuted),
                title: Text(saEditionLabel(opt),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: saInk)),
                trailing: opt == c.edition ? const Icon(Icons.check_circle, color: saEmerald, size: 20) : null,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || choice == c.edition || !mounted) return;
    await _confirmAndRun(
      title: 'Change edition?',
      body: 'Set ${c.name} to the ${saEditionLabel(choice)} plan?',
      confirmLabel: 'Change',
      action: () => _repo.setEdition(c.id, choice),
      successMsg: 'Edition updated to ${saEditionLabel(choice)}',
    );
  }

  Future<void> _editAdminEmail(PlatformCompany c) async {
    final ctrl = TextEditingController(text: c.primaryAdmin?.email ?? c.billingEmail ?? '');
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update admin email', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'New primary-admin email',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: saMuted, fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: saIndigo),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (email == null || email.isEmpty || email == (c.primaryAdmin?.email ?? '') || !mounted) return;
    await _confirmAndRun(
      title: 'Update admin email?',
      body: 'Change the primary-admin email for ${c.name} to $email?',
      confirmLabel: 'Update',
      action: () => _repo.updateAdminEmail(c.id, email),
      successMsg: 'Admin email updated',
    );
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(companyDetailProvider(widget.companyId));
    return async.when(
      loading: () => Scaffold(
        backgroundColor: saBg,
        appBar: _appBar('Company'),
        body: const LoadingIndicator(),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: saBg,
        appBar: _appBar('Company'),
        body: ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(companyDetailProvider(widget.companyId)),
        ),
      ),
      data: (c) => Scaffold(
        backgroundColor: saBg,
        appBar: _appBar(c.name),
        body: _content(context, c),
      ),
    );
  }

  PreferredSizeWidget _appBar(String title) => AppBar(
        backgroundColor: saSurface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: saInk,
        elevation: 0.5,
        title: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      );

  Widget _content(BuildContext context, PlatformCompany c) {
    // Status-aware primary action.
    late final String pLabel;
    late final IconData pIcon;
    late final Future<void> Function() pRun;
    late final String pSuccess;
    late final String pBody;
    switch (c.status) {
      case 'pending_review':
        pLabel = 'Approve 30-day trial';
        pIcon = Icons.rocket_launch_outlined;
        pRun = () => _repo.approveTrial(c.id);
        pSuccess = 'Trial approved';
        pBody = 'Approve a 30-day trial for ${c.name}?';
      case 'trial_active':
      case 'trial_expired':
        pLabel = 'Activate subscription';
        pIcon = Icons.credit_card_outlined;
        pRun = () => _repo.activateSubscription(c.id);
        pSuccess = 'Subscription activated';
        pBody = 'Activate a paid subscription for ${c.name}?';
      default:
        pLabel = 'Extend / renew subscription';
        pIcon = Icons.autorenew;
        pRun = () => _repo.activateSubscription(c.id);
        pSuccess = 'Subscription renewed';
        pBody = 'Renew the subscription for ${c.name}?';
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 32),
          children: [
            _headerCard(c),
            const SizedBox(height: 12),
            _adminCard(c),
            const SizedBox(height: 12),
            _statRow(c),
            const SizedBox(height: 12),
            _detailsCard(c),
            _label('Lifecycle'),
            _primaryAction(
              pLabel,
              pIcon,
              () => _confirmAndRun(
                title: 'Confirm action',
                body: pBody,
                confirmLabel: 'Continue',
                action: pRun,
                successMsg: pSuccess,
              ),
            ),
            const SizedBox(height: 10),
            _grid([
              _actionTile(
                icon: Icons.more_time_outlined,
                label: 'Extend +30d',
                tint: saSky,
                onTap: () => _confirmAndRun(
                  title: 'Extend trial?',
                  body: 'Add 30 more days to the trial for ${c.name}?',
                  confirmLabel: 'Extend',
                  action: () => _repo.extendTrial(c.id, extraDays: 30),
                  successMsg: 'Trial extended 30 days',
                ),
              ),
              _actionTile(
                icon: Icons.credit_card_outlined,
                label: 'Activate sub',
                tint: saEmerald,
                onTap: () => _confirmAndRun(
                  title: 'Activate subscription?',
                  body: 'Activate a paid subscription for ${c.name}?',
                  confirmLabel: 'Activate',
                  action: () => _repo.activateSubscription(c.id),
                  successMsg: 'Subscription activated',
                ),
              ),
              _actionTile(
                icon: Icons.lock_reset,
                label: 'Reset password',
                tint: saRose,
                onTap: () => _confirmAndRun(
                  title: 'Reset admin password?',
                  body: 'Send a password reset for the primary admin of ${c.name}?',
                  confirmLabel: 'Reset',
                  action: () => _repo.resetAdminPassword(c.id),
                  successMsg: 'Password reset issued',
                ),
              ),
              _actionTile(
                icon: Icons.tune_rounded,
                label: 'Plan & edition',
                tint: saIndigo,
                onTap: () => _pickEdition(c),
              ),
              _actionTile(
                icon: Icons.alternate_email_rounded,
                label: 'Update admin email',
                tint: saBlue,
                onTap: () => _editAdminEmail(c),
              ),
              _actionTile(
                icon: Icons.pause_circle_outline,
                label: 'Suspend',
                tint: saAmber,
                warn: true,
                onTap: () => _confirmAndRun(
                  title: 'Suspend company?',
                  body: '${c.name} will lose access until re-activated. Continue?',
                  confirmLabel: 'Suspend',
                  danger: true,
                  action: () => _repo.suspend(c.id),
                  successMsg: 'Company suspended',
                ),
              ),
            ]),
            const SizedBox(height: 18),
            _dangerZone(c),
          ],
        ),
        if (_busy)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2.5, color: saIndigo, backgroundColor: Colors.transparent),
          ),
      ],
    );
  }

  // ─── Sections ───

  Widget _headerCard(PlatformCompany c) {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SaLogo(c.name, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: saInk, height: 1.1)),
                    const SizedBox(height: 7),
                    SaStatusPill(c.status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: saLine),
          const SizedBox(height: 12),
          Text(
            '${saMarketFlag(c.market)} ${saMarketLabel(c.market)}  ·  ${saEditionLabel(c.edition)}  ·  created ${saShortDate(c.createdAt)}',
            style: const TextStyle(fontSize: 12, color: saSlate, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _adminCard(PlatformCompany c) {
    final flagged = c.adminNeedsReset;
    final email = c.primaryAdmin?.email ?? c.billingEmail ?? '—';
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (flagged ? saRose : saIndigo).withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(flagged ? Icons.lock_outline : Icons.person_outline,
                    size: 19, color: flagged ? saRose : saIndigo),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Primary admin${flagged ? ' · flagged for reset' : ''}',
                        style: const TextStyle(fontSize: 10.5, color: saMuted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: saInk)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _confirmAndRun(
                            title: 'Reset admin password?',
                            body: 'Send a password reset for the primary admin of ${c.name}?',
                            confirmLabel: 'Reset',
                            action: () => _repo.resetAdminPassword(c.id),
                            successMsg: 'Password reset issued',
                          ),
                  icon: const Icon(Icons.lock_reset, size: 17),
                  label: const Text('Reset password'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: saInk,
                    side: const BorderSide(color: saBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (flagged) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _confirmAndRun(
                              title: 'Unlock admin login?',
                              body: 'Clear the lock and let the primary admin of ${c.name} sign in again?',
                              confirmLabel: 'Unlock',
                              action: () => _repo.unlockAdminLogin(c.id),
                              successMsg: 'Login unlocked',
                            ),
                    icon: const Icon(Icons.lock_open_outlined, size: 17),
                    label: const Text('Unlock login'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: saRose,
                      side: BorderSide(color: saRose.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _statRow(PlatformCompany c) {
    return Row(
      children: [
        Expanded(child: _statCard('Users', c.usersCount, Icons.group_outlined, saIndigo)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Customers', c.customersCount, Icons.people_alt_outlined, saBlue)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Orders', c.ordersCount, Icons.receipt_long_outlined, saEmerald)),
      ],
    );
  }

  Widget _statCard(String label, int value, IconData icon, Color tint) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      decoration: BoxDecoration(
        color: saSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: saBorder, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(height: 7),
          Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: saInk)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10.5, color: saMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _detailsCard(PlatformCompany c) {
    final rows = <(String, String)>[
      ('Plan', saEditionLabel(c.edition)),
      if (c.maxUsers > 0) ('Seats', '${c.maxUsers}'),
      if (c.trialEndsAt != null) ('Trial ends', saShortDate(c.trialEndsAt)),
      if (c.subscriptionEndsAt != null) ('Renews', saShortDate(c.subscriptionEndsAt)),
    ];
    return SaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: saLine),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(rows[i].$1, style: const TextStyle(fontSize: 12.5, color: saMuted, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(rows[i].$2,
                      style: const TextStyle(fontSize: 13, color: saInk, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: saMuted)),
      );

  Widget _primaryAction(String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: _busy ? null : onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.32), blurRadius: 12, offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(List<Widget> tiles) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final second = i + 1 < tiles.length ? tiles[i + 1] : null;
      // Plain Row + fixed-height tiles keeps the two columns equal height with NO
      // intrinsic-dimension / stretch pass — those are incompatible with the tiles'
      // nested Row(Expanded(Text)) under a ListView (RenderFlex "hasSize").
      rows.add(Row(
        children: [
          Expanded(child: tiles[i]),
          const SizedBox(width: 10),
          Expanded(child: second ?? const SizedBox()),
        ],
      ));
      if (i + 2 < tiles.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color tint,
    required VoidCallback onTap,
    bool warn = false,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _busy ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: saSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: warn ? saAmber.withValues(alpha: 0.5) : saBorder, width: warn ? 1 : 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, size: 16, color: _darken(tint)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: saInk)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dangerZone(PlatformCompany c) {
    // Text block on top, then a full-width Expanded button below (mirrors _adminCard).
    // A BARE button as a non-flex sibling of an Expanded in a Row fails to lay out
    // (Flex measures it under unbounded width → RenderFlex "hasSize").
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: saRose.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: saRose.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: saRose, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Danger zone',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFB91C1C))),
                    SizedBox(height: 2),
                    Text('Cancelling ends billing and revokes tenant access.',
                        style: TextStyle(fontSize: 11, color: saMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _confirmAndRun(
                            title: 'Cancel subscription?',
                            body:
                                'This cancels the subscription for ${c.name} and revokes access. This cannot be undone here. Continue?',
                            confirmLabel: 'Cancel sub',
                            danger: true,
                            action: () => _repo.cancelSubscription(c.id),
                            successMsg: 'Subscription cancelled',
                          ),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancel subscription'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: saRose,
                    side: BorderSide(color: saRose.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _darken(Color c) => Color.lerp(c, Colors.black, 0.28)!;
}
