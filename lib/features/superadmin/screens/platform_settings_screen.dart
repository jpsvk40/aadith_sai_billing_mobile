import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/sa_kit.dart';

/// Darken an accent a touch so it stays legible on white / on its own tint.
Color _shade(Color c) => Color.lerp(c, Colors.black, 0.28)!;

/// A single platform-settings destination. The mobile screens for these don't
/// exist yet — each row nudges the operator to the web portal for this pass.
class _Setting {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _Setting(this.icon, this.color, this.title, this.subtitle);
}

const _group1 = <_Setting>[
  _Setting(Icons.credit_card, saBlue, 'Platform fee & payouts', 'Per-company Stripe fee · Connect status'),
  _Setting(Icons.science, saIndigo, 'Demo accounts', 'Reset & reseed demo tenants'),
  _Setting(Icons.smart_toy, saEmerald, 'AI usage & cost', 'Tokens, spend by tenant, consent'),
];

const _group2 = <_Setting>[
  _Setting(Icons.campaign, saAmber, 'Broadcast to tenants', 'Maintenance & release notices'),
  _Setting(Icons.receipt_long, saSky, 'Platform activity log', 'Approvals, resets, edits — audit'),
  _Setting(Icons.public, saRose, 'Public site & support', 'Marketing site · support inbox'),
];

/// Platform-level settings for the super admin: fee/payouts, demo tenants, AI
/// usage, broadcasts, the audit log, and sign out. Deliberately separate from
/// any tenant business settings.
class PlatformSettingsScreen extends ConsumerWidget {
  const PlatformSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authProvider).user?.email ?? '—';
    return Scaffold(
      backgroundColor: saBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const Text(
              'Platform',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: saInk, letterSpacing: -0.3),
            ),
            const SizedBox(height: 4),
            Text(
              'Signed in as super admin · $email',
              style: const TextStyle(fontSize: 12.5, color: saMuted, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            SaCard(padding: EdgeInsets.zero, child: Column(children: _rows(context, _group1))),
            const SizedBox(height: 14),
            SaCard(padding: EdgeInsets.zero, child: Column(children: _rows(context, _group2))),
            const SizedBox(height: 22),
            _signOutButton(ref),
          ],
        ),
      ),
    );
  }

  List<Widget> _rows(BuildContext context, List<_Setting> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(const Divider(height: 1, thickness: 0.5, color: saLine));
      out.add(_settingRow(context, items[i]));
    }
    return out;
  }

  Widget _settingRow(BuildContext context, _Setting s) {
    return InkWell(
      onTap: () {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('Manage this on the web portal for now')),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(s.icon, size: 18, color: _shade(s.color)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: saInk)),
                  const SizedBox(height: 2),
                  Text(s.subtitle, style: const TextStyle(fontSize: 11.5, color: saMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: saMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _signOutButton(WidgetRef ref) {
    return Material(
      color: saRose.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => ref.read(authProvider.notifier).logout(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: saRose.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, size: 18, color: _shade(saRose)),
              const SizedBox(width: 9),
              Text(
                'Sign out',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _shade(saRose)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
