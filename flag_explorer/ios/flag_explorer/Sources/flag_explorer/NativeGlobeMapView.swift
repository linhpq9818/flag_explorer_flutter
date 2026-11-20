//
//  NativeGlobeMapView.swift
//  flag_explorer
//
//  Created for Flag Explorer - High-performance SwiftUI MapKit 3D Globe Representable
//

import SwiftUI
import MapKit

public class GlobeViewModel: ObservableObject {
    @Published public var centerCoordinate: CLLocationCoordinate2D
    @Published public var cameraDistance: Double
    @Published public var detectedCountry: CountryFeature?
    
    // Programmatic target camera animation requests
    @Published public var targetCameraCoordinate: CLLocationCoordinate2D?
    @Published public var targetCameraDistance: Double?
    @Published public var commandTrigger: Int = 0
    
    // UI visibility toggles
    public var showCenterCrosshair: Bool = true
    public var showCountryCard: Bool = true
    public var showPresetControls: Bool = true
    public var showResetButton: Bool = false
    
    // Customization Options
    public var enableHapticFeedback: Bool = true
    public var enableTapToFocus: Bool = true
    public var cardBottomPadding: CGFloat = 28.0
    public var crosshairColor: Color = .white
    public var crosshairSize: CGFloat = 56.0
    public var customPresets: [NativePresetLocation]?
    
    public func triggerHapticFeedback() {
        guard enableHapticFeedback else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // Callbacks to Flutter MethodChannel
    public var onCountryChanged: ((CountryFeature?) -> Void)?
    public var onCameraChanged: ((MKMapCamera) -> Void)?
    public var onGlobeReady: (() -> Void)?
    public var onPresetSelected: ((String) -> Void)?
    
    public init(
        initialCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.982941, longitude: -98.701740),
        initialDistance: Double = 18_000_000
    ) {
        self.centerCoordinate = initialCoordinate
        self.cameraDistance = initialDistance
    }
}

public struct NativeGlobeMapView: UIViewRepresentable {
    @ObservedObject public var viewModel: GlobeViewModel
    
    public init(viewModel: GlobeViewModel) {
        self.viewModel = viewModel
    }
    
    public func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView
        
        // 3D Realistic Globe Satellite Configuration
        let config = MKImageryMapConfiguration(elevationStyle: .realistic)
        mapView.preferredConfiguration = config
        
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.showsCompass = true
        mapView.showsScale = false
        
        let initialCoord = viewModel.centerCoordinate
        let camera = MKMapCamera(
            lookingAtCenter: initialCoord,
            fromDistance: viewModel.cameraDistance,
            pitch: 0,
            heading: 0
        )
        mapView.setCamera(camera, animated: false)
        
        // Initial lookup
        context.coordinator.performDetection(at: initialCoord)
        
        // Tap to Focus Gesture
        if viewModel.enableTapToFocus {
            let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
            mapView.addGestureRecognizer(tapGesture)
        }
        
        DispatchQueue.main.async {
            self.viewModel.onGlobeReady?()
        }
        
