import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'flag_explorer_controller.dart';
import 'models.dart';

/// Callback invoked when a [FlagExplorerController] is ready for interaction.
typedef GlobeReadyCallback = void Function(FlagExplorerController controller);

/// Callback invoked when the country under the center crosshair changes.
typedef CountryChangedCallback = void Function(CountryData? country);

/// Callback invoked when the camera position changes during user interaction or animation.
typedef CameraChangedCallback = void Function(CameraPosition position);

/// Callback invoked when an error occurs in the native layer.
typedef GlobeErrorCallback = void Function(String errorMessage);

/// Embeddable 3D MapKit Satellite Globe with GeoJSON Country Highlighting.
///
/// NOTE: This plugin is iOS-only. When run on other platforms, an unsupported
/// placeholder is rendered.
class FlagExplorerView extends StatefulWidget {
  const FlagExplorerView({
    super.key,
    this.onGlobeReady,
    this.onCountryChanged,
    this.onCameraChanged,
    this.onError,
    this.initialCoordinate = const LatLng(37.982941, -98.701740),
    this.initialDistance = 18000000.0,
    this.overlayStyle = const GlobeOverlayStyle(),
    this.showCenterCrosshair = true,
    this.showCountryCard = true,
    this.showPresetControls = true,
    this.customPresets,
    this.enableHapticFeedback = true,
    this.cardBottomPadding = 28.0,
    this.crosshairColor = const Color(0xFFFFFFFF),
    this.crosshairSize = 56.0,
    this.enableTapToFocus = true,
  });

  /// Called when the native MapKit globe view is fully mounted and ready.
  final GlobeReadyCallback? onGlobeReady;

  /// Called whenever the country under the globe center crosshair changes.
  final CountryChangedCallback? onCountryChanged;

  /// Called when the camera moves (throttled).
  final CameraChangedCallback? onCameraChanged;

  /// Called if an error occurs (such as GeoJSON loading failure).
  final GlobeErrorCallback? onError;

  /// Initial camera center coordinate (defaults to continental USA).
  final LatLng initialCoordinate;

  /// Initial camera altitude in meters (defaults to 18,000 km space orbit).
  final double initialDistance;

  /// Glowing country boundary overlay styling.
  final GlobeOverlayStyle overlayStyle;

  /// Whether to display the native center crosshair indicator.
  final bool showCenterCrosshair;

  /// Whether to display the native floating liquid glass country information card.
  final bool showCountryCard;

  /// Whether to display the native horizontal preset country pills/controls.
  final bool showPresetControls;

  /// Custom list of preset country items to display in the horizontal carousel.
  final List<GlobePresetItem>? customPresets;

  /// Whether to trigger physical haptic feedback when entering a newly detected country.
  final bool enableHapticFeedback;

  /// Bottom inset/margin for the country card (default 28.0), useful to avoid bottom nav bars.
  final double cardBottomPadding;

  /// Color of the native center targeting crosshair.
  final Color crosshairColor;

  /// Diameter/size of the native center targeting crosshair in points.
  final double crosshairSize;

  /// Whether tapping on a country on the globe moves and focuses the camera on it.
  final bool enableTapToFocus;

  @override
  State<FlagExplorerView> createState() => _FlagExplorerViewState();
}

class _FlagExplorerViewState extends State<FlagExplorerView> {
  FlagExplorerController? _controller;
  StreamSubscription<CountryData?>? _countrySub;
  StreamSubscription<CameraPosition>? _cameraSub;
  StreamSubscription<String>? _errorSub;

  @override
  void dispose() {
    _countrySub?.cancel();
    _cameraSub?.cancel();
    _errorSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _onPlatformViewCreated(int id) async {
    final controller = FlagExplorerController.init(id);
    _controller = controller;

    _countrySub = controller.onCountryChanged.listen((country) {
      widget.onCountryChanged?.call(country);
    });

    _cameraSub = controller.onCameraChanged.listen((pos) {
      widget.onCameraChanged?.call(pos);
    });

    _errorSub = controller.onError.listen((err) {
      widget.onError?.call(err);
    });

    // Fetch initial country and camera position if already ready
    final initialCountry = await controller.getCurrentCountry();
    if (mounted && initialCountry != null) {
      controller.countryNotifier.value = initialCountry;
      widget.onCountryChanged?.call(initialCountry);
    }
    final initialCamera = await controller.getCameraPosition();
    if (mounted && initialCamera != null) {
      controller.cameraNotifier.value = initialCamera;
      widget.onCameraChanged?.call(initialCamera);
    }

    widget.onGlobeReady?.call(controller);
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return Container(
        color: const Color(0xFF0D1117),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public_off, color: Colors.white54, size: 48),
            SizedBox(height: 12),
            Text(
              'Flag Explorer requires Apple MapKit 3D Globe and is only supported on iOS.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final crosshairHex =
        '#${(widget.crosshairColor.toARGB32() & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';

    final creationParams = <String, dynamic>{
      'initialLatitude': widget.initialCoordinate.latitude,
      'initialLongitude': widget.initialCoordinate.longitude,
      'initialDistance': widget.initialDistance,
      'showCenterCrosshair': widget.showCenterCrosshair,
      'showCountryCard': widget.showCountryCard,
      'showPresetControls': widget.showPresetControls,
      if (widget.customPresets != null)
        'customPresets': widget.customPresets!.map((p) => p.toMap()).toList(),
      'enableHapticFeedback': widget.enableHapticFeedback,
      'cardBottomPadding': widget.cardBottomPadding,
      'crosshairColor': crosshairHex,
      'crosshairSize': widget.crosshairSize,
      'enableTapToFocus': widget.enableTapToFocus,
      ...widget.overlayStyle.toMap(),
    };

    return UiKitView(
      viewType: 'flag_explorer_view',
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }
}
