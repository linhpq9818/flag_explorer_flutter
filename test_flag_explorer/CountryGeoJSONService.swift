//
//  CountryGeoJSONService.swift
//  test_flag_explorer
//
//  Created for Flag Explorer - Standalone Local GeoJSON Country Detection
//

import Foundation
import CoreLocation
import MapKit

/// Fast 2D bounding box for initial rejection
struct GeoBoundingBox {
    let minLon: Double
    let minLat: Double
    let maxLon: Double
    let maxLat: Double
    
    func contains(lon: Double, lat: Double) -> Bool {
        return lon >= minLon && lon <= maxLon && lat >= minLat && lat <= maxLat
    }
}

/// A single polygon with outer boundary ring and interior rings (holes)
struct GeoPolygon {
    let outerRing: [CLLocationCoordinate2D]
    let holes: [[CLLocationCoordinate2D]]
    
    func contains(lon: Double, lat: Double) -> Bool {
        guard ringContains(lon: lon, lat: lat, ring: outerRing) else {
            return false
        }
        for hole in holes {
            if ringContains(lon: lon, lat: lat, ring: hole) {
                return false
            }
        }
        return true
    }
    
    /// Jordan curve theorem ray-casting algorithm
    private func ringContains(lon: Double, lat: Double, ring: [CLLocationCoordinate2D]) -> Bool {
        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let xi = ring[i].longitude
            let yi = ring[i].latitude
            let xj = ring[j].longitude
            let yj = ring[j].latitude
            
            let intersect = ((yi > lat) != (yj > lat)) &&
                (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi)
            if intersect {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}

// MARK: - Render Cache & Custom Overlays

/// Cached render representation of a single polygon component
struct CountryRenderComponent {
    let boundingMapRect: MKMapRect
    let fillPath: CGPath
    let strokePath: CGPath
    let maxDimension: Double
}

/// Protocol identifying custom country overlays carrying precomputed render caches
protocol CountryOverlay: AnyObject {
    var renderCache: CountryRenderCache? { get set }
}

/// MKMultiPolygon subclass with attached CountryRenderCache
final class CountryMultiPolygon: MKMultiPolygon, CountryOverlay {
    var renderCache: CountryRenderCache?
}

/// MKPolygon subclass with attached CountryRenderCache
final class CountryPolygon: MKPolygon, CountryOverlay {
    var renderCache: CountryRenderCache?
}

/// Immutable precomputed geometry cache for fast, zero-allocation MapKit draw calls
final class CountryRenderCache {
    let components: [CountryRenderComponent]
    let fullFillPath: CGPath
    let fullStrokePath: CGPath
    let totalBoundingMapRect: MKMapRect
    let largestComponentDimension: Double
    
    init(components: [CountryRenderComponent], fullFillPath: CGPath, fullStrokePath: CGPath, totalRect: MKMapRect, largestDimension: Double) {
        self.components = components
        self.fullFillPath = fullFillPath
        self.fullStrokePath = fullStrokePath
        self.totalBoundingMapRect = totalRect
        self.largestComponentDimension = largestDimension
    }
    
    static func build(for polygons: [GeoPolygon], overlayOrigin: MKMapPoint) -> CountryRenderCache {
        var components: [CountryRenderComponent] = []
        var totalRect = MKMapRect.null
        let aggregatedFillPath = CGMutablePath()
        let aggregatedStrokePath = CGMutablePath()
        var maxComponentDimension: Double = 0.0
        
        for poly in polygons {
            let outerRing = poly.outerRing
            guard outerRing.count > 1 else { continue }
            
            // 1. Calculate component bounding map rect
            var compRect = MKMapRect.null
            for coord in outerRing {
                let mp = MKMapPoint(coord)
                compRect = compRect.union(MKMapRect(origin: mp, size: MKMapSize(width: 0, height: 0)))
            }
            totalRect = totalRect.union(compRect)
            
            let compMaxDim = max(compRect.size.width, compRect.size.height)
            if compMaxDim > maxComponentDimension {
                maxComponentDimension = compMaxDim
            }
            
            // 2. Build Fill Path (closed outer ring + closed holes, keeping seams closed for proper fill coverage)
            let compFillPath = CGMutablePath()
            let p0 = MKMapPoint(outerRing[0])
            compFillPath.move(to: CGPoint(x: p0.x - overlayOrigin.x, y: p0.y - overlayOrigin.y))
            for coord in outerRing.dropFirst() {
                let mp = MKMapPoint(coord)
                compFillPath.addLine(to: CGPoint(x: mp.x - overlayOrigin.x, y: mp.y - overlayOrigin.y))
            }
            compFillPath.closeSubpath()
            
            for hole in poly.holes {
                guard let h0 = hole.first, hole.count > 1 else { continue }
                let mp0 = MKMapPoint(h0)
                compFillPath.move(to: CGPoint(x: mp0.x - overlayOrigin.x, y: mp0.y - overlayOrigin.y))
                for coord in hole.dropFirst() {
                    let mp = MKMapPoint(coord)
                    compFillPath.addLine(to: CGPoint(x: mp.x - overlayOrigin.x, y: mp.y - overlayOrigin.y))
                }
                compFillPath.closeSubpath()
            }
            
            // 3. Build Stroke Path (suppressing artificial GIS antimeridian cut edges along ±180° longitude)
            let compStrokePath = CGMutablePath()
            
            func appendStroke(for ring: [CLLocationCoordinate2D]) {
                guard ring.count > 1 else { return }
                var isDrawing = false
                var hadSeam = false
                
                for i in 0..<(ring.count - 1) {
                    let c1 = ring[i]
                    let c2 = ring[i + 1]
                    
                    let isSeam = abs(abs(c1.longitude) - 180.0) < 0.001 && abs(abs(c2.longitude) - 180.0) < 0.001
                    if isSeam {
                        // Lift pen over artificial antimeridian split seam
                        isDrawing = false
                        hadSeam = true
                    } else {
                        let mp1 = MKMapPoint(c1)
                        let mp2 = MKMapPoint(c2)
                        let pt1 = CGPoint(x: mp1.x - overlayOrigin.x, y: mp1.y - overlayOrigin.y)
                        let pt2 = CGPoint(x: mp2.x - overlayOrigin.x, y: mp2.y - overlayOrigin.y)
                        
                        if !isDrawing {
                            compStrokePath.move(to: pt1)
                            isDrawing = true
                        }
                        compStrokePath.addLine(to: pt2)
                    }
                }
                
                // If there were no artificial seam cuts, properly close the subpath
                if !hadSeam {
                    compStrokePath.closeSubpath()
                }
            }
            
            appendStroke(for: outerRing)
            for hole in poly.holes {
                appendStroke(for: hole)
            }
            
            aggregatedFillPath.addPath(compFillPath)
            aggregatedStrokePath.addPath(compStrokePath)
            
            components.append(CountryRenderComponent(
                boundingMapRect: compRect,
                fillPath: compFillPath,
                strokePath: compStrokePath,
                maxDimension: compMaxDim
            ))
        }
        
        return CountryRenderCache(
            components: components,
            fullFillPath: aggregatedFillPath,
            fullStrokePath: aggregatedStrokePath,
            totalRect: totalRect,
            largestDimension: maxComponentDimension
        )
    }
}

/// Representation of a parsed Country from Natural Earth 50m GeoJSON
final class CountryFeature: Identifiable {
    let id: String // ISO A3 code
    let name: String
    let isoA3: String
    let flagEmoji: String
    let bbox: GeoBoundingBox
    let polygons: [GeoPolygon]
    
    // Cached MapKit overlay
    private var _cachedOverlay: MKOverlay?
    
    var isoA2: String? {
        CountryGeoJSONService.iso2(for: isoA3)
    }
    
    var flagURL: URL? {
        guard let code = isoA2?.lowercased() else { return nil }
        return URL(string: "https://flagcdn.com/w320/\(code).png")
    }
    
    init(id: String, name: String, isoA3: String, flagEmoji: String, bbox: GeoBoundingBox, polygons: [GeoPolygon]) {
        self.id = id
        self.name = name
        self.isoA3 = isoA3
        self.flagEmoji = flagEmoji
        self.bbox = bbox
        self.polygons = polygons
    }
    
    var overlay: MKOverlay {
        if let cached = _cachedOverlay {
            return cached
        }
        
        var mkPolygons: [MKPolygon] = []
        for poly in polygons {
            let outer = poly.outerRing
            let holes = poly.holes.map { hole in
                MKPolygon(coordinates: hole, count: hole.count)
            }
            let mkPoly = MKPolygon(coordinates: outer, count: outer.count, interiorPolygons: holes.isEmpty ? nil : holes)
            mkPolygons.append(mkPoly)
        }
        
        let result: MKOverlay
        if mkPolygons.count == 1 {
            let poly = polygons[0]
            let singlePoly = CountryPolygon(
                coordinates: poly.outerRing,
                count: poly.outerRing.count,
                interiorPolygons: mkPolygons[0].interiorPolygons
            )
            singlePoly.renderCache = CountryRenderCache.build(for: [poly], overlayOrigin: singlePoly.boundingMapRect.origin)
            result = singlePoly
        } else {
            let multiPoly = CountryMultiPolygon(mkPolygons)
            multiPoly.renderCache = CountryRenderCache.build(for: polygons, overlayOrigin: multiPoly.boundingMapRect.origin)
            result = multiPoly
        }
        _cachedOverlay = result
        return result
    }
    
    func contains(coordinate: CLLocationCoordinate2D) -> Bool {
        let lon = coordinate.longitude
        let lat = coordinate.latitude
        
        guard bbox.contains(lon: lon, lat: lat) else {
            return false
        }
        
        for poly in polygons {
            if poly.contains(lon: lon, lat: lat) {
                return true
            }
        }
        return false
    }
}

/// Service that parses countries.geojson and performs fast point-in-polygon country detection
final class CountryGeoJSONService {
    static let shared = CountryGeoJSONService()
    
    private(set) var countries: [CountryFeature] = []
    private(set) var isLoaded: Bool = false
    private let loadQueue = DispatchQueue(label: "com.flag_explorer.geojson_loader", qos: .userInitiated)
    
    private init() {
        loadGeoJSON()
    }
    
    func loadGeoJSON() {
        loadQueue.sync {
            guard !isLoaded else { return }
            
            guard let url = Bundle.main.url(forResource: "countries", withExtension: "geojson") ??
                    Bundle.main.url(forResource: "countries", withExtension: "geojson", subdirectory: "test_flag_explorer") else {
                print("⚠️ [CountryGeoJSONService] countries.geojson not found in bundle!")
                return
            }
            
            do {
                let data = try Data(contentsOf: url)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let features = json["features"] as? [[String: Any]] else {
                    print("⚠️ [CountryGeoJSONService] Invalid GeoJSON structure.")
                    return
                }
                
                var parsed: [CountryFeature] = []
                for feat in features {
                    guard let props = feat["properties"] as? [String: Any],
                          let name = props["name"] as? String,
                          let iso = props["iso_a3"] as? String,
                          let bboxArr = feat["bbox"] as? [Double], bboxArr.count >= 4,
                          let geom = feat["geometry"] as? [String: Any],
                          let geomType = geom["type"] as? String else {
                        continue
                    }
                    
                    let bbox = GeoBoundingBox(
                        minLon: bboxArr[0],
                        minLat: bboxArr[1],
                        maxLon: bboxArr[2],
                        maxLat: bboxArr[3]
                    )
                    
                    var polygons: [GeoPolygon] = []
                    
                    if geomType == "Polygon", let coords = geom["coordinates"] as? [[[Double]]] {
                        if let poly = parsePolygonCoords(coords) {
                            polygons.append(poly)
                        }
                    } else if geomType == "MultiPolygon", let coords = geom["coordinates"] as? [[[[Double]]]] {
                        for polyCoords in coords {
                            if let poly = parsePolygonCoords(polyCoords) {
                                polygons.append(poly)
                            }
                        }
                    }
                    
                    if !polygons.isEmpty {
                        let flag = Self.flagEmoji(for: iso)
                        let country = CountryFeature(
                            id: iso,
                            name: name,
                            isoA3: iso,
                            flagEmoji: flag,
                            bbox: bbox,
                            polygons: polygons
                        )
                        parsed.append(country)
                    }
                }
                
                self.countries = parsed
                self.isLoaded = true
                print("✅ [CountryGeoJSONService] Loaded \(parsed.count) countries successfully.")
            } catch {
                print("❌ [CountryGeoJSONService] Failed to load GeoJSON: \(error)")
            }
        }
    }
    
    private func parsePolygonCoords(_ coords: [[[Double]]]) -> GeoPolygon? {
        guard let outerCoords = coords.first, !outerCoords.isEmpty else { return nil }
        
        let outerRing = outerCoords.map { coord in
            CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
        }
        
        var holes: [[CLLocationCoordinate2D]] = []
        for holeCoords in coords.dropFirst() {
            let holeRing = holeCoords.map { coord in
                CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
            }
            holes.append(holeRing)
        }
        
        return GeoPolygon(outerRing: outerRing, holes: holes)
    }
    
    /// Detect which country contains the given coordinate.
    func findCountry(at coordinate: CLLocationCoordinate2D) -> CountryFeature? {
        let lon = coordinate.longitude
        let lat = coordinate.latitude
        
        // Fast range check
        guard lon >= -180.0 && lon <= 180.0 && lat >= -90.0 && lat <= 90.0 else {
            return nil
        }
        
        for country in countries {
            if country.contains(coordinate: coordinate) {
                return country
            }
        }
        
        return nil
    }
    
    // MARK: - Flag Emoji & ISO Resolution
    static func iso2(for isoA3: String) -> String? {
        iso3ToIso2Map[isoA3]
    }
    
    static func flagEmoji(for isoA3: String) -> String {
        guard let isoA2 = iso3ToIso2Map[isoA3] else {
            return "🏳️"
        }
        let base: UInt32 = 127397
        var flag = ""
        for scalar in isoA2.uppercased().unicodeScalars {
            if let emojiScalar = UnicodeScalar(base + scalar.value) {
                flag.unicodeScalars.append(emojiScalar)
            }
        }
        return flag.isEmpty ? "🏳️" : flag
    }
    
    private static let iso3ToIso2Map: [String: String] = [
        "ABW": "AW", "AFG": "AF", "AGO": "AO", "AIA": "AI", "ALA": "AX", "ALB": "AL",
        "AND": "AD", "ARE": "AE", "ARG": "AR", "ARM": "AM", "ASM": "AS", "ATA": "AQ",
        "ATC": "AU", "ATF": "TF", "ATG": "AG", "AUS": "AU", "AUT": "AT", "AZE": "AZ",
        "BDI": "BI", "BEL": "BE", "BEN": "BJ", "BFA": "BF", "BGD": "BD", "BGR": "BG",
        "BHR": "BH", "BHS": "BS", "BIH": "BA", "BLM": "BL", "BLR": "BY", "BLZ": "BZ",
        "BMU": "BM", "BOL": "BO", "BRA": "BR", "BRB": "BB", "BRN": "BN", "BTN": "BT",
        "BWA": "BW", "CAF": "CF", "CAN": "CA", "CHE": "CH", "CHL": "CL", "CHN": "CN",
        "CIV": "CI", "CMR": "CM", "COD": "CD", "COG": "CG", "COK": "CK", "COL": "CO",
        "COM": "KM", "CPV": "CV", "CRI": "CR", "CUB": "CU", "CUW": "CW", "CYM": "KY",
        "CYN": "CY", "CYP": "CY", "CZE": "CZ", "DEU": "DE", "DJI": "DJ", "DMA": "DM",
        "DNK": "DK", "DOM": "DO", "DZA": "DZ", "ECU": "EC", "EGY": "EG", "ERI": "ER",
        "ESP": "ES", "EST": "EE", "ETH": "ET", "FIN": "FI", "FJI": "FJ", "FLK": "FK",
        "FRA": "FR", "FRO": "FO", "FSM": "FM", "GAB": "GA", "GBR": "GB", "GEO": "GE",
        "GGY": "GG", "GHA": "GH", "GIB": "GI", "GIN": "GN", "GMB": "GM", "GNB": "GW",
        "GNQ": "GQ", "GRC": "GR", "GRD": "GD", "GRL": "GL", "GTM": "GT", "GUM": "GU",
        "GUY": "GY", "HKG": "HK", "HND": "HN", "HRV": "HR", "HTI": "HT", "HUN": "HU",
        "IDN": "ID", "IMN": "IM", "IND": "IN", "IOA": "IO", "IOT": "IO", "IRL": "IE",
        "IRN": "IR", "IRQ": "IQ", "ISL": "IS", "ISR": "IL", "ITA": "IT", "JAM": "JM",
        "JEY": "JE", "JOR": "JO", "JPN": "JP", "KAS": "IN", "KAZ": "KZ", "KEN": "KE",
        "KGZ": "KG", "KHM": "KH", "KIR": "KI", "KNA": "KN", "KOR": "KR", "KOS": "XK",
        "KWT": "KW", "LAO": "LA", "LBN": "LB", "LBR": "LR", "LBY": "LY", "LCA": "LC",
        "LIE": "LI", "LKA": "LK", "LSO": "LS", "LTU": "LT", "LUX": "LU", "LVA": "LV",
        "MAC": "MO", "MAF": "MF", "MAR": "MA", "MCO": "MC", "MDA": "MD", "MDG": "MG",
        "MDV": "MV", "MEX": "MX", "MHL": "MH", "MKD": "MK", "MLI": "ML", "MLT": "MT",
        "MMR": "MM", "MNE": "ME", "MNG": "MN", "MNP": "MP", "MOZ": "MZ", "MRT": "MR",
        "MSR": "MS", "MUS": "MU", "MWI": "MW", "MYS": "MY", "NAM": "NA", "NCL": "NC",
        "NER": "NE", "NFK": "NF", "NGA": "NG", "NIC": "NI", "NIU": "NU", "NLD": "NL",
        "NOR": "NO", "NPL": "NP", "NRU": "NR", "NZL": "NZ", "OMN": "OM", "PAK": "PK",
        "PAN": "PA", "PCN": "PN", "PER": "PE", "PHL": "PH", "PLW": "PW", "PNG": "PG",
        "POL": "PL", "PRI": "PR", "PRK": "KP", "PRT": "PT", "PRY": "PY", "PSE": "PS",
        "PYF": "PF", "QAT": "QA", "ROU": "RO", "RUS": "RU", "RWA": "RW", "SAU": "SA",
        "SDN": "SD", "SEN": "SN", "SGP": "SG", "SGS": "GS", "SHN": "SH", "SLB": "SB",
        "SLE": "SL", "SLV": "SV", "SMR": "SM", "SOL": "SO", "SOM": "SO", "SPM": "PM",
        "SRB": "RS", "SSD": "SS", "STP": "ST", "SUR": "SR", "SVK": "SK", "SVN": "SI",
        "SWE": "SE", "SWZ": "SZ", "SXM": "SX", "SYC": "SC", "SYR": "SY", "TCA": "TC",
        "TCD": "TD", "TGO": "TG", "THA": "TH", "TJK": "TJ", "TKM": "TM", "TLS": "TL",
        "TON": "TO", "TTO": "TT", "TUN": "TN", "TUR": "TR", "TUV": "TV", "TWN": "TW",
        "TZA": "TZ", "UGA": "UG", "UKR": "UA", "UMI": "UM", "URY": "UY", "USA": "US",
        "UZB": "UZ", "VAT": "VA", "VCT": "VC", "VEN": "VE", "VGB": "VG", "VIR": "VI",
        "VNM": "VN", "VUT": "VU", "WLF": "WF", "WSM": "WS", "YEM": "YE", "ZAF": "ZA",
        "ZMB": "ZM", "ZWE": "ZW"
    ]
}
