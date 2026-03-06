import SwiftUI
import WeatherCore

struct WeatherGlyph: View {
    let category: WeatherConditionCategory
    let isNight: Bool
    let size: CGFloat
    let palette: WeatherGlyphPalette

    var body: some View {
        ZStack {
            glyphBody
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var glyphBody: some View {
        switch category {
        case .clear:
            clearGlyph
        case .partlyCloudy:
            partlyCloudyGlyph
        case .mostlyCloudy:
            mostlyCloudyGlyph
        case .overcast:
            overcastGlyph
        case .fog:
            fogGlyph
        case .haze:
            hazeGlyph
        case .sandDust:
            sandDustGlyph
        case .drizzle:
            drizzleGlyph
        case .rain:
            rainGlyph
        case .downpour:
            downpourGlyph
        case .sleet:
            sleetGlyph
        case .snow:
            snowGlyph
        case .blizzard:
            blizzardGlyph
        case .thunderstorm:
            thunderstormGlyph
        case .windy:
            windyGlyph
        case .unknown:
            overcastGlyph
        }
    }

    @ViewBuilder
    private var clearGlyph: some View {
        if isNight {
            moonCore
        } else {
            sunCore
        }
    }

    private var partlyCloudyGlyph: some View {
        ZStack {
            iconLightCore
                .scaleEffect(0.76)
                .offset(x: size * 0.18, y: -size * 0.20)
            cloud(width: size * 0.84, height: size * 0.44, color: palette.primary)
                .offset(y: size * 0.12)
        }
    }

    private var mostlyCloudyGlyph: some View {
        ZStack {
            iconLightCore
                .scaleEffect(0.58)
                .opacity(0.8)
                .offset(x: size * 0.18, y: -size * 0.26)
            cloud(width: size * 0.70, height: size * 0.37, color: palette.secondary)
                .offset(x: -size * 0.10, y: size * 0.03)
            cloud(width: size * 0.84, height: size * 0.44, color: palette.primary)
                .offset(x: size * 0.06, y: size * 0.16)
        }
    }

    private var overcastGlyph: some View {
        ZStack {
            cloud(width: size * 0.72, height: size * 0.38, color: palette.secondary)
                .offset(x: -size * 0.12, y: 0)
            cloud(width: size * 0.88, height: size * 0.46, color: palette.primary)
                .offset(x: size * 0.06, y: size * 0.14)
        }
    }

    private var fogGlyph: some View {
        ZStack {
            cloud(width: size * 0.86, height: size * 0.44, color: palette.primary)
                .offset(y: size * 0.03)
            horizonLines(count: 3, widthScale: 0.86, color: palette.secondary.opacity(0.82), yOffset: size * 0.34)
        }
    }

    private var hazeGlyph: some View {
        ZStack {
            iconLightCore
                .scaleEffect(0.62)
                .opacity(0.85)
                .offset(x: size * 0.20, y: -size * 0.22)
            cloud(width: size * 0.82, height: size * 0.42, color: palette.primary)
                .offset(y: size * 0.12)
            horizonLines(count: 2, widthScale: 0.70, color: palette.secondary.opacity(0.7), yOffset: size * 0.40)
        }
    }

    private var sandDustGlyph: some View {
        ZStack {
            cloud(width: size * 0.82, height: size * 0.42, color: palette.primary)
                .offset(y: size * 0.10)
            horizonLines(count: 2, widthScale: 0.78, color: palette.secondary.opacity(0.85), yOffset: size * 0.36)
            dustParticles
        }
    }

    private var drizzleGlyph: some View {
        ZStack {
            cloud(width: size * 0.86, height: size * 0.44, color: palette.primary)
                .offset(y: size * 0.04)
            rainStreaks(count: 3, length: size * 0.25, thickness: max(1, size * 0.055), color: palette.secondary, yOffset: size * 0.43)
        }
    }

    private var rainGlyph: some View {
        ZStack {
            cloud(width: size * 0.86, height: size * 0.44, color: palette.primary)
                .offset(y: size * 0.04)
            rainStreaks(count: 4, length: size * 0.29, thickness: max(1, size * 0.060), color: palette.secondary, yOffset: size * 0.45)
        }
    }

    private var downpourGlyph: some View {
        ZStack {
            cloud(width: size * 0.86, height: size * 0.44, color: palette.primary)
                .offset(y: size * 0.02)
            rainStreaks(count: 6, length: size * 0.33, thickness: max(1, size * 0.068), color: palette.secondary, yOffset: size * 0.47)
        }
    }

    private var sleetGlyph: some View {
        ZStack {
            cloud(width: size * 0.86, height: size * 0.44, color: palette.primary)
                .offset(y: size * 0.03)
            rainStreaks(count: 2, length: size * 0.26, thickness: max(1, size * 0.056), color: palette.secondary, yOffset: size * 0.45)
            snowDots(count: 3, diameter: max(2, size * 0.12), color: palette.accent, yOffset: size * 0.46)
        }
    }

    private var snowGlyph: some View {
        ZStack {
            cloud(width: size * 0.86, height: size * 0.44, color: palette.primary)
                .offset(y: size * 0.03)
            snowDots(count: 5, diameter: max(2, size * 0.12), color: palette.accent, yOffset: size * 0.46)
        }
    }

    private var blizzardGlyph: some View {
        ZStack {
            cloud(width: size * 0.86, height: size * 0.44, color: palette.primary)
                .offset(y: size * 0.02)
            snowDots(count: 7, diameter: max(2, size * 0.11), color: palette.accent, yOffset: size * 0.44)
            horizonLines(count: 2, widthScale: 0.72, color: palette.secondary.opacity(0.82), yOffset: size * 0.64)
        }
    }

    private var thunderstormGlyph: some View {
        ZStack {
            cloud(width: size * 0.88, height: size * 0.46, color: palette.primary)
                .offset(y: size * 0.02)
            rainStreaks(count: 3, length: size * 0.24, thickness: max(1, size * 0.054), color: palette.secondary, yOffset: size * 0.47)
            lightningBolt
                .offset(x: size * 0.06, y: size * 0.36)
        }
    }

    private var windyGlyph: some View {
        ZStack {
            cloud(width: size * 0.62, height: size * 0.33, color: palette.primary.opacity(0.92))
                .offset(x: size * 0.20, y: -size * 0.12)
            horizonLines(count: 3, widthScale: 0.92, color: palette.secondary.opacity(0.82), yOffset: size * 0.10)
        }
    }

    @ViewBuilder
    private var iconLightCore: some View {
        if isNight {
            moonCore
        } else {
            sunCore
        }
    }

    private var sunCore: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(palette.secondary.opacity(0.95))
                    .frame(width: max(1.5, size * 0.08), height: size * 0.23)
                    .offset(y: -size * 0.42)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
            Circle()
                .fill(palette.primary)
                .frame(width: size * 0.58, height: size * 0.58)
            Circle()
                .stroke(palette.stroke, lineWidth: max(1, size * 0.03))
                .frame(width: size * 0.58, height: size * 0.58)
        }
    }

