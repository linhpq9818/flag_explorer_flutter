//
//  GlowingOverlayRenderers.swift
//  flag_explorer
//
//  Created for Flag Explorer - Optimized Pure-Vector Glowing Country Overlays
//

import UIKit
import MapKit

/// Dynamic configuration styling for glowing country boundary overlays
public final class OverlayStyleConfig {
    public static let shared = OverlayStyleConfig()
    
    public var strokeColor: UIColor = .systemRed
    public var fillColor: UIColor = .systemRed
    public var fillAlpha: CGFloat = 0.18
    public var isNeon: Bool = true
    public var outerStrokeAlpha: CGFloat = 0.20
    public var midStrokeAlpha: CGFloat = 0.45
    public var coreStrokeAlpha: CGFloat = 1.0
    
    public var glowColor: UIColor {
        get { strokeColor }
        set {
            strokeColor = newValue
            fillColor = newValue
        }
    }
    
    private init() {}
    
    // Zoom-adaptive stroke widths (screen points)
    public func strokeWidths(for zoomScale: MKZoomScale) -> (
        bloomUltra: CGFloat,
        bloomWide: CGFloat,
        halo: CGFloat,
        outer: CGFloat,
        mid: CGFloat,
        core: CGFloat
    ) {
        // At space altitude (~35,000 km, zoomScale ~ 8e-6), scale down slightly to prevent island fusing
        // When zoomed in (zoomScale >= 2.5e-5), full widths: 26.0 pt ultra, 16.0 pt wide, 9.0 pt halo, 4.8 pt outer, 2.4 pt mid, 1.0 pt core
        let factor = min(1.0, max(0.65, CGFloat(zoomScale) / 2.5e-5))
        return (
            bloomUltra: 26.0 * factor,
            bloomWide: 16.0 * factor,
            halo: 9.0 * factor,
            outer: 4.8 * factor,
            mid: 2.4 * factor,
            core: 1.0 * factor
        )
    }
}

