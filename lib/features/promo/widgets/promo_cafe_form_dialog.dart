import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/thousands_input_formatter.dart';
import '../../../models/product.dart';
import '../../../models/promo.dart';
import '../../../models/promo_cafe.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../product/data/product_repository.dart';
import '../data/promo_cafe_repository.dart';

class PromoCafeFormResult {
  final String name;
  final PromoType type;
  final int value;
  final List<int> productIds;

  const PromoCafeFormResult({
    required this.name,
    required this.type,
    required this.value,
    required this.productIds,
  });
}

class PromoCafeFormDialog extends StatefulWidget {
  final PromoCafe? promo;

  const PromoCafeFormDialog({super.key, this.promo});

  @override
  State<PromoCafeFormDialog> createState() => _PromoCafeFormDialogState();
}

class _PromoCafeFormDialogState extends State<PromoCafeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _productRepository = ProductRepository();
  final _promoCafeRepository = PromoCafeRepository();
  final _productSearchController = TextEditingController();

  late final _nameController = TextEditingController(
    text: widget.promo?.name ?? "",
  );
  late final _valueController = TextEditingController(
    text: widget.promo != null ? formatThousands(widget.promo!.value) : "",
  );
  late PromoType _type = widget.promo?.type ?? PromoType.fixed;
  late final Set<int> _selectedProductIds = {...?widget.promo?.productIds};

  List<Product> _products = [];
  /// product_id -> the OTHER active promo it's already claimed by (used to
  /// lock those out of selection here — a product may only belong to one
  /// active cafe promo at a time, see PromoCafeRepository/backend). Fetched
  /// independently of [Product] since product listing no longer carries
  /// promo info itself (that's now resolved explicitly at POS checkout).
  Map<int, PromoCafe> _promoByProductId = {};
  bool _loadingProducts = true;
  String? _loadError;
  String _productSearch = "";

  bool get _isEdit => widget.promo != null;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _loadError = null;
    });
    try {
      final products = await _productRepository.getProducts();
      // Best-effort: kalau daftar promo cafe gagal dimuat, form tetap bisa dipakai (cuma tanpa
      // penguncian produk yang sudah dipakai promo lain) - itu bukan alasan untuk memblokir form.
      Map<int, PromoCafe> promoByProductId = {};
      try {
        final promoCafes = await _promoCafeRepository.getAllPromoCafes();
        for (final promo in promoCafes) {
          for (final productId in promo.productIds) {
            promoByProductId[productId] = promo;
          }
        }
      } on PromoCafeRepositoryException {
        // dibiarkan kosong, lihat komentar di atas
      }

      if (!mounted) return;
      setState(() {
        _products = products;
        _promoByProductId = promoByProductId;
        _loadingProducts = false;
      });
    } on ProductRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loadingProducts = false;
      });
    }
  }

  List<Product> get _filteredProducts {
    final query = _productSearch.trim().toLowerCase();
    if (query.isEmpty) return _products;
    return _products
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();
  }

  /// A product already tied to a DIFFERENT active promo can't be picked here
  /// too — the backend rejects it (one product = at most one active cafe
  /// promo, so it's unambiguous which promo a cashier is choosing between).
  bool _isLockedByOtherPromo(Product product) {
    final owningPromo = _promoByProductId[product.id];
    return owningPromo != null &&
        owningPromo.id != widget.promo?.id &&
        !_selectedProductIds.contains(product.id);
  }

  void _toggleProduct(Product product) {
    setState(() {
      if (_selectedProductIds.contains(product.id)) {
        _selectedProductIds.remove(product.id);
      } else {
        _selectedProductIds.add(product.id);
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProductIds.isEmpty) {
      AppToast.error(context, "Pilih minimal 1 produk untuk promo ini");
      return;
    }

    Navigator.of(context).pop(
      PromoCafeFormResult(
        name: _nameController.text.trim(),
        type: _type,
        value: parseThousands(_valueController.text) ?? 0,
        productIds: _selectedProductIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          border: Border.all(color: AppColors.border),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 22),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _label("Nama Promo"),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        style: AppText.body,
                        decoration: _inputDecoration(
                          hint: "Masukkan nama promo",
                          prefixIcon: Icons.local_cafe_outlined,
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? "Nama promo wajib diisi"
                            : null,
                      ),

                      const SizedBox(height: 20),
                      _label("Tipe Promo"),
                      const SizedBox(height: 8),
                      _buildTypeSelector(),

                      const SizedBox(height: 20),
                      _label(
                        _type == PromoType.percentage
                            ? "Diskon (%)"
                            : "Harga Jadi (Rp)",
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _valueController,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [ThousandsInputFormatter()],
                        style: AppText.body,
                        decoration: _inputDecoration(
                          hint: "0",
                          prefixIcon: Icons.payments_outlined,
                          suffixText: _type == PromoType.percentage
                              ? "%"
                              : null,
                        ),
                        validator: (value) {
                          final parsed = parseThousands(value ?? "");
                          if (parsed == null || parsed < 0) {
                            return "Masukkan angka yang valid";
                          }
                          if (_type == PromoType.percentage && parsed > 100) {
                            return "Diskon persen maksimal 100";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _type == PromoType.percentage
                            ? "Harga produk terpilih otomatis dipotong sekian persen dari harga normalnya."
                            : "Harga produk terpilih diganti langsung jadi nominal ini, apa pun harga normalnya.",
                        style: AppText.caption,
                      ),

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _label("Pilih Produk"),
                          const SizedBox(width: 8),
                          if (_selectedProductIds.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: .15,
                                ),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                "${_selectedProductIds.length} dipilih",
                                style: AppText.caption.copyWith(
                                  fontSize: 10,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildProductPicker(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMedium,
                          ),
                        ),
                      ),
                      child: const Text("BATAL"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _submit,
                      icon: Icon(
                        _isEdit
                            ? Icons.save_outlined
                            : Icons.local_cafe_outlined,
                        size: 20,
                      ),
                      label: Text(_isEdit ? "SIMPAN" : "TAMBAH PROMO"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        elevation: 0,
                        textStyle: AppText.button,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductPicker() {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _productSearchController,
                onChanged: (value) =>
                    setState(() => _productSearch = value),
                style: AppText.bodySecondary,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: "Cari produk...",
                  prefixIcon: Icon(Icons.search, size: 18),
                  prefixIconConstraints: BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(child: _buildProductList()),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    if (_loadingProducts) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
        ),
      );
    }

    final products = _filteredProducts;
    if (products.isEmpty) {
      return Center(
        child: Text("Tidak ada produk ditemukan", style: AppText.caption),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final selected = _selectedProductIds.contains(product.id);
        final locked = _isLockedByOtherPromo(product);

        return CheckboxListTile(
          dense: true,
          enabled: !locked,
          value: selected,
          onChanged: locked ? null : (_) => _toggleProduct(product),
          activeColor: AppColors.primary,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodySecondary.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            locked
                ? "Sudah dipakai promo \"${_promoByProductId[product.id]?.name}\""
                : formatCurrency(product.price),
            style: AppText.caption.copyWith(
              fontSize: 11,
              color: locked ? AppColors.danger : AppColors.textHint,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(child: _typeOption(PromoType.fixed)),
        const SizedBox(width: 10),
        Expanded(child: _typeOption(PromoType.percentage)),
      ],
    );
  }

  Widget _typeOption(PromoType type) {
    final active = _type == type;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: .15)
              : AppColors.background,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          type == PromoType.fixed ? "Harga Tetap" : type.label,
          style: AppText.body.copyWith(
            fontWeight: FontWeight.w600,
            color: active ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          child: const Icon(
            Icons.local_cafe_outlined,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? "Edit Promo Cafe" : "Tambah Promo Cafe",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                _isEdit
                    ? "Perbarui produk & harga promo"
                    : "Pilih produk dan tentukan harga promonya",
                style: AppText.caption,
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppText.bodySecondary.copyWith(fontWeight: FontWeight.w600),
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    IconData? prefixIcon,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.caption,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: AppColors.textSecondary)
          : null,
      suffixText: suffixText,
      suffixStyle: AppText.body.copyWith(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.background,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    );
  }
}
