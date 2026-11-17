# flag_explorer

A reusable, high-performance Flutter iOS plugin embedding Apple MapKit's 3D realistic satellite globe with instant offline point-in-polygon country detection and pure-vector glowing border highlights.

## Features

- **Apple MapKit 3D Satellite Globe**: Embedded natively via Flutter iOS Platform Views (`UiKitView`) with realistic terrain elevation and pure satellite imagery.
- **Offline Point-in-Polygon Country Detection**: Ray-casting algorithm running in native Swift with zero network latency.
- **Pure-Vector Glowing Overlays**: Multi-pass CoreGraphics rendering with adaptive LOD (level of detail) and antimeridian seam suppression.
- **Bundled GeoJSON**: Bundled directly within the plugin's CocoaPods/SPM resource bundle (`countries.geojson`), requiring no host app configuration.
- **Bidirectional Flutter ↔ Native API**:
  - `FlagExplorerView` widget for easy embedding.
  - `FlagExplorerController` for programmatic camera movement, focusing countries by ISO code, resetting the camera, and querying current state.
  - Event streams for country change (`onCountryChanged`), throttled camera motion (`onCameraChanged`), and errors (`onError`).
- **iOS Exclusive**: Intentionally designed for iOS 16.0+; provides a graceful fallback widget on unsupported platforms.

---

## Installation

Add `flag_explorer` to your Flutter app's `pubspec.yaml` as a local path dependency:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flag_explorer:
    path: ../flag_explorer # or relative path to where the plugin is stored
```

In your host iOS project's `ios/Podfile`, ensure the platform deployment target is at least `16.0`:

```ruby
platform :ios, '16.0'
```

Then run:

```bash
flutter pub get
cd ios && pod install
```

---

## Usage Example

```dart
import 'package:flutter/material.dart';
import 'package:flag_explorer/flag_explorer.dart';

class GlobeScreen extends StatefulWidget {
  const GlobeScreen({super.key});

  @override
  State<GlobeScreen> createState() => _GlobeScreenState();
}

class _GlobeScreenState extends State<GlobeScreen> {
  FlagExplorerController? _controller;
  CountryData? _selectedCountry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Embedded 3D MapKit Globe
          FlagExplorerView(
            initialCoordinate: const LatLng(37.982941, -98.701740),
            initialDistance: 18000000.0,
            overlayStyle: const GlobeOverlayStyle(
              glowColor: Color(0xFFFF3B30),
              fillAlpha: 0.18,
            ),
            onGlobeReady: (controller) {
              _controller = controller;
            },
            onCountryChanged: (country) {
              setState(() {
                _selectedCountry = country;
              });
            },
            onCameraChanged: (camera) {
              // Throttled camera altitude and center coordinate updates
            },
            onError: (error) {
              debugPrint('Globe Error: $error');
            },
          ),

          // 2. Flutter Overlay UI
          if (_selectedCountry != null)
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: Card(
                color: Colors.black87,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        _selectedCountry!.flagEmoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCountry!.name,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _selectedCountry!.isoA3,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

---

## API Reference

### `FlagExplorerView`

| Property | Type | Default | Description |
|---|---|---|---|
| `initialCoordinate` | `LatLng` | `LatLng(37.982941, -98.701740)` | Starting globe center coordinate. |
| `initialDistance` | `double` | `18000000.0` (18,000 km) | Starting camera altitude in meters. |
| `overlayStyle` | `GlobeOverlayStyle` | Red stroke & fill, 0.18 fillAlpha | Customizable border glow stroke color, polygon fill color, and opacity. |
| `customPresets` | `List<GlobePresetItem>?` | Default 7 countries | Custom curated list of preset country chips in the horizontal carousel. |
| `enableHapticFeedback` | `bool` | `true` | Triggers native iOS Taptic Engine feedback (`UIImpactFeedbackGenerator.light`) on country transition. |
| `cardBottomPadding` | `double` | `28.0` | Bottom margin/padding for the country card, useful to avoid bottom navigation bars. |
| `crosshairColor` | `Color` | `Colors.white` | Color of the native center targeting crosshair. |
| `crosshairSize` | `double` | `56.0` | Size/diameter of the native center targeting crosshair in points. |
| `enableTapToFocus` | `bool` | `true` | Allows tapping directly on any country on the 3D globe to smoothly fly camera to it. |
| `showCenterCrosshair` | `bool` | `true` | Bật/tắt hiển thị tâm ngắm giữa màn hình. |
| `showCountryCard` | `bool` | `true` | Bật/tắt card thông tin quốc gia dạng Liquid Glass. |
| `showPresetControls` | `bool` | `true` | Bật/tắt thanh cuộn preset chips. |
| `onGlobeReady` | `ValueChanged<FlagExplorerController>?` | `null` | Called when native MapKit view is initialized. |
| `onCountryChanged` | `ValueChanged<CountryData?>?` | `null` | Emitted when crosshair enters or leaves a country. |
| `onCameraChanged` | `ValueChanged<CameraPosition>?` | `null` | Throttled camera altitude and coordinate stream. |
| `onError` | `ValueChanged<String>?` | `null` | Emitted if native GeoJSON loading encounters an issue. |

### `FlagExplorerController`

- `Future<void> setCamera({required double latitude, required double longitude, double? altitude, bool animated = true})`: Moves globe camera.
- `Future<bool> focusCountry(String isoA3, {double? altitude, bool animated = true})`: Finds country by 3-letter ISO code, animates camera to framing distance, and immediately highlights it. Returns `true` if found.
- `Future<void> resetCamera({bool animated = true})`: Resets globe to initial default overview framing.
- `Future<void> setOverlayStyle(GlobeOverlayStyle style)`: Updates glow color and fill transparency dynamically.
- `Future<CountryData?> getCurrentCountry()`: Queries currently highlighted country from native cache.
- `Future<CameraPosition?> getCameraPosition()`: Queries current center and altitude.
- `void dispose()`: Releases channel handlers and event streams.

### `CountryData`

- `id`: ISO 3-letter code (e.g. `"USA"`, `"VNM"`).
- `name`: Full country name (e.g. `"United States of America"`).
- `isoA3`: ISO 3166-1 alpha-3 code.
- `isoA2`: Optional ISO 3166-1 alpha-2 code (e.g. `"US"`, `"VN"`).
- `flagEmoji`: Unicode flag emoji (e.g. 🇺🇸, 🇻🇳).
- `flagUrl`: Flagcdn CDN image URL.
- `center`: `LatLng` bounding box center.

---

## Requirements

- iOS 16.0 or later (required by `MKImageryMapConfiguration(elevationStyle: .realistic)`).
- Flutter 3.3.0 or later.
