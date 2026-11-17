import 'package:flutter/material.dart';
import 'package:flag_explorer/flag_explorer.dart';

void main() {
  runApp(const FlagExplorerExampleApp());
}

class FlagExplorerExampleApp extends StatelessWidget {
  const FlagExplorerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flag Explorer Plugin Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const FlagExplorerScreen(),
    );
  }
}

class FlagExplorerScreen extends StatefulWidget {
  const FlagExplorerScreen({super.key});

  @override
  State<FlagExplorerScreen> createState() => _FlagExplorerScreenState();
}

class _FlagExplorerScreenState extends State<FlagExplorerScreen> {
  // ignore: unused_field
  FlagExplorerController? _controller;

  // Zero-rebuild reactive state: ValueNotifier isolates updates to only the HUD pill,
  // completely eliminating setState() and parent PlatformView re-evaluations.
  final ValueNotifier<String> _detectedCountryNotifier = ValueNotifier<String>('Ready');

  @override
  void dispose() {
    _detectedCountryNotifier.dispose();
    super.dispose();
  }

  // Custom Curated Presets
  final List<GlobePresetItem> _customPresets = const [
    GlobePresetItem(name: 'Vietnam', emoji: '🇻🇳', isoA3: 'VNM', altitude: 8000000),
    GlobePresetItem(name: 'USA', emoji: '🇺🇸', isoA3: 'USA', altitude: 18000000),
    GlobePresetItem(name: 'Japan', emoji: '🇯🇵', isoA3: 'JPN', altitude: 8000000),
    GlobePresetItem(name: 'France', emoji: '🇫🇷', isoA3: 'FRA', altitude: 7500000),
    GlobePresetItem(name: 'Korea', emoji: '🇰🇷', isoA3: 'KOR', altitude: 7000000),
    GlobePresetItem(name: 'Egypt', emoji: '🇪🇬', isoA3: 'EGY', altitude: 9000000),
    GlobePresetItem(name: 'Brazil', emoji: '🇧🇷', isoA3: 'BRA', altitude: 16000000),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 100% Native iOS Experience with All Custom Configurations:
          // - Custom Presets
          // - Haptic Feedback on Border Crossing
          // - Tap to Focus on any Country
          // - Custom Cyan Crosshair
          // - Custom Cyan Glow Stroke + Blue Polygon Fill
          // - Custom Card Bottom Padding
          FlagExplorerView(
            customPresets: _customPresets,
            enableHapticFeedback: true,
            enableTapToFocus: true,
            cardBottomPadding: 32.0,
            crosshairColor: Colors.cyanAccent,
            crosshairSize: 58.0,
            overlayStyle: const GlobeOverlayStyle(
              strokeColor: Color(0xFF00F5FF), // Electric Cyan glow border
              fillColor: Color(0xFF007AFF),   // Translucent Sapphire Blue interior fill
              fillAlpha: 0.22,
            ),
            onGlobeReady: (controller) {
              _controller = controller;
            },
            onCountryChanged: (country) {
              // High-performance direct update: zero setState, zero parent rebuild
              _detectedCountryNotifier.value = country != null
                  ? '${country.flagEmoji} ${country.name} (${country.isoA3})'
                  : '🌊 Ocean / International';
            },
          ),

          // Lightweight Reactive Flutter HUD Pill (isolated repaint boundary)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: ValueListenableBuilder<String>(
                  valueListenable: _detectedCountryNotifier,
                  builder: (context, countryText, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app, color: Colors.cyanAccent, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            'Tap to Focus • $countryText',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
