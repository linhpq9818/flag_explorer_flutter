//
//  CountryGeoJSONService.swift
//  flag_explorer
//
//  Created for Flag Explorer - Standalone Local GeoJSON Country Detection
//

import Foundation
import CoreLocation
import MapKit

/// Fast 2D bounding box for initial rejection
public struct GeoBoundingBox {
    public let minLon: Double
    public let minLat: Double
    public let maxLon: Double
    public let maxLat: Double
    
    public func contains(lon: Double, lat: Double) -> Bool {
        return lon >= minLon && lon <= maxLon && lat >= minLat && lat <= maxLat
    }
}

/// A single polygon with outer boundary ring and interior rings (holes)
public struct GeoPolygon {
    public let outerRing: [CLLocationCoordinate2D]
    public let holes: [[CLLocationCoordinate2D]]
    
    public func contains(lon: Double, lat: Double) -> Bool {
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
    
    /// Jordan curve theorem ray-casting algorithm (preserved exact implementation)
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
public struct CountryRenderComponent {
    public let boundingMapRect: MKMapRect
    public let fillPath: CGPath
    public let strokePath: CGPath
    public let maxDimension: Double
}

/// Protocol identifying custom country overlays carrying precomputed render caches
public protocol CountryOverlay: AnyObject {
    var renderCache: CountryRenderCache? { get set }
}

/// MKMultiPolygon subclass with attached CountryRenderCache
public final class CountryMultiPolygon: MKMultiPolygon, CountryOverlay {
    public var renderCache: CountryRenderCache?
}

/// MKPolygon subclass with attached CountryRenderCache
public final class CountryPolygon: MKPolygon, CountryOverlay {
    public var renderCache: CountryRenderCache?
}

/// Immutable precomputed geometry cache for fast, zero-allocation MapKit draw calls
public final class CountryRenderCache {
    public let components: [CountryRenderComponent]
    public let fullFillPath: CGPath
    public let fullStrokePath: CGPath
    public let totalBoundingMapRect: MKMapRect
    public let largestComponentDimension: Double
    
    public init(components: [CountryRenderComponent], fullFillPath: CGPath, fullStrokePath: CGPath, totalRect: MKMapRect, largestDimension: Double) {
        self.components = components
        self.fullFillPath = fullFillPath
        self.fullStrokePath = fullStrokePath
        self.totalBoundingMapRect = totalRect
        self.largestComponentDimension = largestDimension
    }
    
    public static func build(for polygons: [GeoPolygon], overlayOrigin: MKMapPoint) -> CountryRenderCache {
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
            var currentSubpathEmpty = true
            
            for i in 0..<outerRing.count {
                let c1 = outerRing[i]
                let c2 = outerRing[(i + 1) % outerRing.count]
                
                let isAntimeridianCutEdge = (abs(c1.longitude) > 179.9 && abs(c2.longitude) > 179.9) ||
                                            (abs(c1.longitude - c2.longitude) > 180.0)
                
                if !isAntimeridianCutEdge {
                    let mp1 = MKMapPoint(c1)
                    let mp2 = MKMapPoint(c2)
                    let p1 = CGPoint(x: mp1.x - overlayOrigin.x, y: mp1.y - overlayOrigin.y)
                    let p2 = CGPoint(x: mp2.x - overlayOrigin.x, y: mp2.y - overlayOrigin.y)
                    
                    if currentSubpathEmpty {
                        compStrokePath.move(to: p1)
                        currentSubpathEmpty = false
                    }
                    compStrokePath.addLine(to: p2)
                } else {
                    currentSubpathEmpty = true
                }
            }
            
            for hole in poly.holes {
                guard hole.count > 1 else { continue }
                var holeSubpathEmpty = true
                for i in 0..<hole.count {
                    let c1 = hole[i]
                    let c2 = hole[(i + 1) % hole.count]
                    
                    let isAntimeridianCutEdge = (abs(c1.longitude) > 179.9 && abs(c2.longitude) > 179.9) ||
                                                (abs(c1.longitude - c2.longitude) > 180.0)
                    
                    if !isAntimeridianCutEdge {
                        let mp1 = MKMapPoint(c1)
                        let mp2 = MKMapPoint(c2)
                        let p1 = CGPoint(x: mp1.x - overlayOrigin.x, y: mp1.y - overlayOrigin.y)
                        let p2 = CGPoint(x: mp2.x - overlayOrigin.x, y: mp2.y - overlayOrigin.y)
                        
                        if holeSubpathEmpty {
                            compStrokePath.move(to: p1)
                            holeSubpathEmpty = false
                        }
                        compStrokePath.addLine(to: p2)
                    } else {
                        holeSubpathEmpty = true
                    }
                }
            }
            
            components.append(CountryRenderComponent(
                boundingMapRect: compRect,
                fillPath: compFillPath,
                strokePath: compStrokePath,
                maxDimension: compMaxDim
            ))
            
            aggregatedFillPath.addPath(compFillPath)
            aggregatedStrokePath.addPath(compStrokePath)
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
public final class CountryFeature: Identifiable {
    public let id: String // ISO A3 code
    public let name: String
    public let isoA3: String
    public let flagEmoji: String
    public let bbox: GeoBoundingBox
    public let polygons: [GeoPolygon]
    
    // Cached MapKit overlay
    private var _cachedOverlay: MKOverlay?
    
    public var isoA2: String? {
        CountryGeoJSONService.iso2(for: isoA3)
    }
    
    public var flagURL: URL? {
        guard let code = isoA2?.lowercased() else { return nil }
        return URL(string: "https://flagcdn.com/w320/\(code).png")
    }
    
    public init(id: String, name: String, isoA3: String, flagEmoji: String, bbox: GeoBoundingBox, polygons: [GeoPolygon]) {
        self.id = id
        self.name = name
        self.isoA3 = isoA3
        self.flagEmoji = flagEmoji
        self.bbox = bbox
        self.polygons = polygons
    }
    
    public var overlay: MKOverlay {
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
    
    public func contains(coordinate: CLLocationCoordinate2D) -> Bool {
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
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "name": name,
            "isoA3": isoA3,
            "flagEmoji": flagEmoji,
            "centerLat": (bbox.minLat + bbox.maxLat) / 2.0,
            "centerLng": (bbox.minLon + bbox.maxLon) / 2.0
        ]
        if let a2 = isoA2 {
            dict["isoA2"] = a2
        }
        if let url = flagURL?.absoluteString {
            dict["flagUrl"] = url
        }
        return dict
    }
}

/// Service that parses countries.geojson and performs fast point-in-polygon country detection
public final class CountryGeoJSONService {
    public static let shared = CountryGeoJSONService()
    
    public private(set) var countries: [CountryFeature] = []
    public private(set) var isLoaded: Bool = false
    public private(set) var loadError: String?
    private let loadQueue = DispatchQueue(label: "com.flag_explorer.geojson_loader", qos: .userInitiated)
    
    private init() {
        loadGeoJSON()
    }
    
    /// Resolve bundle resource URL across SPM, CocoaPods resource bundle, framework, and main bundle
    public static func resolveCountriesGeoJSONURL() -> URL? {
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "countries", withExtension: "geojson") {
            return url
        }
        #endif
        
        let bundle = Bundle(for: CountryGeoJSONService.self)
        
        // CocoaPods resource bundle named 'flag_explorer_resources'
        if let resourceBundleURL = bundle.url(forResource: "flag_explorer_resources", withExtension: "bundle"),
           let resourceBundle = Bundle(url: resourceBundleURL),
           let url = resourceBundle.url(forResource: "countries", withExtension: "geojson") {
            return url
        }
        
        // Directly inside plugin bundle
        if let url = bundle.url(forResource: "countries", withExtension: "geojson") {
            return url
        }
        
        // Inside any nested bundle
        if let subBundles = bundle.urls(forResourcesWithExtension: "bundle", subdirectory: nil) {
            for subURL in subBundles {
                if let b = Bundle(url: subURL), let url = b.url(forResource: "countries", withExtension: "geojson") {
                    return url
                }
            }
        }
        
        // Fallback to host main bundle
        if let url = Bundle.main.url(forResource: "countries", withExtension: "geojson") {
            return url
        }
        
        return nil
    }
    
    public func loadGeoJSON() {
        loadQueue.sync {
            guard !isLoaded else { return }
            
            guard let url = Self.resolveCountriesGeoJSONURL() else {
                let errorMsg = "countries.geojson not found in plugin bundle or main bundle"
                print("⚠️ [CountryGeoJSONService] \(errorMsg)")
                self.loadError = errorMsg
                return
            }
            
            do {
                let data = try Data(contentsOf: url)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let features = json["features"] as? [[String: Any]] else {
                    let errorMsg = "Invalid GeoJSON structure in \(url.lastPathComponent)"
                    print("⚠️ [CountryGeoJSONService] \(errorMsg)")
                    self.loadError = errorMsg
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
                self.loadError = nil
                print("✅ [CountryGeoJSONService] Successfully loaded \(parsed.count) countries from \(url.path)")
            } catch {
                let errorMsg = "Failed to load GeoJSON: \(error.localizedDescription)"
                print("❌ [CountryGeoJSONService] \(errorMsg)")
                self.loadError = errorMsg
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
    public func findCountry(at coordinate: CLLocationCoordinate2D) -> CountryFeature? {
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
    
    /// Look up a country by ISO A3 code
    public func country(forIsoA3 iso: String) -> CountryFeature? {
        let upper = iso.uppercased().trimmingCharacters(in: .whitespaces)
        return countries.first { $0.isoA3 == upper }
    }
    
    // MARK: - Flag Emoji & ISO Resolution
    public static func iso2(for isoA3: String) -> String? {
        iso3ToIso2Map[isoA3]
    }
    
    public static func flagEmoji(for isoA3: String) -> String {
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
        "JEY": "JE", "JOR": "JO", "JPN": "JP", "KAB": "KZ", "KAS": "IN", "KAZ": "KZ",
        "KEN": "KE", "KGZ": "KG", "KHM": "KH", "KIR": "KI", "KNA": "KN", "KOR": "KR",
        "KOS": "XK", "KWT": "KW", "LAO": "LA", "LBN": "LB", "LBR": "LR", "LBY": "LY",
        "LCA": "LC", "LIE": "LI", "LKA": "LK", "LSO": "LS", "LTU": "LT", "LUX": "LU",
        "LVA": "LV", "MAC": "MO", "MAF": "MF", "MAR": "MA", "MCO": "MC", "MDA": "MD",
        "MDG": "MG", "MDV": "MV", "MEX": "MX", "MHL": "MH", "MKD": "MK", "MLI": "ML",
        "MLT": "MT", "MMR": "MM", "MNE": "ME", "MNG": "MN", "MNP": "MP", "MOZ": "MZ",
        "MRT": "MR", "MSR": "MS", "MUS": "MU", "MWI": "MW", "MYS": "MY", "NAM": "NA",
        "NCL": "NC", "NER": "NE", "NFK": "NF", "NGA": "NG", "NIC": "NI", "NIU": "NU",
        "NLD": "NL", "NOR": "NO", "NPL": "NP", "NRU": "NR", "NZL": "NZ", "OMN": "OM",
        "PAK": "PK", "PAN": "PA", "PCN": "PN", "PER": "PE", "PHL": "PH", "PLW": "PW",
        "PNG": "PG", "POL": "PL", "PRI": "PR", "PRK": "KP", "PRT": "PT", "PRY": "PY",
        "PSE": "PS", "PYF": "PF", "QAT": "QA", "ROU": "RO", "RUS": "RU", "RWA": "RW",
        "SAH": "EH", "SAU": "SA", "SDN": "SD", "SDS": "SS", "SEN": "SN", "SGP": "SG",
        "SGS": "GS", "SHN": "SH", "SLB": "SB", "SLE": "SL", "SLV": "SV", "SMR": "SM",
        "SOL": "SO", "SOM": "SO", "SPM": "PM", "SRB": "RS", "STP": "ST", "SUR": "SR",
        "SVK": "SK", "SVN": "SI", "SWE": "SE", "SWZ": "SZ", "SXM": "SX", "SYC": "SC",
        "SYR": "SY", "TCA": "TC", "TCD": "TD", "TGO": "TG", "THA": "TH", "TJK": "TJ",
        "TKM": "TM", "TLS": "TL", "TON": "TO", "TTO": "TT", "TUN": "TN", "TUR": "TR",
        "TUV": "TV", "TWN": "TW", "TZA": "TZ", "UGA": "UG", "UKR": "UA", "URY": "UY",
        "USA": "US", "UZB": "UZ", "VAT": "VA", "VCT": "VC", "VEN": "VE", "VGB": "VG",
        "VIR": "VI", "VNM": "VN", "VUT": "VU", "WLF": "WF", "WSM": "WS", "YEM": "YE",
        "ZAF": "ZA", "ZMB": "ZM", "ZWE": "ZW"
    ]
}
