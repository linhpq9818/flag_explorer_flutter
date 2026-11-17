import 'package:flutter/material.dart';
import 'package:flag_explorer/flag_explorer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LatLng serialization and equality', () {
    const coord1 = LatLng(37.982941, -98.701740);
    const coord2 = LatLng(37.982941, -98.701740);
    expect(coord1, equals(coord2));

    final map = coord1.toMap();
    final restored = LatLng.fromMap(map);
    expect(restored, equals(coord1));
  });

  test('CountryData model parsing', () {
    final map = {
      'id': 'USA',
      'name': 'United States',
      'isoA3': 'USA',
      'isoA2': 'US',
      'flagEmoji': '🇺🇸',
      'flagUrl': 'https://flagcdn.com/w320/us.png',
      'centerLat': 37.09,
      'centerLng': -95.71,
    };

    final country = CountryData.fromMap(map);
    expect(country.id, 'USA');
    expect(country.name, 'United States');
    expect(country.isoA3, 'USA');
    expect(country.isoA2, 'US');
    expect(country.flagEmoji, '🇺🇸');
    expect(country.flagUrl, 'https://flagcdn.com/w320/us.png');
    expect(country.center.latitude, 37.09);
    expect(country.center.longitude, -95.71);
  });

  test('GlobePresetItem serialization', () {
    const preset = GlobePresetItem(
      name: 'Vietnam',
      emoji: '🇻🇳',
      isoA3: 'VNM',
      latitude: 14.0583,
      longitude: 108.2772,
      altitude: 8000000.0,
    );
    final map = preset.toMap();
    expect(map['name'], 'Vietnam');
    expect(map['emoji'], '🇻🇳');
    expect(map['isoA3'], 'VNM');
    expect(map['latitude'], 14.0583);
    expect(map['longitude'], 108.2772);
    expect(map['altitude'], 8000000.0);
  });

  test('GlobeOverlayStyle custom stroke and fill colors', () {
    const style = GlobeOverlayStyle(
      strokeColor: Colors.cyan,
      fillColor: Colors.blue,
      fillAlpha: 0.25,
    );
    final map = style.toMap();
    expect(map['strokeColor'], startsWith('#'));
    expect(map['fillColor'], startsWith('#'));
    expect(map['fillAlpha'], 0.25);
  });

  test('FlagExplorerController notifiers and reactive state', () {
    final controller = FlagExplorerController.init(42);
    expect(controller.countryNotifier.value, isNull);
    expect(controller.cameraNotifier.value, isNull);

    controller.countryNotifier.value = const CountryData(
      id: 'VNM',
      name: 'Vietnam',
      isoA3: 'VNM',
      flagEmoji: '🇻🇳',
      center: LatLng(14.0583, 108.2772),
    );
    expect(controller.countryNotifier.value?.name, 'Vietnam');
    expect(controller.countryNotifier.value?.isoA3, 'VNM');

    controller.cameraNotifier.value = const CameraPosition(
      center: LatLng(14.0583, 108.2772),
      altitude: 8000000.0,
    );
    expect(controller.cameraNotifier.value?.altitude, 8000000.0);

    controller.dispose();
  });
}
