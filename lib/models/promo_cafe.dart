import 'promo.dart';

/// A cafe promo pins one or more [productIds] to a fixed price or percent
/// discount off their normal price — distinct from [Promo] (billing table
/// sessions), which discounts a whole bill rather than specific products.
/// Prices in the POS product grid/cart always stay normal; a promo only
/// takes effect once the cashier explicitly picks it in the "Pilih Promo"
/// dropdown at payment (see CafePaymentDialog), and even then it discounts
/// only the cart items whose product is in [productIds] — the backend
/// re-validates and recomputes the effective price server-side (see
/// Cafe_model::get_cafe_promo_price_map()).
class PromoCafe {
  final int id;
  final String name;
  final PromoType type;
  final int value;
  final List<int> productIds;

  const PromoCafe({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    required this.productIds,
  });

  factory PromoCafe.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawValue = json['value'];
    final rawProductIds = json['product_ids'];

    return PromoCafe(
      id: rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0,
      name: json['name']?.toString() ?? "",
      type: PromoType.fromApiValue(json['tipe']?.toString() ?? ""),
      value: rawValue is int
          ? rawValue
          : int.tryParse(rawValue.toString()) ?? 0,
      productIds: rawProductIds is List
          ? rawProductIds
              .map((id) => id is int ? id : int.tryParse(id.toString()))
              .whereType<int>()
              .toList()
          : const [],
    );
  }
}
