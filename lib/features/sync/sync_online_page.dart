import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formatters.dart';
import '../../models/sync_queue_item.dart';
import '../../services/session_storage.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_layout.dart';
import '../../shared/widgets/app_toast.dart';
import 'data/sync_online_repository.dart';

enum _ItemProgress { pending, processing, success, failed }

/// Shows rows in the backend's failed-sync queue (see Admin_sync.php /
/// Online_report.php) — transactions/master rows that couldn't be pushed to
/// the external "onlinereport" system — and lets the owner retry all of them
/// with live per-item progress. Owner-only, same pattern as OpnamePage: the
/// menu item is only visible to the built-in owner account (see
/// app_sidebar.dart), and this page double-checks via
/// [SessionStorage.isSuperadmin] so a direct URL visit doesn't get in.
class SyncOnlinePage extends StatefulWidget {
  const SyncOnlinePage({super.key});

  @override
  State<SyncOnlinePage> createState() => _SyncOnlinePageState();
}

class _SyncOnlinePageState extends State<SyncOnlinePage> {
  final _repository = SyncOnlineRepository();
  final _sessionStorage = SessionStorage();

  bool? _isOwner;
  List<SyncQueueItem> _items = [];
  bool _loading = true;
  String? _error;

  bool _retrying = false;
  final Map<int, _ItemProgress> _progress = {};
  int _successCount = 0;
  int _failCount = 0;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final isOwner = await _sessionStorage.isSuperadmin();
    if (!mounted) return;
    setState(() => _isOwner = isOwner);
    if (isOwner) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _repository.getFailedQueue();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on SyncOnlineRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _retryAll() async {
    if (_items.isEmpty || _retrying) return;

    setState(() {
      _retrying = true;
      _successCount = 0;
      _failCount = 0;
      _progress
        ..clear()
        ..addEntries(_items.map((e) => MapEntry(e.id, _ItemProgress.pending)));
    });

    // Sequential on purpose (not Future.wait): each item is its own HTTP
    // round-trip to onlinereport, and doing them one at a time is what lets
    // the UI show real live progress instead of everything flipping at once.
    for (final item in _items) {
      if (!mounted) return;
      setState(() => _progress[item.id] = _ItemProgress.processing);

      try {
        final result = await _repository.retryQueueItem(item.id);
        if (!mounted) return;
        setState(() {
          _progress[item.id] = result.success
              ? _ItemProgress.success
              : _ItemProgress.failed;
          if (result.success) {
            _successCount++;
          } else {
            _failCount++;
          }
        });
      } on SyncOnlineRepositoryException {
        if (!mounted) return;
        setState(() {
          _progress[item.id] = _ItemProgress.failed;
          _failCount++;
        });
      }
    }

    if (!mounted) return;
    setState(() => _retrying = false);

    if (_failCount == 0) {
      AppToast.success(
        context,
        "Semua item berhasil disinkronkan ($_successCount item)",
      );
    } else {
      AppToast.error(
        context,
        "$_successCount berhasil, $_failCount masih gagal",
      );
    }

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "Sync Online",
      subtitle: "Antrian sinkronisasi ke laporan online yang gagal",
      showSearch: false,
      activeMenuKey: "sync_online",
      onMenuSelect: (key) => navigateToMenu(context, key),
      onRefresh: _isOwner == true && !_retrying ? _load : null,
      child: _isOwner == null
          ? const Center(child: CircularProgressIndicator())
          : (_isOwner == false ? _buildAccessDenied() : _buildCard()),
    );
  }

  Widget _buildAccessDenied() {
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
              Icons.lock_outline_rounded,
              size: 30,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "Hanya akun owner yang dapat mengakses halaman ini",
            style: AppText.bodySecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: _buildToolbar(),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
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
            Icons.sync_problem_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Antrian Gagal Sinkron",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(_toolbarSubtitle(), style: AppText.caption),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: (_items.isEmpty || _retrying || _loading)
              ? null
              : _retryAll,
          icon: _retrying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sync_rounded, size: 18),
          label: Text(
            _retrying
                ? "MEMPROSES ${_processedCount()}/${_items.length}..."
                : "UPDATE SEMUA YANG GAGAL",
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            textStyle: AppText.button.copyWith(fontSize: 13),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            ),
          ),
        ),
      ],
    );
  }

  int _processedCount() =>
      _progress.values.where((s) => s != _ItemProgress.pending).length;

  String _toolbarSubtitle() {
    if (_loading) return "Memuat data...";
    if (_retrying) {
      return "$_successCount berhasil, $_failCount gagal dari ${_processedCount()} diproses";
    }
    return _items.isEmpty
        ? "Semua data sudah tersinkron ke laporan online"
        : "${_items.length} item menunggu untuk disinkronkan ulang";
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorState(_error!);
    }
    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _QueueItemRow(
        item: _items[index],
        progress: _progress[_items[index].id],
      ),
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
              color: AppColors.success.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_done_outlined,
              size: 30,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "Tidak ada antrian gagal — semua data sudah tersinkron",
            style: AppText.bodySecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
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
            onPressed: _load,
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
}

class _QueueItemRow extends StatelessWidget {
  final SyncQueueItem item;
  final _ItemProgress? progress;

  const _QueueItemRow({required this.item, this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      "${item.tableName} · ${item.action.toUpperCase()}",
                      style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "ID ${item.recordId}",
                      style: AppText.caption.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
                if (item.lastError != null && item.lastError!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.lastError!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(color: AppColors.danger),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  "${item.attempts}x percobaan"
                  "${item.createdAt != null ? ' · sejak ${formatDate(item.createdAt!)} ${formatClock(item.createdAt!)}' : ''}",
                  style: AppText.caption.copyWith(color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusIcon() {
    switch (progress) {
      case _ItemProgress.processing:
        return const Padding(
          padding: EdgeInsets.all(2),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case _ItemProgress.success:
        return const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 22,
        );
      case _ItemProgress.failed:
        return const Icon(
          Icons.error_rounded,
          color: AppColors.danger,
          size: 22,
        );
      case _ItemProgress.pending:
      case null:
        return const Icon(
          Icons.hourglass_empty_rounded,
          color: AppColors.textHint,
          size: 22,
        );
    }
  }
}
