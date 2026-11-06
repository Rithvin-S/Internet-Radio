class AdminSongStats {
  final int totalSongs;
  final int activeSongs;
  final int totalStorageBytes;
  final int totalDurationSeconds;

  const AdminSongStats({
    this.totalSongs = 0,
    this.activeSongs = 0,
    this.totalStorageBytes = 0,
    this.totalDurationSeconds = 0,
  });

  String get formattedTotalStorage {
    if (totalStorageBytes <= 0) return '0 MB';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = totalStorageBytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String get formattedTotalDuration {
    if (totalDurationSeconds <= 0) return '0m';
    final hours = totalDurationSeconds ~/ 3600;
    final minutes = (totalDurationSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  factory AdminSongStats.fromJson(Map<String, dynamic> json) {
    return AdminSongStats(
      totalSongs: json['totalSongs'] is int
          ? json['totalSongs'] as int
          : (int.tryParse(json['totalSongs']?.toString() ?? '') ?? 0),
      activeSongs: json['activeSongs'] is int
          ? json['activeSongs'] as int
          : (int.tryParse(json['activeSongs']?.toString() ?? '') ?? 0),
      totalStorageBytes: json['totalStorageBytes'] is int
          ? json['totalStorageBytes'] as int
          : (int.tryParse(json['totalStorageBytes']?.toString() ?? '') ?? 0),
      totalDurationSeconds: json['totalDurationSeconds'] is int
          ? json['totalDurationSeconds'] as int
          : (int.tryParse(json['totalDurationSeconds']?.toString() ?? '') ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalSongs': totalSongs,
      'activeSongs': activeSongs,
      'totalStorageBytes': totalStorageBytes,
      'totalDurationSeconds': totalDurationSeconds,
    };
  }
}
