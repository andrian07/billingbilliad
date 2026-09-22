import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/sync_queue_item.dart';
import '../../../services/session_storage.dart';

class SyncOnlineRepositoryException implements Exception {
  final String message;

  const SyncOnlineRepositoryException(this.message);

  @override
  String toString() => message;
}

class SyncRetryResult {
  final int queueId;
  final bool success;
  final String? error;

  const SyncRetryResult({
    required this.queueId,
    required this.success,
    this.error,
  });
}

/// Reads and manually drains the backend's failed-sync queue (Admin_sync.php)
/// for the "Sync Online" page — owner-only, same as the backend endpoints
/// themselves (see Admin_sync::_require_owner()).
class SyncOnlineRepository {
  final Dio _dio = Dio();
  final _sessionStorage = SessionStorage();

  Future<int> _ownerUserId() async {
    final session = await _sessionStorage.getSession();
    return int.tryParse(session?['id']?.toString() ?? "") ?? 0;
  }

  Future<List<SyncQueueItem>> getFailedQueue() async {
    final userId = await _ownerUserId();
    final data = await _post(ApiEndpoints.syncQueueList, {"user_id": userId});

    final result = data['result'];
    if (result is! List) {
      throw const SyncOnlineRepositoryException(
        "Format respons antrian sinkron tidak valid.",
      );
    }

    return result
        .whereType<Map<String, dynamic>>()
        .map(SyncQueueItem.fromJson)
        .toList();
  }

  /// Retries exactly one queued item — called once per row by the "Update
  /// Semua yang Gagal" button so the UI can show live per-item progress
  /// instead of blocking on one long request for the whole batch.
  Future<SyncRetryResult> retryQueueItem(int queueId) async {
    final userId = await _ownerUserId();
    final data = await _post(ApiEndpoints.syncRetryQueueItem, {
      "user_id": userId,
      "queue_id": queueId,
    });

    final result = data['result'];
    if (result is! Map<String, dynamic>) {
      throw const SyncOnlineRepositoryException(
        "Format respons retry tidak valid.",
      );
    }

    return SyncRetryResult(
      queueId: queueId,
      success: result['success'] == true,
      error: result['error']?.toString(),
    );
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
          throw const SyncOnlineRepositoryException(
            "Format respons tidak valid.",
          );
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const SyncOnlineRepositoryException(
          "Format respons tidak valid.",
        );
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw SyncOnlineRepositoryException(
          data['result']?.toString() ??
              data['message']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on SyncOnlineRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['result'] != null) {
        throw SyncOnlineRepositoryException(responseData['result'].toString());
      }
      throw const SyncOnlineRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}
