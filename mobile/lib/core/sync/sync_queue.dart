enum SyncActionType {
  addFavoriteStation,
  removeFavoriteStation,
}

enum SyncStatus {
  idle,
  syncing,
  synced,
  error,
  offline,
}

/// Represents a deferred mutation queued while offline
class SyncAction {
  final String id;
  final SyncActionType type;
  final int stationId;
  final DateTime createdAt;
  final int retryCount;

  const SyncAction({
    required this.id,
    required this.type,
    required this.stationId,
    required this.createdAt,
    this.retryCount = 0,
  });

  SyncAction copyWith({
    int? retryCount,
  }) {
    return SyncAction(
      id: id,
      type: type,
      stationId: stationId,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'station_id': stationId,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
    };
  }

  factory SyncAction.fromJson(Map<String, dynamic> json) {
    return SyncAction(
      id: json['id'] as String,
      type: SyncActionType.values.byName(json['type'] as String),
      stationId: json['station_id'] as int,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      retryCount: json['retry_count'] as int? ?? 0,
    );
  }
}

