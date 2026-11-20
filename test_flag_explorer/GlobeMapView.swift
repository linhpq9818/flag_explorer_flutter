//
//  GlobeMapView.swift
//  test_flag_explorer
//
//  Created for Flag Explorer - Standalone 3D Globe with GeoJSON Country Detection
//

import SwiftUI
import MapKit

/// SwiftUI wrapper for MKMapView displaying a 3D satellite globe and handling country overlays
struct GlobeMapView: UIViewRepresentable {
    @Binding var centerCoordinate: CLLocationCoordinate2D
    @Binding var detectedCountry: CountryFeature?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView
        
        // Configure 3D Globe with realistic elevation and pure satellite imagery
        let config = MKImageryMapConfiguration(elevationStyle: .realistic)
        mapView.preferredConfiguration = config
        
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.showsCompass = true
        mapView.showsScale = false
        
        // Initial camera looking at Earth globe from altitude (18,000 km for optimal framing)
        let initialCoord = centerCoordinate
        let camera = MKMapCamera(lookingAtCenter: initialCoord, fromDistance: 18_000_000, pitch: 0, heading: 0)
        mapView.setCamera(camera, animated: false)
        
        // Initial lookup
        context.coordinator.performDetection(at: initialCoord, isIdle: true)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.parent = self
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: GlobeMapView
        weak var mapView: MKMapView?
        
        // Active GeoJSON country overlay tracking
        private var currentHighlightedCountryId: String?
        private var currentOverlay: MKOverlay?
        
        // Throttle control for map movement
        private var lastLookupTime: TimeInterval = 0
        private let throttleInterval: TimeInterval = 0.05 // 50ms (~20 lookups/sec during fast spins)
        private var activeLookupToken: UUID?
        
        init(_ parent: GlobeMapView) {
            self.parent = parent
        }
        
        // MARK: - Region & Center Tracking
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            let center = mapView.camera.centerCoordinate
            
            DispatchQueue.main.async {
                self.parent.centerCoordinate = center
            }
            
            let now = CACurrentMediaTime()
            if now - lastLookupTime >= throttleInterval {
                lastLookupTime = now
                performDetection(at: center, isIdle: false)
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let center = mapView.camera.centerCoordinate
            
            DispatchQueue.main.async {
                self.parent.centerCoordinate = center
            }
            
            // Reconfirm detection accurately when movement stops
            performDetection(at: center, isIdle: true)
        }
        
        // MARK: - Country Detection & Boundary Highlighting
        func performDetection(at coordinate: CLLocationCoordinate2D, isIdle: Bool) {
            let token = UUID()
            self.activeLookupToken = token
            
            // Execute ray-casting point-in-polygon on background thread (prevents UI hitching)
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                guard let self = self, self.activeLookupToken == token else { return }
                let country = CountryGeoJSONService.shared.findCountry(at: coordinate)
                guard self.activeLookupToken == token else { return }
                
                // Warm up overlay on background thread
                let preparedOverlay = country?.overlay
                
                DispatchQueue.main.async {
                    guard self.activeLookupToken == token else { return }
                    
                    if let country = country {
                        // Update overlay highlight only if the detected country changed
                        if self.currentHighlightedCountryId != country.id {
                            self.currentHighlightedCountryId = country.id
                            self.parent.detectedCountry = country
                            self.updateOverlay(with: country, preparedOverlay: preparedOverlay)
                        }
                    } else {
                        // Over ocean or unclaimed area
                        if self.currentHighlightedCountryId != nil {
                            self.currentHighlightedCountryId = nil
                            self.parent.detectedCountry = nil
                            self.clearOverlay()
                        }
                    }
                }
            }
        }
        
        private func updateOverlay(with country: CountryFeature, preparedOverlay: MKOverlay? = nil) {
            guard let mapView = mapView else { return }
            let newOverlay = preparedOverlay ?? country.overlay
            if let old = currentOverlay {
                if old === newOverlay { return }
                mapView.removeOverlay(old)
            }
            currentOverlay = newOverlay
            mapView.addOverlay(newOverlay, level: .aboveRoads)
        }
        
        private func clearOverlay() {
            guard let mapView = mapView, let old = currentOverlay else { return }
            mapView.removeOverlay(old)
            currentOverlay = nil
        }
        
        // MARK: - Custom Overlay Renderer
        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if let multiPolygon = overlay as? MKMultiPolygon {
                return GlowingMultiPolygonRenderer(multiPolygon: multiPolygon)
            } else if let polygon = overlay as? MKPolygon {
                return GlowingPolygonRenderer(polygon: polygon)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
