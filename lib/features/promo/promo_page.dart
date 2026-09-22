import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formatters.dart';
import '../../models/pagination_info.dart';
import '../../models/promo.dart';
import '../../models/promo_cafe.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_layout.dart';
import '../../shared/widgets/app_toast.dart';
import '../product/data/product_repository.dart';
import 'data/promo_cafe_repository.dart';
import 'data/promo_repository.dart';
import 'widgets/promo_cafe_form_dialog.dart';
import 'widgets/promo_form_dialog.dart';

enum _PromoTab { billing, cafe }

class PromoPage extends StatefulWidget {
  const PromoPage({super.key});

  @override
  State<PromoPage> createState() => _PromoPageState();
}

class _PromoPageState extends State<PromoPage> {
  static const _perPage = 10;

  final _repository = PromoRepository();
  final _cafeRepository = PromoCafeRepository();
  final _productRepository = ProductRepository();

  _PromoTab _tab = _PromoTab.billing;

  List<Promo> _promos = [];
  PaginationInfo _pagination = PaginationInfo.empty;
  bool _loading = true;
  String? _error;

  List<PromoCafe> _promoCafes = [];
  PaginationInfo _cafePagination = PaginationInfo.empty;
  bool _loadingCafe = true;
  String? _cafeError;

  /// id -> name, used only to show which products a cafe promo covers in
  /// the list (the promo itself only carries product ids).
  Map<int, String> _productNames = {};

  @override
  void initState() {
    super.initState();
    _load(1);
    _loadCafe(1);
    _loadProductNames();
  }

  Future<void> _loadProductNames() async {
    try {
      final products = await _productRepository.getProducts();
      if (!mounted) return;
      setState(() {
        _productNames = {for (final p in products) p.id: p.name};
      });
    } on ProductRepositoryException {
      // Non-critical - the cafe promo row just falls back to "N produk"
      // without names if this fails.
    }
  }

  Future<void> _load(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _repository.getPromos(page: page, perPage: _perPage);
      if (!mounted) return;
      setState(() {
        _promos = result.promos;
        _pagination = result.pagination;
        _loading = false;
      });
    } on PromoRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _goToPage(int page) {
    if (page == _pagination.currentPage || _loading) return;
    _load(page);
  }

