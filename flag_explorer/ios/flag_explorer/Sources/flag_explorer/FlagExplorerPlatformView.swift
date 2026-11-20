//
//  FlagExplorerPlatformView.swift
//  flag_explorer
//
//  Created for Flag Explorer - Platform View Implementation for Flutter iOS
//

import Flutter
import UIKit
import SwiftUI
import MapKit

public class FlagExplorerPlatformView: NSObject, FlutterPlatformView {
    private let viewId: Int64
    private let channel: FlutterMethodChannel
    private let viewModel: GlobeViewModel
    private var hostingController: UIHostingController<NativeFlagExplorerView>?
    
    init(
        frame: CGRect,
        viewIdentifier: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        self.viewId = viewIdentifier
        self.channel = FlutterMethodChannel(
            name: "flag_explorer_view_\(viewIdentifier)",
            binaryMessenger: messenger
        )
        
        var initialLat: Double = 37.982941
        var initialLng: Double = -98.701740
        var initialDist: Double = 18_000_000
        var showCrosshair = true
        var showCard = true
        var showPresets = true
        var showReset = false
        var enableHaptics = true
        var enableTapFocus = true
        var cardPadding: CGFloat = 28.0
        var crosshairColor: Color = .white
        var crosshairSize: CGFloat = 56.0
        var parsedPresets: [NativePresetLocation]?
        
        if let params = args as? [String: Any] {
            if let lat = params["initialLatitude"] as? Double { initialLat = lat }
            if let lng = params["initialLongitude"] as? Double { initialLng = lng }
            if let dist = params["initialDistance"] as? Double { initialDist = dist }
            if let crosshair = params["showCenterCrosshair"] as? Bool { showCrosshair = crosshair }
            if let card = params["showCountryCard"] as? Bool { showCard = card }
            if let presets = params["showPresetControls"] as? Bool { showPresets = presets }
            if let reset = params["showResetButton"] as? Bool { showReset = reset }
            if let haptics = params["enableHapticFeedback"] as? Bool { enableHaptics = haptics }
            if let tapFocus = params["enableTapToFocus"] as? Bool { enableTapFocus = tapFocus }
            if let padding = params["cardBottomPadding"] as? Double { cardPadding = CGFloat(padding) }
            if let size = params["crosshairSize"] as? Double { crosshairSize = CGFloat(size) }
            
            if let crossColorHex = params["crosshairColor"] as? String, let uiColor = UIColor(hexString: crossColorHex) {
                crosshairColor = Color(uiColor)
            }
            
            // Custom presets parsing
            if let presetList = params["customPresets"] as? [[String: Any]] {
                var items: [NativePresetLocation] = []
                for p in presetList {
                    guard let name = p["name"] as? String,
                          let emoji = p["emoji"] as? String,
                          let iso = p["isoA3"] as? String else { continue }
                    
                    let lat = p["latitude"] as? Double
                    let lng = p["longitude"] as? Double
                    let dist = p["altitude"] as? Double ?? 18_000_000
                    
                    let coord: CLLocationCoordinate2D
                    if let la = lat, let lo = lng {
                        coord = CLLocationCoordinate2D(latitude: la, longitude: lo)
                    } else if let country = CountryGeoJSONService.shared.country(forIsoA3: iso) {
                        coord = country.visualCenter
                    } else {
                        coord = CLLocationCoordinate2D(latitude: 0, longitude: 0)
                    }
                    items.append(NativePresetLocation(name: name, flag: emoji, isoA3: iso, coordinate: coord, distance: dist))
                }
                parsedPresets = items
            }
            
            // Polygon styling: stroke, fill, alpha
            if let strokeHex = params["strokeColor"] as? String, let color = UIColor(hexString: strokeHex) {
                OverlayStyleConfig.shared.strokeColor = color
            } else if let glowHex = params["glowColor"] as? String, let color = UIColor(hexString: glowHex) {
                OverlayStyleConfig.shared.strokeColor = color
            }
            
            if let fillHex = params["fillColor"] as? String, let color = UIColor(hexString: fillHex) {
                OverlayStyleConfig.shared.fillColor = color
            } else if let glowHex = params["glowColor"] as? String, let color = UIColor(hexString: glowHex) {
                OverlayStyleConfig.shared.fillColor = color
            }
            
            if let fillAlpha = params["fillAlpha"] as? Double {
                OverlayStyleConfig.shared.fillAlpha = CGFloat(fillAlpha)
            }
            if let isNeon = params["isNeon"] as? Bool {
                OverlayStyleConfig.shared.isNeon = isNeon
            }
        }
        
        let vm = GlobeViewModel(
            initialCoordinate: CLLocationCoordinate2D(latitude: initialLat, longitude: initialLng),
            initialDistance: initialDist
        )
        vm.showCenterCrosshair = showCrosshair
        vm.showCountryCard = showCard
        vm.showPresetControls = showPresets
        vm.showResetButton = showReset
        vm.enableHapticFeedback = enableHaptics
        vm.enableTapToFocus = enableTapFocus
        vm.cardBottomPadding = cardPadding
        vm.crosshairColor = crosshairColor
        vm.crosshairSize = crosshairSize
        vm.customPresets = parsedPresets
        
        self.viewModel = vm
        super.init()
        
        setupCallbacks()
        setupMethodChannel()
        setupHostingController(frame: frame)
    }
    
    private func setupHostingController(frame: CGRect) {
        let rootView = NativeFlagExplorerView(viewModel: viewModel)
        let hc = UIHostingController(rootView: rootView)
        hc.view.frame = frame
        hc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hc.view.backgroundColor = .clear
        self.hostingController = hc
    }
    
