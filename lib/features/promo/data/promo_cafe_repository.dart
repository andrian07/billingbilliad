import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/pagination_info.dart';
import '../../../models/promo.dart';
import '../../../models/promo_cafe.dart';

class PromoCafeRepositoryException implements Exception {
  final String message;

  const PromoCafeRepositoryException(this.message);

  @override
  String toString() => message;
}

class PromoCafeListResult {
  final List<PromoCafe> promos;
  final PaginationInfo pagination;

  const PromoCafeListResult({required this.promos, required this.pagination});
}

/// Reads and manages cafe promo entries (product-tied price overrides) via
/// the Master/*_promo_cafe endpoints — distinct from [PromoRepository],
/// which handles whole-bill billing promos.
class PromoCafeRepository {
  final Dio _dio = Dio();

  Future<PromoCafeListResult> getPromoCafes({
    required int page,
    required int perPage,
  }) async {
    final data = await _post(ApiEndpoints.promoCafeList, {
      "page": "$page",
      "per_page": "$perPage",
    });

    final list = data['data'];
    if (list is! List) {
      throw const PromoCafeRepositoryException(
        "Format respons daftar promo cafe tidak valid.",
      );
    }

    final promos = list
        .whereType<Map<String, dynamic>>()
        .map(PromoCafe.fromJson)
        .toList();

    final paginationJson = data['pagination'];
    final pagination = paginationJson is Map<String, dynamic>
        ? PaginationInfo.fromJson(paginationJson)
        : PaginationInfo.empty;

    return PromoCafeListResult(promos: promos, pagination: pagination);
  }

  /// Reads the full, unpaginated cafe promo list — used where every promo
  /// needs to be available at once (e.g. the POS payment dialog's "Pilih
  /// Promo" dropdown), mirroring [PromoRepository.getAllPromos].
  Future<List<PromoCafe>> getAllPromoCafes() async {
    final data = await _get(ApiEndpoints.promoCafeListNoPaging);

    if (data is! List) {
      throw const PromoCafeRepositoryException(
        "Format respons daftar promo cafe tidak valid.",
      );
    }

    return data.whereType<Map<String, dynamic>>().map(PromoCafe.fromJson).toList();
  }

  Future<void> addPromoCafe({
    required String name,
    required PromoType type,
    required int value,
    required List<int> productIds,
  }) {
    return _post(ApiEndpoints.addPromoCafe, {
      "ms_promo_cafe_name": name,
      "ms_promo_cafe_tipe": type.apiValue,
      "ms_promo_cafe_value": "$value",
      "product_ids": productIds.join(","),
    });
  }

  Future<void> editPromoCafe({
    required int id,
    required String name,
    required PromoType type,
    required int value,
    required List<int> productIds,
  }) {
    return _post(ApiEndpoints.editPromoCafe, {
      "ms_promo_cafe_id": "$id",
      "ms_promo_cafe_name": name,
      "ms_promo_cafe_tipe": type.apiValue,
      "ms_promo_cafe_value": "$value",
      "product_ids": productIds.join(","),
    });
  }

  Future<void> deletePromoCafe(int id) {
    return _post(ApiEndpoints.deletePromoCafe, {"ms_promo_cafe_id": "$id"});
  }

  Future<dynamic> _get(String url) async {
    try {
      final response = await _dio.get(url);

      var data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          throw const PromoCafeRepositoryException(
            "Format respons tidak valid.",
          );
        }
      }

      return data;
    } on PromoCafeRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw PromoCafeRepositoryException(
          responseData['message'].toString(),
        );
      }
      throw const PromoCafeRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }

  Future<Map<String, dynamic>> _post(
    String url,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post(url, data: payload);

      var data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          throw const PromoCafeRepositoryException(
            "Format respons tidak valid.",
          );
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const PromoCafeRepositoryException(
          "Format respons tidak valid.",
        );
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw PromoCafeRepositoryException(
          data['message']?.toString() ??
              data['result']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on PromoCafeRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw PromoCafeRepositoryException(
          responseData['message'].toString(),
        );
      }
      throw const PromoCafeRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}
