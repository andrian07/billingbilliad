class BusinessInfo {
  BusinessInfo._();

  static const name = "Doublin Billiard";
  static const address = "Ngabang";
  static const outletCode = "1";

  /// Nama kategori meja untuk tiap kolom harga (Harga 1/2/3) di Pengaturan
  /// Harga - harus sesuai category_meja.category_meja_price di database.
  static const priceTierLabels = ["VIP", "Reguler", "PS"];
}
