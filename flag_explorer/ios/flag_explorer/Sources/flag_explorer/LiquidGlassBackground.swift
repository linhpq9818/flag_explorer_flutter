//
//  LiquidGlassBackground.swift
//  flag_explorer
//
//  Created for Flag Explorer - Native Liquid Glass UI Component
//

import SwiftUI

/// Liquid Glass translucent refractive background with multi-pass specular highlights and chamfered rims
public struct LiquidGlassBackground: View {
    public var cornerRadius: CGFloat = 24
    
    public init(cornerRadius: CGFloat = 24) {
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        ZStack {
            // 1. Crystal Liquid Diffusion Layer
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .light)
                .opacity(0.22)
            
            // 2. Liquid Glass Translucent Body Tint
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
                        .init(color: .clear, location: 0.0),
                        .init(color: Color.white.opacity(0.08), location: 0.50),
                        .init(color: Color.white.opacity(0.28), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 35)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            
            // 6. Outer 3D Refractive Meniscus Rim
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
            
            // 7. Inner Chamfer / Physical Glass Thickness
            RoundedRectangle(cornerRadius: max(0, cornerRadius - 1.5), style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.48), location: 0.0),
                            .init(color: Color.white.opacity(0.16), location: 0.35),
                            .init(color: .clear, location: 0.65),
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
