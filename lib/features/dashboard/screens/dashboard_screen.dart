import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/startup_diagnostics.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    StartupDiagnostics.reportAsync('Dashboard screen build');
    final state = ref.watch(dashboardProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (user?.companyName != null)
              Text(user!.companyName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          if (user?.hasModule('alerts') == true)
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.go('/alerts'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(dashboardProvider.notifier).load(),
          ),
        ],
      ),
      body: state.isLoading && state.stats == null
          ? const LoadingIndicator(message: 'Loading dashboard...')
          : state.error != null && state.stats == null
              ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(dashboardProvider.notifier).load())
              : _buildContent(state, user),
    );
  }

  Widget _buildContent(DashboardState state, dynamic user) {
    final stats = state.stats;
    if (stats == null) return const LoadingIndicator();

    final canOrders = user?.hasModule('orders') == true;
    final canInvoices = user?.hasModule('invoices') == true;
    final canPayments = user?.hasModule('payments') == true;
    final canCollections = user?.hasModule('collections') == true;

    return RefreshIndicator(
      onRefresh: () => ref.read(dashboardProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hello, ${user?.name ?? 'User'}!', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Here is your business overview',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _StatCard(
                label: 'Monthly Revenue',
                value: CurrencyUtils.formatCompact(stats.monthlyRevenue),
                icon: Icons.trending_up,
                color: AppColors.primary,
                onTap: canInvoices ? () => context.go('/invoices') : null,
              ),
              _StatCard(
                label: 'Outstanding',
                value: CurrencyUtils.formatCompact(stats.outstandingAmount),
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.warning,
                onTap: canInvoices ? () => context.go('/invoices') : null,
              ),
              _StatCard(
                label: 'Total Orders',
                value: stats.totalOrders.toString(),
                icon: Icons.receipt_long_outlined,
                color: AppColors.success,
                onTap: canOrders ? () => context.go('/orders') : null,
              ),
              _StatCard(
                label: 'Pending Orders',
                value: stats.pendingOrders.toString(),
                icon: Icons.pending_outlined,
                color: AppColors.danger,
                onTap: canOrders ? () => context.go('/orders') : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (canOrders || canPayments || canCollections) ...[
            Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                if (canOrders)
                  Expanded(child: _ActionButton(icon: Icons.add_circle_outline, label: 'New Order', onTap: () => context.go('/orders/create'))),
                if (canOrders && (canPayments || canCollections)) const SizedBox(width: 12),
                if (canPayments)
                  Expanded(child: _ActionButton(icon: Icons.payment_outlined, label: 'Record Payment', onTap: () => context.go('/payments/record'))),
                if (canPayments && canCollections) const SizedBox(width: 12),
                if (canCollections)
                  Expanded(child: _ActionButton(icon: Icons.list_alt_outlined, label: 'Collections', onTap: () => context.go('/collections'))),
              ],
            ),
            const SizedBox(height: 20),
          ],
          if (stats.unreadAlerts > 0 && user?.hasModule('alerts') == true) ...[
            _AlertBanner(count: stats.unreadAlerts, onTap: () => context.go('/alerts')),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 26),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _AlertBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.notifications_active, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You have $count unread alert${count > 1 ? 's' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
