//
//  NativeFlagExplorerView.swift
//  flag_explorer
//
//  Created for Flag Explorer - Complete Native SwiftUI Interface with Liquid Glass Card & Controls
//

import SwiftUI
import CoreLocation

public struct NativePresetLocation: Identifiable {
    public let id = UUID()
    public let name: String
    public let flag: String
    public let isoA3: String
    public let coordinate: CLLocationCoordinate2D
    public let distance: Double
    
    public init(name: String, flag: String, isoA3: String, coordinate: CLLocationCoordinate2D, distance: Double = 18_000_000) {
        self.name = name
        self.flag = flag
        self.isoA3 = isoA3
        self.coordinate = coordinate
        self.distance = distance
    }
}

public struct NativeFlagExplorerView: View {
    @ObservedObject public var viewModel: GlobeViewModel
    
    private let defaultPresets: [NativePresetLocation] = [
        NativePresetLocation(name: "Vietnam", flag: "🇻🇳", isoA3: "VNM", coordinate: CLLocationCoordinate2D(latitude: 14.0583, longitude: 108.2772), distance: 8_000_000),
        NativePresetLocation(name: "USA", flag: "🇺🇸", isoA3: "USA", coordinate: CLLocationCoordinate2D(latitude: 37.0902, longitude: -95.7129), distance: 18_000_000),
        NativePresetLocation(name: "Japan", flag: "🇯🇵", isoA3: "JPN", coordinate: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529), distance: 8_000_000),
        NativePresetLocation(name: "France", flag: "🇫🇷", isoA3: "FRA", coordinate: CLLocationCoordinate2D(latitude: 46.2276, longitude: 2.2137), distance: 7_500_000),
        NativePresetLocation(name: "UK", flag: "🇬🇧", isoA3: "GBR", coordinate: CLLocationCoordinate2D(latitude: 52.3555, longitude: -1.1743), distance: 7_500_000),
        NativePresetLocation(name: "Australia", flag: "🇦🇺", isoA3: "AUS", coordinate: CLLocationCoordinate2D(latitude: -25.2744, longitude: 133.7751), distance: 14_000_000),
        NativePresetLocation(name: "Brazil", flag: "🇧🇷", isoA3: "BRA", coordinate: CLLocationCoordinate2D(latitude: -14.2350, longitude: -51.9253), distance: 16_000_000),
        NativePresetLocation(name: "Ocean", flag: "🌊", isoA3: "", coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 170.0), distance: 28_000_000)
    ]
    
    private var activePresets: [NativePresetLocation] {
        viewModel.customPresets ?? defaultPresets
    }
    
    public init(viewModel: GlobeViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ZStack {
            // 1. 3D Globe with GeoJSON Country Overlay
            NativeGlobeMapView(viewModel: viewModel)
                .ignoresSafeArea()
            
            // 2. Fixed Center Indicator Crosshair
            if viewModel.showCenterCrosshair {
                NativeCenterCrosshairView(color: viewModel.crosshairColor, size: viewModel.crosshairSize)
                    .allowsHitTesting(false)
            }
            
            // 3. Top Header Bar (Reset Button)
            if viewModel.showResetButton {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.targetCameraCoordinate = CLLocationCoordinate2D(latitude: 37.982941, longitude: -98.701740)
                            viewModel.targetCameraDistance = 18_000_000
                            viewModel.commandTrigger += 1
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.8).allowsHitTesting(false))
                                .contentShape(Circle())
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 50)
                    }
                    Spacer()
                }
            }
            
            // 4. Floating Bottom Preset Controls & Country Card
            VStack(spacing: 12) {
                Spacer()
                
                // Horizontal Preset Chips
                if viewModel.showPresetControls {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(activePresets) { preset in
                                let isSelected = viewModel.detectedCountry?.isoA3 == preset.isoA3
                                Button(action: {
                                    viewModel.targetCameraCoordinate = preset.coordinate
                                    viewModel.targetCameraDistance = preset.distance
                                    viewModel.commandTrigger += 1
                                    viewModel.triggerHapticFeedback()
                                    viewModel.onPresetSelected?(preset.name)
                                }) {
                                    HStack(spacing: 6) {
                                        Text(preset.flag)
                                            .font(.system(size: 14))
                                        Text(preset.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color.white)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        isSelected
                                            ? Color.red.opacity(0.40)
                                            : Color.black.opacity(0.65)
                                    )
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(
                                            isSelected ? Color.red : Color.white.opacity(0.25),
                                            lineWidth: isSelected ? 1.5 : 0.8
                                        )
                                        .allowsHitTesting(false)
                                    )
                                    .contentShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .contentShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                
                // Floating Country Card
                if viewModel.showCountryCard {
                    countryInfoCard
                        .padding(.bottom, viewModel.cardBottomPadding)
                }
            }
        }
    }
    
    // MARK: - Country Information Card (Native Apple Glass iOS 26+ / Liquid Glass Fallback)
    @ViewBuilder
    private var countryInfoCard: some View {
        let cardContent = VStack(spacing: 5) {
            // Country Name
            Text(viewModel.detectedCountry != nil ? displayName(for: viewModel.detectedCountry!) : "Ocean / International")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
            
            // Coordinates
            Text(formattedCoordinates)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
                .shadow(color: Color.black.opacity(0.45), radius: 2, x: 0, y: 1)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .padding(.bottom, 2)
            
            // Flag Image Frame
            if let country = viewModel.detectedCountry {
                ZStack {
                    Text(country.flagEmoji)
                        .font(.system(size: 72))
                    
                    if let url = country.flagURL {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                            }
                        }
                    }
                    
                    // Specular sheen
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.white.opacity(0.08),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .allowsHitTesting(false)
                }
                .frame(width: 228, height: 138)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.75), Color.white.opacity(0.30)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                )
                .shadow(color: Color.black.opacity(0.20), radius: 6, x: 0, y: 3)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.7), Color.cyan.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    VStack(spacing: 4) {
                        Image(systemName: "water.waves")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundStyle(.white)
                        Text("International Waters")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .frame(width: 228, height: 138)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.75), Color.white.opacity(0.30)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                )
                .shadow(color: Color.black.opacity(0.20), radius: 6, x: 0, y: 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 13)
        .padding(.bottom, 16)
        
        // Native Apple Liquid Glass on iOS 26.0+ with graceful fallback for iOS < 26.0
        if #available(iOS 26.0, *) {
            cardContent.glassEffect(
                .clear,
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
        } else {
            cardContent
                .background(LiquidGlassBackground(cornerRadius: 24))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)
                .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 2)
        }
    }
    
    private func displayName(for country: CountryFeature) -> String {
        switch country.isoA3 {
        case "USA": return "United States"
        case "GBR": return "United Kingdom"
        default: return country.name
        }
    }
    
    private var formattedCoordinates: String {
        let latStr = String(format: "%.6f", abs(viewModel.centerCoordinate.latitude)).replacingOccurrences(of: ".", with: ",")
        let lonStr = String(format: "%.5f", abs(viewModel.centerCoordinate.longitude)).replacingOccurrences(of: ".", with: ",")
        return "\(latStr) - \(lonStr)"
    }
}