  Future<void> _loadCafe(int page) async {
    setState(() {
      _loadingCafe = true;
      _cafeError = null;
    });

    try {
      final result = await _cafeRepository.getPromoCafes(
        page: page,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _promoCafes = result.promos;
        _cafePagination = result.pagination;
        _loadingCafe = false;
      });
    } on PromoCafeRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _cafeError = e.message;
        _loadingCafe = false;
      });
    }
  }

  void _goToCafePage(int page) {
    if (page == _cafePagination.currentPage || _loadingCafe) return;
    _loadCafe(page);
  }

  void _notifyError(String message) {
    AppToast.error(context, message);
  }

  void _notifySuccess(String message) {
    AppToast.success(context, message);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: Text(title, style: AppText.title),
        content: Text(message, style: AppText.bodySecondary),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("TIDAK"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _openAddDialog() async {
    final result = await showDialog<PromoFormResult>(
      context: context,
      builder: (_) => const PromoFormDialog(),
    );
    if (result == null) return;

    try {
      await _repository.addPromo(
        name: result.name,
        type: result.type,
        value: result.value,
        hourGained: result.hourGained,
        validDays: result.validDays,
        validTimeStart: result.validTimeStart,
        validTimeEnd: result.validTimeEnd,
      );
      if (!mounted) return;
      _notifySuccess("Promo ${result.name} berhasil ditambahkan");
      await _load(_pagination.currentPage);
    } on PromoRepositoryException catch (e) {
      if (!mounted) return;
      _notifyError(e.message);
    }
  }

  Future<void> _openEditDialog(Promo promo) async {
    final result = await showDialog<PromoFormResult>(
      context: context,
      builder: (_) => PromoFormDialog(promo: promo),
    );
    if (result == null) return;

    try {
      await _repository.editPromo(
        id: promo.id,
        name: result.name,
        type: result.type,
        value: result.value,
        hourGained: result.hourGained,
        validDays: result.validDays,
        validTimeStart: result.validTimeStart,
        validTimeEnd: result.validTimeEnd,
      );
      if (!mounted) return;
      _notifySuccess("Promo ${result.name} berhasil diperbarui");
      await _load(_pagination.currentPage);
    } on PromoRepositoryException catch (e) {
      if (!mounted) return;
      _notifyError(e.message);
    }
  }

  Future<void> _confirmDelete(Promo promo) async {
    final confirmed = await _confirm(
      title: "Hapus Promo?",
      message: "Apakah Anda yakin akan menghapus promo \"${promo.name}\"?",
      confirmLabel: "YA, HAPUS",
    );
    if (!confirmed) return;

    try {
      await _repository.deletePromo(promo.id);
      if (!mounted) return;
      _notifySuccess("Promo ${promo.name} berhasil dihapus");
      await _load(_pagination.currentPage);
    } on PromoRepositoryException catch (e) {
      if (!mounted) return;
      _notifyError(e.message);
    }
  }

  Future<void> _openAddCafeDialog() async {
    final result = await showDialog<PromoCafeFormResult>(
      context: context,
      builder: (_) => const PromoCafeFormDialog(),
    );
    if (result == null) return;

    try {
      await _cafeRepository.addPromoCafe(
        name: result.name,
        type: result.type,
        value: result.value,
        productIds: result.productIds,
      );
      if (!mounted) return;
      _notifySuccess("Promo ${result.name} berhasil ditambahkan");
      await _loadCafe(_cafePagination.currentPage);
    } on PromoCafeRepositoryException catch (e) {
      if (!mounted) return;
      _notifyError(e.message);
    }
  }

  Future<void> _openEditCafeDialog(PromoCafe promo) async {
    final result = await showDialog<PromoCafeFormResult>(
      context: context,
      builder: (_) => PromoCafeFormDialog(promo: promo),
    );
    if (result == null) return;

    try {
      await _cafeRepository.editPromoCafe(
        id: promo.id,
        name: result.name,
        type: result.type,
        value: result.value,
        productIds: result.productIds,
      );
      if (!mounted) return;
      _notifySuccess("Promo ${result.name} berhasil diperbarui");
      await _loadCafe(_cafePagination.currentPage);
    } on PromoCafeRepositoryException catch (e) {
      if (!mounted) return;
      _notifyError(e.message);
    }
  }

  Future<void> _confirmDeleteCafe(PromoCafe promo) async {
    final confirmed = await _confirm(
      title: "Hapus Promo?",
      message: "Apakah Anda yakin akan menghapus promo \"${promo.name}\"?",
      confirmLabel: "YA, HAPUS",
    );
    if (!confirmed) return;

    try {
      await _cafeRepository.deletePromoCafe(promo.id);
      if (!mounted) return;
      _notifySuccess("Promo ${promo.name} berhasil dihapus");
      await _loadCafe(_cafePagination.currentPage);
    } on PromoCafeRepositoryException catch (e) {
      if (!mounted) return;
      _notifyError(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "Promo",
      subtitle: "Kelola promo diskon",
      showSearch: false,
      activeMenuKey: "promo",
      onMenuSelect: (key) => navigateToMenu(context, key),
      onRefresh: () => _tab == _PromoTab.billing
          ? _load(_pagination.currentPage)
          : _loadCafe(_cafePagination.currentPage),
      child: Column(
        children: [
          _buildTabBar(),
          const SizedBox(height: 16),
          Expanded(
            child: _tab == _PromoTab.billing
                ? _buildBillingCard()
                : _buildCafeCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Row(
      children: [
        _tabChip(_PromoTab.billing, "Billing", Icons.table_bar_outlined),
        const SizedBox(width: 10),
        _tabChip(_PromoTab.cafe, "Cafe", Icons.local_cafe_outlined),
      ],
    );
  }

  Widget _tabChip(_PromoTab tab, String label, IconData icon) {
    final active = _tab == tab;

    return InkWell(
      onTap: () => setState(() => _tab = tab),
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: .15) : null,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppText.body.copyWith(
                fontWeight: FontWeight.w600,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: _buildBillingToolbar(),
          ),
          const Divider(height: 1, color: AppColors.divider),
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 14, 36, 6),
              child: _PromoRow.header(),
            ),
          Expanded(child: _buildBillingBody()),
          if (!_loading && _error == null && _promos.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.divider),
            Container(
              color: AppColors.background.withValues(alpha: .3),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: _buildPagination(_pagination, _goToPage),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBillingBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorState(_error!, () => _load(_pagination.currentPage));
    }
    if (_promos.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _promos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final promo = _promos[index];
        return _RowCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _PromoRow.data(
              no:
                  (_pagination.currentPage - 1) * _pagination.perPage +
                  index +
                  1,
              promo: promo,
              onEdit: () => _openEditDialog(promo),
              onDelete: () => _confirmDelete(promo),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBillingToolbar() {
    return _buildToolbar(
      title: "Daftar Promo Billing",
      subtitleText: _loading || _error != null
          ? "Memuat data..."
          : "${_pagination.totalItems} promo terdaftar",
      buttonLabel: "Tambah Promo",
      onAdd: _openAddDialog,
    );
  }

  Widget _buildCafeCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: _buildCafeToolbar(),
          ),
          const Divider(height: 1, color: AppColors.divider),
          if (!_loadingCafe && _cafeError == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 14, 36, 6),
              child: _PromoCafeRow.header(),
            ),
          Expanded(child: _buildCafeBody()),
          if (!_loadingCafe && _cafeError == null && _promoCafes.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.divider),
            Container(
              color: AppColors.background.withValues(alpha: .3),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: _buildPagination(_cafePagination, _goToCafePage),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCafeBody() {
    if (_loadingCafe) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_cafeError != null) {
      return _buildErrorState(
        _cafeError!,
        () => _loadCafe(_cafePagination.currentPage),
      );
    }
    if (_promoCafes.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _promoCafes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final promo = _promoCafes[index];
        return _RowCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _PromoCafeRow.data(
              no:
                  (_cafePagination.currentPage - 1) * _cafePagination.perPage +
                  index +
                  1,
              promo: promo,
              productNames: _productNames,
              onEdit: () => _openEditCafeDialog(promo),
              onDelete: () => _confirmDeleteCafe(promo),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCafeToolbar() {
    return _buildToolbar(
      title: "Daftar Promo Cafe",
      subtitleText: _loadingCafe || _cafeError != null
          ? "Memuat data..."
          : "${_cafePagination.totalItems} promo terdaftar",
      buttonLabel: "Tambah Promo",
      onAdd: _openAddCafeDialog,
    );
  }

  Widget _buildToolbar({
    required String title,
    required String subtitleText,
    required String buttonLabel,
    required VoidCallback onAdd,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          child: const Icon(
            Icons.local_offer_outlined,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppText.title.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(subtitleText, style: AppText.caption),
          ],
        ),
        const Spacer(),
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              buttonLabel,
              style: AppText.button.copyWith(fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.textHint.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_offer_outlined,
              size: 30,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 14),
          Text("Belum ada promo ditemukan", style: AppText.bodySecondary),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 30,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.bodySecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Coba Lagi"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(
    PaginationInfo p,
    ValueChanged<int> onPageChange,
  ) {
    final startItem = p.totalItems == 0
        ? 0
        : (p.currentPage - 1) * p.perPage + 1;
    final endItem = (p.currentPage * p.perPage).clamp(0, p.totalItems);

    return Row(
      children: [
        Text(
          "Menampilkan $startItem-$endItem dari ${p.totalItems} promo",
          style: AppText.caption,
        ),
        const Spacer(),
        _pageArrow(
          icon: Icons.chevron_left_rounded,
          onTap: p.hasPrevPage ? () => onPageChange(p.currentPage - 1) : null,
        ),
        const SizedBox(width: 6),
        ..._buildPageButtons(p, onPageChange),
        const SizedBox(width: 6),
        _pageArrow(
          icon: Icons.chevron_right_rounded,
          onTap: p.hasNextPage ? () => onPageChange(p.currentPage + 1) : null,
        ),
      ],
    );
  }

  List<Widget> _buildPageButtons(
    PaginationInfo p,
    ValueChanged<int> onPageChange,
  ) {
    final window = _pageWindow(p.totalPages, p.currentPage);
    final widgets = <Widget>[];

    for (var i = 0; i < window.length; i++) {
      if (i > 0 && window[i] - window[i - 1] > 1) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text("...", style: AppText.caption),
          ),
        );
      }
      widgets.add(
        _pageNumberButton(
          window[i],
          active: window[i] == p.currentPage,
          onTap: () => onPageChange(window[i]),
        ),
      );
      widgets.add(const SizedBox(width: 6));
    }

    return widgets;
  }

  List<int> _pageWindow(int totalPages, int current) {
    if (totalPages <= 7) return List.generate(totalPages, (i) => i + 1);

    final set = <int>{1, totalPages, current};
    if (current - 1 >= 1) set.add(current - 1);
    if (current + 1 <= totalPages) set.add(current + 1);

    return set.toList()..sort();
  }

  Widget _pageNumberButton(
    int page, {
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: active ? null : onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          "$page",
          style: AppText.caption.copyWith(
            color: active ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _pageArrow({required IconData icon, required VoidCallback? onTap}) {
    final enabled = onTap != null;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.textSecondary : AppColors.textHint,
        ),
      ),
    );
  }
}

/// Individual row rendered as its own card, with a hover "lift" effect.
class _RowCard extends StatefulWidget {
  final Widget child;

  const _RowCard({required this.child});

  @override
  State<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<_RowCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.hover
              : AppColors.background.withValues(alpha: .4),
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(
            color: _hovered
                ? AppColors.primary.withValues(alpha: .4)
                : AppColors.border,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}

class _PromoRow extends StatelessWidget {
  final bool header;
  final int? no;
  final Promo? promo;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _PromoRow.header()
    : header = true,
      no = null,
      promo = null,
      onEdit = null,
      onDelete = null;

  const _PromoRow.data({
    required this.no,
    required this.promo,
    required this.onEdit,
    required this.onDelete,
  }) : header = false;

  @override
  Widget build(BuildContext context) {
    if (header) {
      return _row(
        no: _headerText("NO"),
        name: _headerText("NAMA PROMO"),
        type: _headerText("TIPE", alignCenter: true),
        value: _headerText("NILAI", alignEnd: true),
        aksi: _headerText("AKSI", alignCenter: true),
      );
    }

    final p = promo!;
    final cellStyle = AppText.caption.copyWith(fontSize: 13);
    final isPercentage = p.type == PromoType.percentage;
    final typeColor = isPercentage ? AppColors.purple : AppColors.info;

    return _row(
      no: Text("$no", style: cellStyle.copyWith(color: AppColors.textHint)),
      name: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: cellStyle.copyWith(fontWeight: FontWeight.w600),
          ),
          if (p.hasDayRestriction || p.hasTimeWindow) ...[
            const SizedBox(height: 2),
            Text(
              [
                if (p.hasDayRestriction)
                  p.validDays!.map((d) => weekdayLabels[d]).join(", "),
                if (p.hasTimeWindow)
                  "${p.validTimeStart.toString().padLeft(2, '0')}:00-"
                      "${p.validTimeEnd.toString().padLeft(2, '0')}:00",
              ].join(" • "),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                fontSize: 10,
                color: AppColors.textHint,
              ),
            ),
          ],
        ],
      ),
      type: Align(
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            p.type.label,
            style: AppText.caption.copyWith(
              fontSize: 11,
              color: typeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      value: Text(
        isPercentage ? "${p.value}%" : formatCurrency(p.value),
        textAlign: TextAlign.end,
        style: cellStyle.copyWith(fontWeight: FontWeight.w600),
      ),
      aksi: Center(
        child: PopupMenuButton<String>(
          tooltip: "Aksi",
          color: AppColors.card,
          icon: const Icon(
            Icons.more_vert_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            side: const BorderSide(color: AppColors.border),
          ),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit?.call();
                break;
              case 'delete':
                onDelete?.call();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: _menuItem(Icons.edit_outlined, "Edit"),
            ),
            PopupMenuItem(
              value: 'delete',
              child: _menuItem(
                Icons.delete_outline_rounded,
                "Hapus",
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _menuItem(IconData icon, String label, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppText.body.copyWith(color: color ?? AppColors.text),
        ),
      ],
    );
  }

  static Widget _headerText(
    String text, {
    bool alignEnd = false,
    bool alignCenter = false,
  }) {
    return Text(
      text,
      textAlign: alignCenter
          ? TextAlign.center
          : (alignEnd ? TextAlign.end : TextAlign.start),
      style: AppText.caption.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
        color: AppColors.textSecondary,
      ),
    );
  }

  static Widget _row({
    required Widget no,
    required Widget name,
    required Widget type,
    required Widget value,
    required Widget aksi,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 28, child: no),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: name),
        const SizedBox(width: 10),
        SizedBox(width: 100, child: type),
        const SizedBox(width: 10),
        SizedBox(width: 110, child: value),
        const SizedBox(width: 10),
        SizedBox(width: 48, child: aksi),
      ],
    );
  }
}

class _PromoCafeRow extends StatelessWidget {
  final bool header;
  final int? no;
  final PromoCafe? promo;
  final Map<int, String> productNames;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _PromoCafeRow.header()
    : header = true,
      no = null,
      promo = null,
      productNames = const {},
      onEdit = null,
      onDelete = null;

  const _PromoCafeRow.data({
    required this.no,
    required this.promo,
    required this.productNames,
    required this.onEdit,
    required this.onDelete,
  }) : header = false;

  @override
  Widget build(BuildContext context) {
    if (header) {
      return _row(
        no: _headerText("NO"),
        name: _headerText("NAMA PROMO"),
        type: _headerText("TIPE", alignCenter: true),
        value: _headerText("HARGA/DISKON", alignEnd: true),
        products: _headerText("PRODUK"),
        aksi: _headerText("AKSI", alignCenter: true),
      );
    }

    final p = promo!;
    final cellStyle = AppText.caption.copyWith(fontSize: 13);
    final isPercentage = p.type == PromoType.percentage;
    final typeColor = isPercentage ? AppColors.purple : AppColors.info;
    final names = p.productIds
        .map((id) => productNames[id])
        .whereType<String>()
        .toList();

    return _row(
      no: Text("$no", style: cellStyle.copyWith(color: AppColors.textHint)),
      name: Text(
        p.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: cellStyle.copyWith(fontWeight: FontWeight.w600),
      ),
      type: Align(
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            isPercentage ? "Diskon %" : "Harga Tetap",
            style: AppText.caption.copyWith(
              fontSize: 11,
              color: typeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      value: Text(
        isPercentage ? "${p.value}%" : formatCurrency(p.value),
        textAlign: TextAlign.end,
        style: cellStyle.copyWith(fontWeight: FontWeight.w600),
      ),
      products: Tooltip(
        message: names.isEmpty
            ? "${p.productIds.length} produk"
            : names.join(", "),
        child: Text(
          names.isEmpty
              ? "${p.productIds.length} produk"
              : names.join(", "),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: cellStyle,
        ),
      ),
      aksi: Center(
        child: PopupMenuButton<String>(
          tooltip: "Aksi",
          color: AppColors.card,
          icon: const Icon(
            Icons.more_vert_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            side: const BorderSide(color: AppColors.border),
          ),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit?.call();
                break;
              case 'delete':
                onDelete?.call();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: _menuItem(Icons.edit_outlined, "Edit"),
            ),
            PopupMenuItem(
              value: 'delete',
              child: _menuItem(
                Icons.delete_outline_rounded,
                "Hapus",
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _menuItem(IconData icon, String label, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppText.body.copyWith(color: color ?? AppColors.text),
        ),
      ],
    );
  }

  static Widget _headerText(
    String text, {
    bool alignEnd = false,
    bool alignCenter = false,
  }) {
    return Text(
      text,
      textAlign: alignCenter
          ? TextAlign.center
          : (alignEnd ? TextAlign.end : TextAlign.start),
      style: AppText.caption.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
        color: AppColors.textSecondary,
      ),
    );
  }

  static Widget _row({
    required Widget no,
    required Widget name,
    required Widget type,
    required Widget value,
    required Widget products,
    required Widget aksi,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 28, child: no),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: name),
        const SizedBox(width: 10),
        SizedBox(width: 100, child: type),
        const SizedBox(width: 10),
        SizedBox(width: 110, child: value),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: products),
        const SizedBox(width: 10),
        SizedBox(width: 48, child: aksi),
      ],
    );
  }
}