        return mapView
    }
    
    public func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.viewModel = viewModel
        
        // Handle programmatic camera moves (e.g., preset chips or Flutter commands)
        if let target = viewModel.targetCameraCoordinate,
           context.coordinator.lastCommandTrigger != viewModel.commandTrigger {
            context.coordinator.lastCommandTrigger = viewModel.commandTrigger
            
            let distance = viewModel.targetCameraDistance ?? uiView.camera.centerCoordinateDistance
            let newCamera = MKMapCamera(
                lookingAtCenter: target,
                fromDistance: distance,
                pitch: 0,
                heading: 0
            )
            uiView.setCamera(newCamera, animated: true)
            context.coordinator.performDetection(at: target)
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(viewModel)
    }
    
    public class Coordinator: NSObject, MKMapViewDelegate {
        var viewModel: GlobeViewModel
        weak var mapView: MKMapView?
        var lastCommandTrigger: Int = -1
        
        private var currentHighlightedCountryId: String?
        private var currentOverlay: MKOverlay?
        
        // Background PIP lookup synchronization
        private var activeLookupToken: UUID?
        private var lastLookupTime: TimeInterval = 0
        private let throttleInterval: TimeInterval = 0.05 // 50ms
        
        private var lastCameraEmitTime: TimeInterval = 0
        private let cameraEmitInterval: TimeInterval = 0.10 // 100ms
        
        init(_ viewModel: GlobeViewModel) {
            self.viewModel = viewModel
        }
        
        // MARK: - Region & Center Tracking
        public func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            let center = mapView.camera.centerCoordinate
            let distance = mapView.camera.centerCoordinateDistance
            
            // Immediate local state update for buttery smooth UI
            self.viewModel.centerCoordinate = center
            self.viewModel.cameraDistance = distance
            
            let now = CACurrentMediaTime()
            if now - lastLookupTime >= throttleInterval {
                lastLookupTime = now
                performDetection(at: center)
            }
            
            if now - lastCameraEmitTime >= cameraEmitInterval {
                lastCameraEmitTime = now
                viewModel.onCameraChanged?(mapView.camera)
            }
        }
        
        public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let center = mapView.camera.centerCoordinate
            let distance = mapView.camera.centerCoordinateDistance
            self.viewModel.centerCoordinate = center
            self.viewModel.cameraDistance = distance
            performDetection(at: center)
            viewModel.onCameraChanged?(mapView.camera)
        }
        
        // MARK: - Tap-to-Focus Interaction
        @objc func handleMapTap(_ recognizer: UITapGestureRecognizer) {
            guard let mapView = mapView else { return }
            let tapPoint = recognizer.location(in: mapView)
            let tapCoord = mapView.convert(tapPoint, toCoordinateFrom: mapView)
            
            // Execute on background queue to keep touch handling 100% fluid
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                guard let self = self else { return }
                if let country = CountryGeoJSONService.shared.findCountry(at: tapCoord) {
                    let centerLat = (country.bbox.minLat + country.bbox.maxLat) / 2.0
                    let centerLon = (country.bbox.minLon + country.bbox.maxLon) / 2.0
                    let coord = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
                    
                    let latSpread = abs(country.bbox.maxLat - country.bbox.minLat)
                    let lonSpread = abs(country.bbox.maxLon - country.bbox.minLon)
                    let maxSpread = max(latSpread, lonSpread)
                    
                    let targetDistance: Double
                    if maxSpread > 35 { targetDistance = 22_000_000 }
                    else if maxSpread > 15 { targetDistance = 14_000_000 }
                    else if maxSpread > 5 { targetDistance = 8_000_000 }
                    else { targetDistance = 4_500_000 }
                    
                    DispatchQueue.main.async {
                        self.viewModel.targetCameraCoordinate = coord
                        self.viewModel.targetCameraDistance = targetDistance
                        self.viewModel.commandTrigger += 1
                        self.viewModel.triggerHapticFeedback()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.viewModel.targetCameraCoordinate = tapCoord
                        self.viewModel.commandTrigger += 1
                    }
                }
            }
        }
        
        // MARK: - Background Threaded Country Detection
        func performDetection(at coordinate: CLLocationCoordinate2D) {
            let token = UUID()
            self.activeLookupToken = token
            
            // Execute ray-casting point-in-polygon on background thread (prevents UI hitching)
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                guard let self = self, self.activeLookupToken == token else { return }
                let country = CountryGeoJSONService.shared.findCountry(at: coordinate)
                guard self.activeLookupToken == token else { return }
                
                DispatchQueue.main.async {
                    guard self.activeLookupToken == token else { return }
                    
                    if let country = country {
                        if self.currentHighlightedCountryId != country.id {
                            self.currentHighlightedCountryId = country.id
                            self.viewModel.detectedCountry = country
                            self.updateOverlay(with: country)
                            self.viewModel.onCountryChanged?(country)
                            self.viewModel.triggerHapticFeedback()
                        }
                    } else {
                        if self.currentHighlightedCountryId != nil {
                            self.currentHighlightedCountryId = nil
                            self.viewModel.detectedCountry = nil
                            self.clearOverlay()
                            self.viewModel.onCountryChanged?(nil)
                        }
                    }
                }
            }
        }
        
        private func updateOverlay(with country: CountryFeature) {
            guard let mapView = mapView else { return }
            if let old = currentOverlay {
                mapView.removeOverlay(old)
            }
            let newOverlay = country.overlay
            currentOverlay = newOverlay
            mapView.addOverlay(newOverlay, level: .aboveRoads)
        }
        
        private func clearOverlay() {
            guard let mapView = mapView, let old = currentOverlay else { return }
            mapView.removeOverlay(old)
            currentOverlay = nil
        }
        
        // MARK: - Overlay Renderer
        public func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if let multiPolygon = overlay as? MKMultiPolygon {
                return GlowingMultiPolygonRenderer(multiPolygon: multiPolygon)
            } else if let polygon = overlay as? MKPolygon {
                return GlowingPolygonRenderer(polygon: polygon)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
