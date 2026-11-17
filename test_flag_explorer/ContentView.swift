//
//  ContentView.swift
//  test_flag_explorer
//
//  Created for Flag Explorer - Standalone GeoJSON 3D Globe Explorer
//

import SwiftUI
import MapKit

struct ContentView: View {
    @State private var centerCoordinate = CLLocationCoordinate2D(latitude: 37.982941, longitude: -98.701740) // Default to USA (matches mockup)
    @State private var detectedCountry: CountryFeature?
    
    var body: some View {
        ZStack {
            // 1. 3D Globe with GeoJSON Country Overlay
            GlobeMapView(
                centerCoordinate: $centerCoordinate,
                detectedCountry: $detectedCountry
            )
            .ignoresSafeArea()
            
            // 2. Fixed Center Indicator (Crosshair icon from Asset)
            CenterIndicatorView()
            
            // 3. Floating Bottom Country Information Card (Mockup Design)
            VStack {
                Spacer()
                countryInfoCard
                    .padding(.bottom, 38)
            }
        }
    }
    
    // MARK: - Country Information Card (Liquid Glass Design)
    @ViewBuilder
    private var countryInfoCard: some View {
        let cardContent = VStack(spacing: 5) {
            // 1. Country Name (Dark charcoal text as in mockup)
            Text(detectedCountry != nil ? displayName(for: detectedCountry!) : "Ocean")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
            
            // 2. Coordinates (Crisp white text with subtle shadow as in mockup)
            Text(formattedCoordinates)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
                .shadow(color: Color.black.opacity(0.45), radius: 2, x: 0, y: 1)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .padding(.bottom, 2)
            
            // 3. Flag Image Card with Liquid Glass Inset
            if let country = detectedCountry {
                ZStack {
                    // Fallback to high-resolution emoji
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
                    
                    // Specular sheen over the flag glass
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
                                colors: [
                                    Color.white.opacity(0.75),
                                    Color.white.opacity(0.30)
                                ],
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
                                colors: [
                                    Color.white.opacity(0.75),
                                    Color.white.opacity(0.30)
                                ],
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
                in: RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
            )
        } else {
            cardContent
                .background(LiquidGlassBackground(cornerRadius: 24))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)
                .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 2)
        }
    }
    
    // MARK: - Helpers
    private func displayName(for country: CountryFeature) -> String {
        switch country.isoA3 {
        case "USA": return "United States"
        case "GBR": return "United Kingdom"
        default: return country.name
        }
    }
    private var formattedCoordinates: String {
        let latStr = String(format: "%.6f", abs(centerCoordinate.latitude)).replacingOccurrences(of: ".", with: ",")
        let lonStr = String(format: "%.5f", abs(centerCoordinate.longitude)).replacingOccurrences(of: ".", with: ",")
        return "\(latStr) - \(lonStr)"
    }
}

// MARK: - Liquid Glass Background Effect
struct LiquidGlassBackground: View {
    var cornerRadius: CGFloat = 24
    
    var body: some View {
        ZStack {
            // 1. Crystal Liquid Diffusion Layer (Balanced optical diffusion)
            // Tuned to 0.22 for the ideal balance: crisp Earth visibility beneath + tangible liquid glass refraction
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .light)
                .opacity(0.22)
            
            // 2. Liquid Glass Translucent Body Tint (Icy, luminous crystal tone)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02),
                            Color.white.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 3. Diagonal Liquid Gloss Sweep (Studio light refraction across liquid surface)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color.white.opacity(0.05), location: 0.28),
                            .init(color: Color.white.opacity(0.24), location: 0.44),
                            .init(color: Color.white.opacity(0.06), location: 0.54),
                            .init(color: .clear, location: 0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 4. Specular Liquid Lens Reflection (Curved top meniscus highlight)
            VStack {
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.55), location: 0.0),
                        .init(color: Color.white.opacity(0.22), location: 0.30),
                        .init(color: Color.clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 58)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            
            // 5. Bottom Caustic Lip (Light gathering along lower rim)
            VStack {
                Spacer()
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: Color.white.opacity(0.08), location: 0.50),
                        .init(color: Color.white.opacity(0.28), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 35)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            
            // 6. Outer 3D Refractive Meniscus Rim (Crisp highlight where light strikes glass edge)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.95), location: 0.0),
                            .init(color: Color.white.opacity(0.68), location: 0.35),
                            .init(color: Color.white.opacity(0.20), location: 0.65),
                            .init(color: Color.white.opacity(0.52), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.4
                )
            
            // 7. Inner Chamfer / Physical Glass Thickness (Secondary refraction line)
            RoundedRectangle(cornerRadius: cornerRadius - 1.5, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.48), location: 0.0),
                            .init(color: Color.white.opacity(0.16), location: 0.35),
                            .init(color: Color.clear, location: 0.65),
                            .init(color: Color.white.opacity(0.22), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
                .padding(1.5)
        }
    }
}

// MARK: - Center Indicator View (Crosshair from Assets)
struct CenterIndicatorView: View {
    var body: some View {
        Image("center_indicator_icon")
            .resizable()
            .scaledToFit()
            .frame(width: 60, height: 60)
            .allowsHitTesting(false)
    }
}

#Preview {
    ContentView()
}
