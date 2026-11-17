//
//  GlowingOverlayRenderers.swift
//  test_flag_explorer
//
//  Created for Flag Explorer - Optimized Pure-Vector Glowing Country Overlays
//

import UIKit
import MapKit

/// Shared configuration styling for glowing country boundary overlays
struct OverlayStyle {
    static let glowColor = UIColor.systemRed
    static let fillAlpha: CGFloat = 0.18
    
    // Zoom-adaptive stroke widths (screen points)
    static func strokeWidths(for zoomScale: MKZoomScale) -> (outer: CGFloat, mid: CGFloat, core: CGFloat) {
        // At space altitude (~35,000 km, zoomScale ~ 8e-6), scale down slightly to prevent island fusing
        // When zoomed in (zoomScale >= 2.5e-5), full widths: 6.0 pt, 3.5 pt, 1.5 pt
        let factor = min(1.0, max(0.65, CGFloat(zoomScale) / 2.5e-5))
        return (outer: 6.0 * factor, mid: 3.5 * factor, core: 1.5 * factor)
    }
    
    static let outerStrokeAlpha: CGFloat = 0.20
    static let midStrokeAlpha: CGFloat = 0.45
    static let coreStrokeAlpha: CGFloat = 1.0
}

/// Unified drawing engine for country overlays with pure-vector glow and adaptive LOD
enum CountryOverlayDrawing {
    static func canDraw(cache: CountryRenderCache, mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        let zoom = Double(zoomScale)
        guard zoom > 0 else { return false }
        
        let glowRadius = Double(GlowStyleConfig.strokeWidths(for: zoomScale).outer / CGFloat(zoomScale))
        let expandedTotal = cache.totalBoundingMapRect.insetBy(dx: -glowRadius, dy: -glowRadius)
        guard mapRect.intersects(expandedTotal) else { return false }
        
        if cache.components.count <= 1 {
            return true
        }
        
        let needsLOD = zoom < 2.5e-5
        let largestDim = cache.largestComponentDimension
        
        for comp in cache.components {
            if needsLOD && comp.maxDimension != largestDim && (comp.maxDimension * zoom < 2.5) {
                continue
            }
            let expandedComp = comp.boundingMapRect.insetBy(dx: -glowRadius, dy: -glowRadius)
            if mapRect.intersects(expandedComp) {
                return true
            }
        }
        
        return false
    }
    
    static func draw(cache: CountryRenderCache, mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard mapRect.intersects(cache.totalBoundingMapRect) else { return }
        
        let drawFillPath: CGPath
        let drawStrokePath: CGPath
        
        let zoom = Double(zoomScale)
        let needsLOD = cache.components.count > 1 && (zoom < 2.5e-5)
        
        if cache.components.count == 1 {
            drawFillPath = cache.fullFillPath
            drawStrokePath = cache.fullStrokePath
        } else {
            let fill = CGMutablePath()
            let stroke = CGMutablePath()
            var visibleCount = 0
            let largestDim = cache.largestComponentDimension
            
            for comp in cache.components {
                guard mapRect.intersects(comp.boundingMapRect) else { continue }
                
                // Adaptive Screen-Space LOD:
                // Small islands with max screen dimension < 2.5 points are omitted at high altitude (space view)
                // Always preserve the primary/largest component so single-island countries never disappear
                if needsLOD && comp.maxDimension != largestDim && (comp.maxDimension * zoom < 2.5) {
                    continue
                }
                
                fill.addPath(comp.fillPath)
                stroke.addPath(comp.strokePath)
                visibleCount += 1
            }
            
            guard visibleCount > 0 else { return }
            drawFillPath = fill
            drawStrokePath = stroke
        }
        
        context.saveGState()
        
        // 1. Separate Fill Pass (translucent red, rendered independently from glow strokes)
        if !drawFillPath.isEmpty {
            context.setFillColor(OverlayStyle.glowColor.withAlphaComponent(OverlayStyle.fillAlpha).cgColor)
            context.addPath(drawFillPath)
            context.fillPath()
        }
        
        // 2. Pure-Vector Multi-Stroke Glow Pass (outer, middle, core)
        if !drawStrokePath.isEmpty {
            let widths = OverlayStyle.strokeWidths(for: zoomScale)
            let outerWidth = widths.outer / CGFloat(zoomScale)
            let midWidth = widths.mid / CGFloat(zoomScale)
            let coreWidth = widths.core / CGFloat(zoomScale)
            
            context.setLineJoin(.round)
            context.setLineCap(.round)
            
            // Pass 1: Outer soft glow stroke
            context.setLineWidth(outerWidth)
            context.setStrokeColor(OverlayStyle.glowColor.withAlphaComponent(OverlayStyle.outerStrokeAlpha).cgColor)
            context.addPath(drawStrokePath)
            context.strokePath()
            
            // Pass 2: Middle glow stroke
            context.setLineWidth(midWidth)
            context.setStrokeColor(OverlayStyle.glowColor.withAlphaComponent(OverlayStyle.midStrokeAlpha).cgColor)
            context.addPath(drawStrokePath)
            context.strokePath()
            
            // Pass 3: Core crisp stroke
            context.setLineWidth(coreWidth)
            context.setStrokeColor(OverlayStyle.glowColor.withAlphaComponent(OverlayStyle.coreStrokeAlpha).cgColor)
            context.addPath(drawStrokePath)
            context.strokePath()
        }
        
        context.restoreGState()
    }
}

/// Custom overlay renderer for MultiPolygons with red boundary highlight, graduated pure-vector glow, and cached paths
class GlowingMultiPolygonRenderer: MKMultiPolygonRenderer {
    override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        if let countryOverlay = self.overlay as? CountryOverlay,
           let cache = countryOverlay.renderCache {
            return CountryOverlayDrawing.canDraw(cache: cache, mapRect: mapRect, zoomScale: zoomScale)
        }
        return super.canDraw(mapRect, zoomScale: zoomScale)
    }
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        if let countryOverlay = self.overlay as? CountryOverlay,
           let cache = countryOverlay.renderCache {
            CountryOverlayDrawing.draw(cache: cache, mapRect: mapRect, zoomScale: zoomScale, in: context)
        }
    }
}

/// Custom overlay renderer for single Polygons with red boundary highlight, graduated pure-vector glow, and cached paths
class GlowingPolygonRenderer: MKPolygonRenderer {
    override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        if let countryOverlay = self.overlay as? CountryOverlay,
           let cache = countryOverlay.renderCache {
            return CountryOverlayDrawing.canDraw(cache: cache, mapRect: mapRect, zoomScale: zoomScale)
        }
        return super.canDraw(mapRect, zoomScale: zoomScale)
    }
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        if let countryOverlay = self.overlay as? CountryOverlay,
           let cache = countryOverlay.renderCache {
            CountryOverlayDrawing.draw(cache: cache, mapRect: mapRect, zoomScale: zoomScale, in: context)
        }
    }
}