    private var moonCore: some View {
        ZStack {
            Circle()
                .fill(palette.primary)
                .frame(width: size * 0.58, height: size * 0.58)
            Circle()
                .fill(palette.secondary.opacity(0.55))
                .frame(width: size * 0.50, height: size * 0.50)
                .offset(x: size * 0.16, y: -size * 0.10)
        }
    }

    private func cloud(width: CGFloat, height: CGFloat, color: Color) -> some View {
        ZStack(alignment: .bottomLeading) {
            Circle()
                .fill(color)
                .frame(width: width * 0.44, height: height * 0.84)
                .offset(x: width * 0.05, y: -height * 0.10)
            Circle()
                .fill(color)
                .frame(width: width * 0.52, height: height)
                .offset(x: width * 0.31, y: -height * 0.20)
            Circle()
                .fill(color)
                .frame(width: width * 0.43, height: height * 0.76)
                .offset(x: width * 0.63, y: -height * 0.08)
            RoundedRectangle(cornerRadius: height * 0.30, style: .continuous)
                .fill(color)
                .frame(width: width, height: height * 0.47)
                .offset(y: height * 0.08)
        }
    }

    private func rainStreaks(count: Int, length: CGFloat, thickness: CGFloat, color: Color, yOffset: CGFloat) -> some View {
        HStack(spacing: size * 0.08) {
            ForEach(0..<count, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(color.opacity(0.95 - Double(index % 3) * 0.12))
                    .frame(width: thickness, height: length)
                    .rotationEffect(.degrees(18))
            }
        }
        .offset(y: yOffset)
    }

    private func snowDots(count: Int, diameter: CGFloat, color: Color, yOffset: CGFloat) -> some View {
        let points: [(CGFloat, CGFloat)] = [
            (-0.30, 0.00), (-0.10, 0.06), (0.10, -0.02), (0.30, 0.07),
            (-0.18, 0.15), (0.02, 0.14), (0.24, 0.16), (-0.04, 0.24)
        ]
        return ZStack {
            ForEach(0..<min(count, points.count), id: \.self) { index in
                Circle()
                    .fill(color.opacity(0.95))
                    .frame(width: diameter, height: diameter)
                    .offset(
                        x: size * points[index].0,
                        y: yOffset + size * points[index].1
                    )
            }
        }
    }

    private func horizonLines(count: Int, widthScale: CGFloat, color: Color, yOffset: CGFloat) -> some View {
        let lineHeight = max(1, size * 0.050)
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(color.opacity(0.95 - Double(index) * 0.10))
                    .frame(width: size * (widthScale - CGFloat(index) * 0.12), height: lineHeight)
                    .offset(x: size * 0.16, y: yOffset + CGFloat(index) * size * 0.12)
            }
        }
    }

    private var dustParticles: some View {
        let points: [(CGFloat, CGFloat)] = [(-0.20, 0.22), (0.04, 0.26), (0.26, 0.19), (0.12, 0.34)]
        return ZStack {
            ForEach(0..<points.count, id: \.self) { index in
                Circle()
                    .fill(palette.accent.opacity(0.72))
                    .frame(width: max(1.5, size * 0.07), height: max(1.5, size * 0.07))
                    .offset(x: size * points[index].0, y: size * points[index].1)
            }
        }
    }

    private var lightningBolt: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 0.50, y: 0))
            path.addLine(to: CGPoint(x: size * 0.38, y: size * 0.26))
            path.addLine(to: CGPoint(x: size * 0.52, y: size * 0.26))
            path.addLine(to: CGPoint(x: size * 0.42, y: size * 0.54))
            path.addLine(to: CGPoint(x: size * 0.68, y: size * 0.18))
            path.addLine(to: CGPoint(x: size * 0.54, y: size * 0.18))
            path.closeSubpath()
        }
        .fill(palette.accent)
    }
}
