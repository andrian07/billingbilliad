/// One item stuck in the backend's `online_report_sync_queue` — a table row
/// that failed to push to the external "onlinereport" system and is waiting
/// to be retried (see Online_report.php/Admin_sync.php on the backend).
class SyncQueueItem {
  final int id;
  final String tableName;
  final String action;
  final String recordId;
  final int attempts;
  final String? lastError;
  final DateTime? createdAt;

  const SyncQueueItem({
    required this.id,
    required this.tableName,
    required this.action,
    required this.recordId,
    required this.attempts,
    this.lastError,
    this.createdAt,
  });

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawAttempts = json['attempts'];

    return SyncQueueItem(
      id: rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0,
      tableName: json['table_name']?.toString() ?? "",
      action: json['action']?.toString() ?? "",
      recordId: json['record_id']?.toString() ?? "",
      attempts: rawAttempts is int
          ? rawAttempts
          : int.tryParse(rawAttempts.toString()) ?? 0,
      lastError: json['last_error']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ""),
    );
  }
}
