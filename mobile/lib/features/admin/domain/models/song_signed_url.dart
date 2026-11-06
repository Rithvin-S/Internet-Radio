class SongSignedUrl {
  final String songId;
  final String title;
  final String artist;
  final String signedUrl;
  final int expiresIn; // Seconds
  final DateTime createdAt;

  SongSignedUrl({
    required this.songId,
    required this.title,
    required this.artist,
    required this.signedUrl,
    required this.expiresIn,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Check whether the signed URL has expired (with 10-second safety cushion)
  bool get isExpired {
    final expiryTime = createdAt.add(Duration(seconds: expiresIn - 10));
    return DateTime.now().isAfter(expiryTime);
  }

  factory SongSignedUrl.fromJson(Map<String, dynamic> json) {
    return SongSignedUrl(
      songId: json['songId']?.toString() ?? '',
      title: json['title'] as String? ?? 'Untitled',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      signedUrl: json['signedUrl'] as String? ?? '',
      expiresIn: json['expiresIn'] is int
          ? json['expiresIn'] as int
          : (int.tryParse(json['expiresIn']?.toString() ?? '') ?? 300),
      createdAt: DateTime.now(),
    );
  }
}
