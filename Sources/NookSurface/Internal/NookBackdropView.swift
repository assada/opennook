// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin

import SwiftUI

/// Shared backdrop renderer for the main nook and its attached accessories.
struct NookBackdropView<ClipShape: Shape>: View {
    let backdrop: NookBackdrop
    let shape: ClipShape

    var body: some View {
        Group {
            switch backdrop {
                case .vibrancy(let spec):
                    ZStack {
                        VisualEffectView(material: spec.material, blendingMode: spec.blendingMode)
                        if spec.darkenOpacity > 0 {
                            Color.black.opacity(spec.darkenOpacity)
                        }
                    }
                case .solid(let color):
                    color
                case .liquidGlass(let glass):
                    liquidGlass(glass)
            }
        }
        .clipShape(shape)
    }

    @ViewBuilder
    private func liquidGlass(_ glass: NookBackdrop.LiquidGlass) -> some View {
        #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                realLiquidGlass(glass)
            } else {
                approximateLiquidGlass(glass)
            }
        #else
            approximateLiquidGlass(glass)
        #endif
    }

    #if compiler(>=6.2)
        @available(macOS 26.0, *)
        private func realLiquidGlass(_ glass: NookBackdrop.LiquidGlass) -> some View {
            let material: Glass = {
                guard let tint = glass.tint, glass.tintStrength > 0 else { return .regular }
                return Glass.regular.tint(tint.opacity(glass.tintStrength))
            }()
            return Color.clear
                .glassEffect(material, in: shape)
                .overlay { glassShading(glass) }
        }
    #endif

    @ViewBuilder
    private func glassShading(_ glass: NookBackdrop.LiquidGlass) -> some View {
        if let shading = glass.shading {
            LinearGradient(
                gradient: shading.gradient,
                startPoint: shading.startPoint,
                endPoint: shading.endPoint
            )
        }
    }

    private func approximateLiquidGlass(_ glass: NookBackdrop.LiquidGlass) -> some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

            if let tint = glass.tint, glass.tintStrength > 0 {
                tint.opacity(glass.tintStrength)
            }

            glassShading(glass)

            if glass.highlightStrength > 0 {
                LinearGradient(
                    colors: [Color.white.opacity(0.16 * glass.highlightStrength), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.5 * glass.highlightStrength),
                            Color.white.opacity(0.06 * glass.highlightStrength),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
        }
    }
}
