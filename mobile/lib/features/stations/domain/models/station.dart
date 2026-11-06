import '../../../../core/config/app_config.dart';

/// PulseCast Radio Station Model
class Station {
  final int id;
  final String name;
  final String? description;
  final String? genre;
  final String streamUrl;
  final String? artworkUrl;
  final bool isActive;
  final bool isFavourite;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Station({
    required this.id,
    required this.name,
    this.description,
    this.genre,
    required this.streamUrl,
    this.artworkUrl,
    this.isActive = true,
    this.isFavourite = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Identifies whether the station is a local developer loopback fallback
  bool get isLocalFallback => streamUrl.contains('localhost');

  /// Identifies whether this is the primary AWS EC2 Icecast Station (Station 7)
  bool get isPrimaryAwsStream => id == 7 || streamUrl.contains('pulsecast.duckdns.org/pulsecast');

  /// Effective public stream URL for audio playback.
  /// Replaces the local dev loopback URL for Station #6 with the production public stream URL.
  String get effectiveStreamUrl {
    if (id == 6 && (streamUrl.isEmpty || streamUrl.contains('localhost'))) {
      return AppConfig.channel6StreamUrl;
    }
    return streamUrl;
  }

  factory Station.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] is int
        ? json['id'] as int
        : int.tryParse(json['id']?.toString() ?? '0') ?? 0;
    final rawUrl = json['stream_url'] as String? ?? '';

    return Station(
      id: rawId,
      name: json['name'] as String? ?? 'PulseCast Station',
      description: json['description'] as String?,
      genre: json['genre'] as String?,
      streamUrl: rawUrl,
      artworkUrl: json['artwork_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isFavourite: json['is_favourite'] as bool? ?? false,
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
      'name': name,
      'description': description,
      'genre': genre,
      'stream_url': streamUrl,
      'artwork_url': artworkUrl,
      'is_active': isActive,
      'is_favourite': isFavourite,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Station copyWith({
    int? id,
    String? name,
    String? description,
    String? genre,
    String? streamUrl,
    String? artworkUrl,
    bool? isActive,
    bool? isFavourite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Station(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      genre: genre ?? this.genre,
      streamUrl: streamUrl ?? this.streamUrl,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      isActive: isActive ?? this.isActive,
      isFavourite: isFavourite ?? this.isFavourite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Station && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

