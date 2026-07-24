import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/product_model.dart';
import '../../../widgets/common/list_controls.dart';
import '../providers/product_admin_providers.dart';

/// Product master list — parity with the web Products page: search + rows showing
/// product name, SKU, category and selling price, with a New FAB.
class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});
  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  ListFilterState _filters = ListFilterState();
  SortSpec? _sort;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(productListProvider.notifier).load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(productListProvider.notifier).setSearch(q);
    });
  }

  /// Distinct, non-empty, sorted values for a select filter's options.
  List<String> _distinct(Iterable<String?> values) {
    return values
        .where((v) => v != null && v.trim().isNotEmpty)
        .map((v) => v!.trim())
        .toSet()
        .toList()
      ..sort();
  }

  /// Applies client-side category filter + sort over the server-searched list.
  List<ProductDetail> _visible(ProductListState s) {
    var list = s.products;

    final category = _filters.select('category');
    if (category != null) {
      list = list.where((p) => (p.category ?? '') == category).toList();
    }

    if (_sort != null) {
      list = applySort<ProductDetail>(list, _sort!, (p, key) {
        switch (key) {
          case 'name':
            return p.productName.toLowerCase();
          case 'category':
            return p.category?.toLowerCase();
          case 'price':
            return p.sellingPrice;
        }
        return null;
      });
    }
    return list;
  }

  Future<void> _openFilters() async {
    final s = ref.read(productListProvider);
    final categories = _distinct(s.products.map((p) => p.category));
    final res = await showListFilterSheet(
      context,
      initial: _filters,
      showPeriods: false,
      showDateRange: false,
      selects: [
        if (categories.isNotEmpty) SelectFilter(key: 'category', label: 'Category', options: categories),
      ],
    );
    if (res != null) setState(() => _filters = res);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productListProvider);
    final visible = _visible(state);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/products/new');
          if (mounted) ref.read(productListProvider.notifier).load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Product'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search name, SKU, category…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
          ),
          FilterSortButtons(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            activeFilterCount: _filters.activeCount,
            onFilterTap: _openFilters,
            sortOptions: const [
              SortSpec('name', 'Name'),
              SortSpec('category', 'Category'),
              SortSpec('price', 'Price'),
            ],
            currentSort: _sort,
            onSortChanged: (s) => setState(() => _sort = s),
          ),
          const Divider(height: 1),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? _error(state.error!)
                    : state.products.isEmpty
                        ? _empty()
                        : RefreshIndicator(
                            onRefresh: () => ref.read(productListProvider.notifier).load(),
                            child: visible.isEmpty
                                ? _empty()
                                : ListView.separated(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: visible.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (ctx, i) => _row(visible[i]),
                                  ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _row(ProductDetail p) {
    return InkWell(
      onTap: () async {
        await context.push('/products/${p.id}/edit');
        if (mounted) ref.read(productListProvider.notifier).load();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(p.productName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (!p.isActive) ...[
                      const SizedBox(width: 8),
                      _chip('INACTIVE', AppColors.textMuted),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    '${p.sku?.isNotEmpty == true ? p.sku : '—'}${p.category?.isNotEmpty == true ? '  ·  ${p.category}' : ''}${p.unit?.isNotEmpty == true ? '  ·  ${p.unit}' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(CurrencyUtils.format(p.sellingPrice), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('GST ${p.taxPercent.toStringAsFixed(p.taxPercent == p.taxPercent.roundToDouble() ? 0 : 2)}%', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
      );

  Widget _empty() => ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.category_outlined, size: 46, color: AppColors.textMuted),
          SizedBox(height: 12),
          Center(child: Text('No products yet.', style: TextStyle(color: AppColors.textMuted))),
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
}