/// Unified drawing engine for country overlays with pure-vector glow and adaptive LOD
public enum CountryOverlayDrawing {
    /// Fast spatial evaluation determining whether MapKit should allocate and invoke draw() for this tile.
    /// Drops empty tiles and ocean gaps immediately without wasting background thread cycles.
    public static func canDraw(cache: CountryRenderCache, mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        let zoom = Double(zoomScale)
        guard zoom > 0 else { return false }
        
        let style = OverlayStyleConfig.shared
        let glowRadius = Double(style.strokeWidths(for: zoomScale).bloomUltra / CGFloat(zoomScale))
        
        // 1. Fast reject: does mapRect intersect the expanded bounding box of the entire country?
        let expandedTotal = cache.totalBoundingMapRect.insetBy(dx: -glowRadius, dy: -glowRadius)
        guard mapRect.intersects(expandedTotal) else { return false }
        
        // Single component country (e.g. France, Germany, Poland)
        if cache.components.count <= 1 {
            return true
        }
        
        // 2. MultiPolygon country (USA, Russia, Canada, Indonesia, Japan):
        // Drops empty ocean/gap tiles between separated landmasses (e.g. ocean between Hawaii and California).
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
    
    public static func draw(cache: CountryRenderCache, mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
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
        
        let style = OverlayStyleConfig.shared
        context.saveGState()
        
        // 1. Separate Fill Pass (translucent color, rendered independently from glow strokes)
        if !drawFillPath.isEmpty {
            context.setFillColor(style.fillColor.withAlphaComponent(style.fillAlpha).cgColor)
            context.addPath(drawFillPath)
            context.fillPath()
        }
        
        // 2. Pure-Vector Multi-Stroke Glow Pass (outer, middle, core)
        if !drawStrokePath.isEmpty {
            let widths = style.strokeWidths(for: zoomScale)
            
            context.setLineJoin(.round)
            context.setLineCap(.round)
            
            if style.isNeon {
                // Pass 1: Ultra-Wide Atmospheric Neon Bloom (26 pt) - dreamy soft blurry glow
                context.setLineWidth(widths.bloomUltra / CGFloat(zoomScale))
                context.setStrokeColor(style.strokeColor.withAlphaComponent(0.12).cgColor)
                context.addPath(drawStrokePath)
                context.strokePath()
                
                // Pass 2: Wide Diffuse Glow (16 pt)
                context.setLineWidth(widths.bloomWide / CGFloat(zoomScale))
                context.setStrokeColor(style.strokeColor.withAlphaComponent(0.24).cgColor)
                context.addPath(drawStrokePath)
                context.strokePath()
                
                // Pass 3: Radiant Neon Halo (9 pt)
                context.setLineWidth(widths.halo / CGFloat(zoomScale))
                context.setStrokeColor(style.strokeColor.withAlphaComponent(0.48).cgColor)
                context.addPath(drawStrokePath)
                context.strokePath()
                
                // Pass 4: Inner Vibrant Radiance (4.8 pt)
                context.setLineWidth(widths.outer / CGFloat(zoomScale))
                context.setStrokeColor(style.strokeColor.withAlphaComponent(0.85).cgColor)
                context.addPath(drawStrokePath)
                context.strokePath()
                
                // Pass 5: Saturated Neon Core (2.4 pt)
                context.setLineWidth(widths.mid / CGFloat(zoomScale))
                context.setStrokeColor(style.strokeColor.withAlphaComponent(1.0).cgColor)
                context.addPath(drawStrokePath)
                context.strokePath()
                
                // Pass 6: Incandescent White-Hot Laser Filament (1.0 pt)
                context.setLineWidth(widths.core / CGFloat(zoomScale))
                context.setStrokeColor(UIColor(white: 1.0, alpha: 0.98).cgColor)
                context.addPath(drawStrokePath)
                context.strokePath()
            } else {
                let outerWidth = widths.outer / CGFloat(zoomScale)
                let midWidth = widths.mid / CGFloat(zoomScale)
                let coreWidth = widths.core / CGFloat(zoomScale)
                
                // Pass 1: Outer soft glow stroke
                context.setLineWidth(outerWidth)
                context.setStrokeColor(style.strokeColor.withAlphaComponent(style.outerStrokeAlpha).cgColor)
                context.addPath(drawStrokePath)
                context.strokePath()
                
                // Pass 2: Middle glow stroke
                context.setLineWidth(midWidth)
                context.setStrokeColor(style.strokeColor.withAlphaComponent(style.midStrokeAlpha).cgColor)
                context.addPath(drawStrokePath)
                context.strokePath()
                
                // Pass 3: Core crisp stroke
                context.setLineWidth(coreWidth)
                context.setStrokeColor(style.strokeColor.withAlphaComponent(style.coreStrokeAlpha).cgColor)
                context.addPath(drawStrokePath)
                context.strokePath()
            }
        }
        
        context.restoreGState()
    }
}

/// Custom overlay renderer for MultiPolygons with country boundary highlight, graduated pure-vector glow, and cached paths
public class GlowingMultiPolygonRenderer: MKMultiPolygonRenderer {
    public override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        if let countryOverlay = self.overlay as? CountryOverlay,
           let cache = countryOverlay.renderCache {
            return CountryOverlayDrawing.canDraw(cache: cache, mapRect: mapRect, zoomScale: zoomScale)
        }
        return super.canDraw(mapRect, zoomScale: zoomScale)
    }
    
    public override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        if let countryOverlay = self.overlay as? CountryOverlay,
           let cache = countryOverlay.renderCache {
            CountryOverlayDrawing.draw(cache: cache, mapRect: mapRect, zoomScale: zoomScale, in: context)
        }
    }
}

/// Custom overlay renderer for single Polygons with country boundary highlight, graduated pure-vector glow, and cached paths
public class GlowingPolygonRenderer: MKPolygonRenderer {
    public override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        if let countryOverlay = self.overlay as? CountryOverlay,
           let cache = countryOverlay.renderCache {
            return CountryOverlayDrawing.canDraw(cache: cache, mapRect: mapRect, zoomScale: zoomScale)
        }
        return super.canDraw(mapRect, zoomScale: zoomScale)
    }
    
    public override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        if let countryOverlay = self.overlay as? CountryOverlay,
           let cache = countryOverlay.renderCache {
            CountryOverlayDrawing.draw(cache: cache, mapRect: mapRect, zoomScale: zoomScale, in: context)
        }
    }
}