    private func setupCallbacks() {
        viewModel.onPresetSelected = { [weak self] name in
            self?.channel.invokeMethod("onPresetSelected", arguments: ["name": name])
        }

        viewModel.onCountryChanged = { [weak self] country in
            self?.channel.invokeMethod("onCountryChanged", arguments: country?.toDictionary())
        }
        
        viewModel.onCameraChanged = { [weak self] camera in
            let payload: [String: Any] = [
                "latitude": camera.centerCoordinate.latitude,
                "longitude": camera.centerCoordinate.longitude,
                "altitude": camera.centerCoordinateDistance
            ]
            self?.channel.invokeMethod("onCameraChanged", arguments: payload)
        }
        
        viewModel.onGlobeReady = { [weak self] in
            guard let self = self else { return }
            self.channel.invokeMethod("onGlobeReady", arguments: nil)
            
            if let country = self.viewModel.detectedCountry {
                self.channel.invokeMethod("onCountryChanged", arguments: country.toDictionary())
            }
            
            if let error = CountryGeoJSONService.shared.loadError {
                self.channel.invokeMethod("onError", arguments: ["message": error])
            }
        }
    }
    
    public func view() -> UIView {
        return hostingController?.view ?? UIView()
    }
    
    // MARK: - Method Channel Handling
    private func setupMethodChannel() {
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else {
                result(FlutterError(code: "DISPOSED", message: "Platform view has been disposed", details: nil))
                return
            }
            self.handleMethodCall(call, result: result)
        }
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setCamera":
            guard let args = call.arguments as? [String: Any],
                  let lat = args["latitude"] as? Double,
                  let lng = args["longitude"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "latitude and longitude required", details: nil))
                return
            }
            let altitude = args["altitude"] as? Double ?? viewModel.cameraDistance
            viewModel.targetCameraCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            viewModel.targetCameraDistance = altitude
            viewModel.commandTrigger += 1
            result(nil)
            
        case "focusCountry":
            guard let args = call.arguments as? [String: Any],
                  let isoA3 = args["isoA3"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "isoA3 required", details: nil))
                return
            }
            let requestedAltitude = args["altitude"] as? Double
            
            if let country = CountryGeoJSONService.shared.country(forIsoA3: isoA3) {
                let coord = country.visualCenter
                let maxSpread = country.visualSpan
                
                let targetDistance: Double
                if let explicitAlt = requestedAltitude {
                    targetDistance = explicitAlt
                } else if maxSpread > 35 {
                    targetDistance = 22_000_000
                } else if maxSpread > 15 {
                    targetDistance = 14_000_000
                } else if maxSpread > 5 {
                    targetDistance = 8_000_000
                } else {
                    targetDistance = 4_500_000
                }
                
                viewModel.targetCameraCoordinate = coord
                viewModel.targetCameraDistance = targetDistance
                viewModel.commandTrigger += 1
                result(true)
            } else {
                result(false)
            }
            
        case "resetCamera":
            viewModel.targetCameraCoordinate = CLLocationCoordinate2D(latitude: 37.982941, longitude: -98.701740)
            viewModel.targetCameraDistance = 18_000_000
            viewModel.commandTrigger += 1
            result(nil)
            
        case "setOverlayStyle":
            if let args = call.arguments as? [String: Any] {
                if let strokeHex = args["strokeColor"] as? String, let color = UIColor(hexString: strokeHex) {
                    OverlayStyleConfig.shared.strokeColor = color
                } else if let glowHex = args["glowColor"] as? String, let color = UIColor(hexString: glowHex) {
                    OverlayStyleConfig.shared.strokeColor = color
                }
                
                if let fillHex = args["fillColor"] as? String, let color = UIColor(hexString: fillHex) {
                    OverlayStyleConfig.shared.fillColor = color
                } else if let glowHex = args["glowColor"] as? String, let color = UIColor(hexString: glowHex) {
                    OverlayStyleConfig.shared.fillColor = color
                }
                
                if let alpha = args["fillAlpha"] as? Double {
                    OverlayStyleConfig.shared.fillAlpha = CGFloat(alpha)
                }
                if let isNeon = args["isNeon"] as? Bool {
                    OverlayStyleConfig.shared.isNeon = isNeon
                }
            }
            result(nil)
            
        case "getCurrentCountry":
            if let country = viewModel.detectedCountry {
                result(country.toDictionary())
            } else {
                result(nil)
            }
            
        case "getCameraPosition":
            let dict: [String: Any] = [
                "latitude": viewModel.centerCoordinate.latitude,
                "longitude": viewModel.centerCoordinate.longitude,
                "altitude": viewModel.cameraDistance
            ]
            result(dict)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Cleanup / Deallocation
    deinit {
        channel.setMethodCallHandler(nil)
        viewModel.onCountryChanged = nil
        viewModel.onCameraChanged = nil
        viewModel.onGlobeReady = nil
        viewModel.onPresetSelected = nil
        hostingController?.view.removeFromSuperview()
        hostingController = nil
    }
}

// MARK: - Hex Color Helper
private extension UIColor {
    convenience init?(hexString: String) {
        var cString = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }
        guard cString.count == 6 || cString.count == 8 else { return nil }
        
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        
        if cString.count == 8 {
            let a = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
            let r = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
            let g = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
            let b = CGFloat(rgbValue & 0x000000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: a)
        } else {
            let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(rgbValue & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: 1.0)
        }
    }
}
