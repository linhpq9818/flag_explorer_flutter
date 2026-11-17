import 'package:flutter/material.dart';

/// Geographical coordinate representation (latitude and longitude).
class LatLng {
  const LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  factory LatLng.fromMap(Map<dynamic, dynamic> map) {
    return LatLng(
      (map['latitude'] as num).toDouble(),
      (map['longitude'] as num).toDouble(),
    );
  }

  @override
  String toString() => 'LatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Camera altitude and target center coordinate.
class CameraPosition {
  const CameraPosition({
    required this.center,
    required this.altitude,
  });

  final LatLng center;
  final double altitude;

  factory CameraPosition.fromMap(Map<dynamic, dynamic> map) {
    return CameraPosition(
      center: LatLng(
        (map['latitude'] as num).toDouble(),
        (map['longitude'] as num).toDouble(),
      ),
      altitude: (map['altitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'latitude': center.latitude,
        'longitude': center.longitude,
        'altitude': altitude,
      };

  @override
  String toString() =>
      'CameraPosition(center: $center, altitude: ${altitude.toStringAsFixed(0)}m)';
}

/// Parsed country data detected under the globe center crosshair.
class CountryData {
  const CountryData({
    required this.id,
    required this.name,
    required this.isoA3,
    this.isoA2,
    required this.flagEmoji,
    this.flagUrl,
    required this.center,
  });

  /// ISO 3-letter alpha code (e.g., "USA", "VNM").
  final String id;

  /// Display name of the country.
  final String name;

  /// ISO 3166-1 alpha-3 code.
  final String isoA3;

  /// ISO 3166-1 alpha-2 code (e.g., "US", "VN").
  final String? isoA2;

  /// Regional flag emoji (e.g. 🇺🇸, 🇻🇳).
  final String flagEmoji;

  /// Flagcdn thumbnail image URL (e.g., "https://flagcdn.com/w320/us.png").
  final String? flagUrl;

  /// Center coordinate of country bounding box.
  final LatLng center;

  factory CountryData.fromMap(Map<dynamic, dynamic> map) {
    return CountryData(
      id: map['id'] as String? ?? map['isoA3'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown',
      isoA3: map['isoA3'] as String? ?? '',
      isoA2: map['isoA2'] as String?,
      flagEmoji: map['flagEmoji'] as String? ?? '🏳️',
      flagUrl: map['flagUrl'] as String?,
      center: LatLng(
        (map['centerLat'] as num?)?.toDouble() ?? 0.0,
        (map['centerLng'] as num?)?.toDouble() ?? 0.0,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'isoA3': isoA3,
        'isoA2': isoA2,
        'flagEmoji': flagEmoji,
        'flagUrl': flagUrl,
        'centerLat': center.latitude,
        'centerLng': center.longitude,
      };

  @override
  String toString() => 'CountryData($name, isoA3: $isoA3, flag: $flagEmoji)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountryData &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Representation of a preset country item for the horizontal controls list.
class GlobePresetItem {
  const GlobePresetItem({
    required this.name,
    required this.emoji,
    required this.isoA3,
    this.latitude,
    this.longitude,
    this.altitude,
  });

  /// Display name on the preset chip (e.g. "Vietnam").
  final String name;

  /// Emoji flag displayed in the avatar (e.g. "🇻🇳").
  final String emoji;

  /// ISO 3-letter country code (e.g. "VNM", "USA").
  final String isoA3;

  /// Optional specific camera center latitude.
  final double? latitude;

  /// Optional specific camera center longitude.
  final double? longitude;

  /// Optional camera altitude in meters when focused.
  final double? altitude;

  Map<String, dynamic> toMap() => {
        'name': name,
        'emoji': emoji,
        'isoA3': isoA3,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (altitude != null) 'altitude': altitude,
      };
}

/// Styling configuration for glowing country border lines and polygon fill.
class GlobeOverlayStyle {
  const GlobeOverlayStyle({
    Color? strokeColor,
    Color? fillColor,
    Color? glowColor,
    this.fillAlpha = 0.18,
    this.isNeon = true,
  })  : strokeColor = strokeColor ?? glowColor ?? const Color(0xFFFF3B30),
        fillColor = fillColor ?? glowColor ?? const Color(0xFFFF3B30);

  /// Color of the country boundary glow stroke lines.
  final Color strokeColor;

  /// Color of the interior country polygon fill.
  final Color fillColor;

  /// Opacity of the interior country polygon fill (0.0 to 1.0).
  final double fillAlpha;

  /// Whether to render borders as multi-pass glowing Neon tubes with incandescent white filament cores.
  final bool isNeon;

  Map<String, dynamic> toMap() {
    final strokeHex =
        '#${(strokeColor.toARGB32() & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';
    final fillHex =
        '#${(fillColor.toARGB32() & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';
    return {
      'strokeColor': strokeHex,
      'fillColor': fillHex,
      'fillAlpha': fillAlpha,
      'glowColor': strokeHex,
      'isNeon': isNeon,
    };
  }
}
