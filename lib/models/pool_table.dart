enum TableStatus { playing, ready, unpaid }

enum SessionType { timer, reguler }

class PoolTable {
  final String id;
  final String name;
  final TableStatus status;
  final int? categoryMejaId;
  final String? badge;
  final String? startTime;
  final String? timerText;
  final String? endTime;
  final SessionType? sessionType;
  final int? promoId;
  final String? promoName;
  final DateTime? startAt;
  final DateTime? endAt;
  final Duration? plannedDuration;
  final int? currentBill;

  const PoolTable({
    required this.id,
    required this.name,
    required this.status,
    this.categoryMejaId,
    this.badge,
    this.startTime,
    this.timerText,
    this.endTime,
    this.sessionType,
    this.promoId,
    this.promoName,
    this.startAt,
    this.endAt,
    this.plannedDuration,
    this.currentBill,
  });

  PoolTable copyWith({
    TableStatus? status,
    String? badge,
    String? startTime,
    String? timerText,
    String? endTime,
    SessionType? sessionType,
    int? promoId,
    String? promoName,
    DateTime? startAt,
    DateTime? endAt,
    Duration? plannedDuration,
    int? currentBill,
  }) {
    return PoolTable(
      id: id,
      name: name,
      status: status ?? this.status,
      categoryMejaId: categoryMejaId,
      badge: badge ?? this.badge,
      startTime: startTime ?? this.startTime,
      timerText: timerText ?? this.timerText,
      endTime: endTime ?? this.endTime,
      sessionType: sessionType ?? this.sessionType,
      promoId: promoId ?? this.promoId,
      promoName: promoName ?? this.promoName,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      plannedDuration: plannedDuration ?? this.plannedDuration,
      currentBill: currentBill ?? this.currentBill,
    );
  }
}
