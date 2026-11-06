class AdminSong {
  final String id; // UUID v4
  final String title;
  final String artist;
  final String? album;
  final String? duration;
  final int durationSeconds;
  final String? mimeType;
  final int fileSizeBytes;
  final String? fileHash;
  final String storageBucket;
  final String storagePath;
  final String? originalFilename;
  final int? createdBy;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminSong({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.duration,
    this.durationSeconds = 0,
    this.mimeType,
    this.fileSizeBytes = 0,
    this.fileHash,
    required this.storageBucket,
    required this.storagePath,
    this.originalFilename,
    this.createdBy,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  String get formattedFileSize {
    if (fileSizeBytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = fileSizeBytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String get formattedDuration {
    if (duration != null && duration!.isNotEmpty) return duration!;
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  factory AdminSong.fromJson(Map<String, dynamic> json) {
    return AdminSong(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Untitled',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String?,
      duration: json['duration'] as String?,
      durationSeconds: json['duration_seconds'] is int
          ? json['duration_seconds'] as int
          : (int.tryParse(json['duration_seconds']?.toString() ?? '') ?? 0),
      mimeType: json['mime_type'] as String?,
      fileSizeBytes: json['file_size_bytes'] is int
          ? json['file_size_bytes'] as int
          : (int.tryParse(json['file_size_bytes']?.toString() ?? '') ?? 0),
      fileHash: json['file_hash'] as String?,
      storageBucket: json['storage_bucket'] as String? ?? 'pulsecast-music-library',
      storagePath: json['storage_path'] as String? ?? '',
      originalFilename: json['original_filename'] as String?,
      createdBy: json['created_by'] is int
          ? json['created_by'] as int
          : int.tryParse(json['created_by']?.toString() ?? ''),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'duration_seconds': durationSeconds,
      'mime_type': mimeType,
      'file_size_bytes': fileSizeBytes,
      'file_hash': fileHash,
      'storage_bucket': storageBucket,
      'storage_path': storagePath,
      'original_filename': originalFilename,
      'created_by': createdBy,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  AdminSong copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? duration,
    int? durationSeconds,
    String? mimeType,
    int? fileSizeBytes,
    String? fileHash,
    String? storageBucket,
    String? storagePath,
    String? originalFilename,
    int? createdBy,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminSong(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      mimeType: mimeType ?? this.mimeType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      fileHash: fileHash ?? this.fileHash,
      storageBucket: storageBucket ?? this.storageBucket,
      storagePath: storagePath ?? this.storagePath,
      originalFilename: originalFilename ?? this.originalFilename,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
