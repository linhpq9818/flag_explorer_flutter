import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'models.dart';

/// Controller providing programmatic control and event listeners for a [FlagExplorerView].
class FlagExplorerController {
  FlagExplorerController._(this.viewId)
      : _channel = MethodChannel('flag_explorer_view_$viewId') {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  /// Platform view unique identifier.
  final int viewId;
  final MethodChannel _channel;

  // Stream controllers for native events
  final _countryChangedController = StreamController<CountryData?>.broadcast();
  final _cameraChangedController = StreamController<CameraPosition>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _presetSelectedController = StreamController<String>.broadcast();
  final _readyCompleter = Completer<void>();

  /// High-performance [ValueNotifier] holding the current detected country.
  /// Use with [ValueListenableBuilder] to update UI without calling [State.setState]
  /// or rebuilding the platform view.
  final ValueNotifier<CountryData?> countryNotifier = ValueNotifier<CountryData?>(null);

  /// High-performance [ValueNotifier] holding the current camera position.
  final ValueNotifier<CameraPosition?> cameraNotifier = ValueNotifier<CameraPosition?>(null);

  /// Broadcast stream emitting when the country under the center crosshair changes.
  /// Emits `null` when moving over international waters or unmapped regions.
  Stream<CountryData?> get onCountryChanged => _countryChangedController.stream;

  /// Broadcast stream emitting throttled camera position updates during globe manipulation.
  Stream<CameraPosition> get onCameraChanged => _cameraChangedController.stream;

  /// Broadcast stream emitting any runtime error or dataset loading failure.
  Stream<String> get onError => _errorController.stream;

  /// Broadcast stream emitting when a preset country chip is clicked.
  Stream<String> get onPresetSelected => _presetSelectedController.stream;

  /// Completes when the native MapKit 3D globe has fully initialized.
  Future<void> get whenReady => _readyCompleter.future;

  /// Internal factory for [FlagExplorerView].
  static FlagExplorerController init(int viewId) {
    return FlagExplorerController._(viewId);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onGlobeReady':
        if (!_readyCompleter.isCompleted) {
          _readyCompleter.complete();
        }
        break;

      case 'onCountryChanged':
        if (call.arguments == null) {
          countryNotifier.value = null;
          _countryChangedController.add(null);
        } else if (call.arguments is Map) {
          final data = CountryData.fromMap(call.arguments as Map);
          countryNotifier.value = data;
          _countryChangedController.add(data);
        }
        break;

      case 'onCameraChanged':
        if (call.arguments is Map) {
          final pos = CameraPosition.fromMap(call.arguments as Map);
          cameraNotifier.value = pos;
          _cameraChangedController.add(pos);
        }
        break;

      case 'onError':
        final message = (call.arguments as Map?)?['message'] as String? ?? 'Unknown error';
        _errorController.add(message);
        break;

      case 'onPresetSelected':
        final name = (call.arguments as Map?)?['name'] as String? ?? '';
        _presetSelectedController.add(name);
        break;

      default:
        break;
    }
  }

  /// Move camera to target coordinates and altitude.
  Future<void> setCamera({
    required double latitude,
    required double longitude,
    double? altitude,
    bool animated = true,
  }) async {
    await _channel.invokeMethod('setCamera', {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'animated': animated,
    });
  }

  /// Focus and highlight a country by its ISO 3-letter code (e.g. "USA", "VNM", "GBR", "JPN").
  /// Returns `true` if the country was found in the GeoJSON dataset and focused, `false` otherwise.
  Future<bool> focusCountry(
    String isoA3, {
    double? altitude,
    bool animated = true,
  }) async {
    final result = await _channel.invokeMethod<bool>('focusCountry', {
      'isoA3': isoA3,
      'altitude': altitude,
      'animated': animated,
    });
    return result ?? false;
  }

  /// Reset globe camera to default initial Earth overview framing.
  Future<void> resetCamera({bool animated = true}) async {
    await _channel.invokeMethod('resetCamera', {
      'animated': animated,
    });
  }

  /// Update border glow overlay color and fill transparency dynamically.
  Future<void> setOverlayStyle(GlobeOverlayStyle style) async {
    await _channel.invokeMethod('setOverlayStyle', style.toMap());
  }

  /// Retrieve currently highlighted country synchronously from native cache.
  Future<CountryData?> getCurrentCountry() async {
    final res = await _channel.invokeMethod<Map>('getCurrentCountry');
    if (res == null) return null;
    return CountryData.fromMap(res);
  }

  /// Query current camera position from native MapKit globe.
  Future<CameraPosition?> getCameraPosition() async {
    final res = await _channel.invokeMethod<Map>('getCameraPosition');
    if (res == null) return null;
    return CameraPosition.fromMap(res);
  }

  /// Clean up listeners and disconnect from the native view.
  void dispose() {
    _channel.setMethodCallHandler(null);
    countryNotifier.dispose();
    cameraNotifier.dispose();
    _countryChangedController.close();
    _cameraChangedController.close();
    _errorController.close();
    _presetSelectedController.close();
  }
}
