import SwiftUI
import WeatherCore

struct WeatherWidgetBackground: View {
    let category: WeatherConditionCategory
    let isNight: Bool

    var body: some View {
        let theme = WeatherWidgetTheme(category: category, isNight: isNight)

        ZStack {
            LinearGradient(colors: theme.backgroundGradient, startPoint: .topLeading, endPoint: .bottomTrailing)

            if let glow = theme.glowColor {
                Circle()
                    .fill(glow)
                    .frame(width: 184, height: 184)
                    .blur(radius: 44)
                    .offset(x: 64, y: -74)
            }

            textureOverlay(theme: theme)

            Rectangle()
                .fill(Color.black.opacity(theme.scrimOpacity))
        }
    }

    @ViewBuilder
    private func textureOverlay(theme: WeatherWidgetTheme) -> some View {
        switch category {
        case .drizzle:
            RainTexture(density: 6, lengthRatio: 0.24, opacity: 0.08, tint: theme.textureTint)
        case .rain:
            RainTexture(density: 8, lengthRatio: 0.29, opacity: 0.10, tint: theme.textureTint)
        case .downpour, .thunderstorm:
            RainTexture(density: 10, lengthRatio: 0.34, opacity: 0.13, tint: theme.textureTint)
        case .snow:
            SnowTexture(count: 12, opacity: 0.16, tint: theme.textureTint)
        case .blizzard:
            ZStack {
                SnowTexture(count: 18, opacity: 0.20, tint: theme.textureTint)
                WindTexture(lineCount: 3, opacity: 0.13, tint: theme.textureTint)
            }
        case .sleet:
            ZStack {
                RainTexture(density: 6, lengthRatio: 0.25, opacity: 0.10, tint: theme.textureTint)
                SnowTexture(count: 8, opacity: 0.13, tint: theme.textureTint)
            }
        case .fog, .haze, .mostlyCloudy, .overcast:
            MistTexture(strength: category == .fog ? 0.15 : 0.11, tint: theme.textureTint)
        case .sandDust:
            ZStack {
                WindTexture(lineCount: 2, opacity: 0.12, tint: theme.textureTint)
                DustTexture(count: 12, opacity: 0.16, tint: theme.textureTint)
            }
        case .windy:
            WindTexture(lineCount: 3, opacity: 0.14, tint: theme.textureTint)
        default:
            EmptyView()
        }
    }
}

private struct RainTexture: View {
    let density: Int
    let lengthRatio: CGFloat
    let opacity: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ForEach(0..<density, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(tint.opacity(opacity * (0.95 - Double(index % 3) * 0.15)))
                    .frame(width: max(1.0, width * 0.010), height: height * lengthRatio)
                    .rotationEffect(.degrees(17))
                    .offset(
                        x: CGFloat(index) * (width / CGFloat(max(1, density - 1))) - width * 0.07,
                        y: CGFloat(index % 4) * 9 - 10
                    )
            }
        }
    }
}

private struct SnowTexture: View {
    let count: Int
    let opacity: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ForEach(0..<count, id: \.self) { index in
                let size = CGFloat((index % 3) + 2)
                Circle()
                    .fill(tint.opacity(opacity))
                    .frame(width: size, height: size)
                    .offset(
                        x: CGFloat((index * 37) % 100) / 100 * width - width * 0.04,
                        y: CGFloat((index * 53) % 100) / 100 * (height * 0.90) - height * 0.02
                    )
            }
        }
    }
}

private struct MistTexture: View {
    let strength: Double
    let tint: Color

    var body: some View {
        VStack(spacing: 9) {
            Capsule(style: .continuous)
                .fill(tint.opacity(strength))
                .frame(height: 16)
                .blur(radius: 2)
                .offset(x: -18)
            Capsule(style: .continuous)
                .fill(tint.opacity(strength * 0.82))
                .frame(height: 14)
                .blur(radius: 2)
                .offset(x: 16)
            Capsule(style: .continuous)
                .fill(tint.opacity(strength * 0.66))
                .frame(height: 12)
                .blur(radius: 2)
                .offset(x: -10)
        }
        .padding(.horizontal, 14)
    }
}

private struct WindTexture: View {
    let lineCount: Int
    let opacity: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(0..<lineCount, id: \.self) { index in
                GeometryReader { proxy in
                    let ratio = max(0.36, 0.78 - CGFloat(index) * 0.14)
                    Capsule(style: .continuous)
                        .fill(tint.opacity(opacity * (0.95 - Double(index) * 0.13)))
                        .frame(width: proxy.size.width * ratio, height: 3)
                        .offset(x: proxy.size.width * (1 - ratio))
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, 14)
        .offset(y: 4)
    }
}

private struct DustTexture: View {
    let count: Int
    let opacity: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ForEach(0..<count, id: \.self) { index in
                let size = CGFloat((index % 4) + 1)
                Circle()
                    .fill(tint.opacity(opacity * (0.85 - Double(index % 3) * 0.12)))
                    .frame(width: size, height: size)
                    .offset(
                        x: CGFloat((index * 29) % 100) / 100 * width - width * 0.05,
                        y: CGFloat((index * 47) % 100) / 100 * height - height * 0.05
                    )
            }
        }
    }
}