// MARK: - Native Center Crosshair Indicator
public struct NativeCenterCrosshairView: View {
    public var color: Color = .white
    public var size: CGFloat = 56
    
    public init(color: Color = .white, size: CGFloat = 56) {
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let s = min(w, h) / 60.0
            
            let strokeWidth: CGFloat = 4.6875 * s
            let halfStroke: CGFloat = strokeWidth / 2.0
            let circleRadius: CGFloat = 4.6875 * s
            let cornerRadius: CGFloat = 4.6875 * s
            let cx = w / 2.0
            let cy = h / 2.0
            
            let armExtent: CGFloat = 10.45 * s
            let cornerArmH: CGFloat = 14.18 * s
            let cornerArmV: CGFloat = 13.95 * s
            
            var path = Path()
            
            // 1. Center Circle Ring
            path.addEllipse(in: CGRect(x: cx - circleRadius, y: cy - circleRadius, width: circleRadius * 2, height: circleRadius * 2))
            
            // 2. Cross Arms (Top, Bottom, Left, Right)
            // Top
            path.move(to: CGPoint(x: cx, y: cy - circleRadius))
            path.addLine(to: CGPoint(x: cx, y: cy - armExtent))
            // Bottom
            path.move(to: CGPoint(x: cx, y: cy + circleRadius))
            path.addLine(to: CGPoint(x: cx, y: cy + armExtent))
            // Left
            path.move(to: CGPoint(x: cx - circleRadius, y: cy))
            path.addLine(to: CGPoint(x: cx - armExtent, y: cy))
            // Right
            path.move(to: CGPoint(x: cx + circleRadius, y: cy))
            path.addLine(to: CGPoint(x: cx + armExtent, y: cy))
            
            // 3. Four Viewfinder Corner Brackets
            // Top-Left
            let tlX = halfStroke
            let tlY = halfStroke
            path.move(to: CGPoint(x: tlX, y: tlY + cornerArmV))
            path.addLine(to: CGPoint(x: tlX, y: tlY + cornerRadius))
            path.addArc(tangent1End: CGPoint(x: tlX, y: tlY), tangent2End: CGPoint(x: tlX + cornerRadius, y: tlY), radius: cornerRadius)
            path.addLine(to: CGPoint(x: tlX + cornerArmH, y: tlY))
            
            // Top-Right
            let trX = w - halfStroke
            let trY = halfStroke
            path.move(to: CGPoint(x: trX - cornerArmH, y: trY))
            path.addLine(to: CGPoint(x: trX - cornerRadius, y: trY))
            path.addArc(tangent1End: CGPoint(x: trX, y: trY), tangent2End: CGPoint(x: trX, y: trY + cornerRadius), radius: cornerRadius)
            path.addLine(to: CGPoint(x: trX, y: trY + cornerArmV))
            
            // Bottom-Left
            let blX = halfStroke
            let blY = h - halfStroke
            path.move(to: CGPoint(x: blX, y: blY - cornerArmV))
            path.addLine(to: CGPoint(x: blX, y: blY - cornerRadius))
            path.addArc(tangent1End: CGPoint(x: blX, y: blY), tangent2End: CGPoint(x: blX + cornerRadius, y: blY), radius: cornerRadius)
            path.addLine(to: CGPoint(x: blX + cornerArmH, y: blY))
            
            // Bottom-Right
            let brX = w - halfStroke
            let brY = h - halfStroke
            path.move(to: CGPoint(x: brX - cornerArmH, y: brY))
            path.addLine(to: CGPoint(x: brX - cornerRadius, y: brY))
            path.addArc(tangent1End: CGPoint(x: brX, y: brY), tangent2End: CGPoint(x: brX, y: brY - cornerRadius), radius: cornerRadius)
            path.addLine(to: CGPoint(x: brX, y: brY - cornerArmV))
            
            // Subtle high-contrast outer shadow for legibility over white satellite clouds & dark oceans
            context.stroke(
                path,
                with: .color(Color.black.opacity(0.35)),
                style: StrokeStyle(lineWidth: strokeWidth + 1.5 * s, lineCap: .round, lineJoin: .round)
            )
            
            // Crisp vector foreground
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
    }
}
