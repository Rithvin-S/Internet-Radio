enum StationSort {
  defaultSort,
  nameAsc,
  nameDesc,
  genre,
}

/// Persistent user preferences for PulseCast application
class UserSettings {
  final int? defaultStationId;
  final bool autoplayOnLaunch;
  final StationSort stationSort;
  final String preferredLibraryFilter;
  final bool dataSaverMode;
  final String themeMode;

  const UserSettings({
    this.defaultStationId,
    this.autoplayOnLaunch = true,
    this.stationSort = StationSort.defaultSort,
    this.preferredLibraryFilter = 'all',
    this.dataSaverMode = false,
    this.themeMode = 'dark',
  });

  UserSettings copyWith({
    int? defaultStationId,
    bool? clearDefaultStation,
    bool? autoplayOnLaunch,
    StationSort? stationSort,
    String? preferredLibraryFilter,
    bool? dataSaverMode,
    String? themeMode,
  }) {
    return UserSettings(
      defaultStationId: clearDefaultStation == true
          ? null
          : (defaultStationId ?? this.defaultStationId),
      autoplayOnLaunch: autoplayOnLaunch ?? this.autoplayOnLaunch,
      stationSort: stationSort ?? this.stationSort,
      preferredLibraryFilter:
          preferredLibraryFilter ?? this.preferredLibraryFilter,
      dataSaverMode: dataSaverMode ?? this.dataSaverMode,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'default_station_id': defaultStationId,
      'autoplay_on_launch': autoplayOnLaunch,
      'station_sort': stationSort.name,
      'preferred_library_filter': preferredLibraryFilter,
      'data_saver_mode': dataSaverMode,
      'theme_mode': themeMode,
    };
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      defaultStationId: json['default_station_id'] as int?,
      autoplayOnLaunch: json['autoplay_on_launch'] as bool? ?? true,
      stationSort: StationSort.values.firstWhere(
        (e) => e.name == json['station_sort'],
        orElse: () => StationSort.defaultSort,
      ),
      preferredLibraryFilter:
          json['preferred_library_filter'] as String? ?? 'all',
      dataSaverMode: json['data_saver_mode'] as bool? ?? false,
      themeMode: json['theme_mode'] as String? ?? 'dark',
    );
  }
}

