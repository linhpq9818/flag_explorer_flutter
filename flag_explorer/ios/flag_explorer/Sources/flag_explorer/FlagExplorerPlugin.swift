//
//  FlagExplorerPlugin.swift
//  flag_explorer
//
//  Created for Flag Explorer - Flutter iOS Plugin Entry Point
//

import Flutter
import UIKit

public class FlagExplorerPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        // Register the native Platform View factory for 'flag_explorer_view'
        let factory = FlagExplorerViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "flag_explorer_view")
        
        // Eagerly trigger background loading of countries.geojson so it's ready when the view appears
        DispatchQueue.global(qos: .userInitiated).async {
            _ = CountryGeoJSONService.shared.isLoaded
        }
    }
}
