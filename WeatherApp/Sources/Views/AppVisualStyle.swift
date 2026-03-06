import SwiftUI
import WeatherCore

enum AppPalette {
    static let accent = Color(red: 0.31, green: 0.84, blue: 0.96)
    static let accentStrong = Color(red: 0.25, green: 0.62, blue: 0.96)
    static let cardFill = Color.white.opacity(0.07)
    static let cardBorder = Color.white.opacity(0.14)
    static let cardShadow = Color.black.opacity(0.22)
}

struct AppGradientBackground: View {
    var category: WeatherConditionCategory? = nil
    var isNight: Bool = false

    var body: some View {
        ZStack {
            if let category {
                WeatherWidgetBackground(category: category, isNight: isNight)
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.12, blue: 0.20),
                        Color(red: 0.06, green: 0.10, blue: 0.16),
                        Color(red: 0.04, green: 0.07, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            Circle()
                .fill(AppPalette.accent.opacity(category == nil ? 0.18 : 0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 40)
                .offset(x: 210, y: -260)

            Circle()
                .fill(Color.cyan.opacity(category == nil ? 0.10 : 0.07))
                .frame(width: 260, height: 260)
                .blur(radius: 48)
                .offset(x: -220, y: 280)

            Rectangle()
                .fill(Color.black.opacity(category == nil ? 0.0 : 0.08))
        }
        .ignoresSafeArea()
    }
}

struct AppCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: AppPalette.cardShadow, radius: 14, x: 0, y: 8)
    }
}

struct AppSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MetricChip: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(.callout, design: .rounded, weight: .medium))
            Text(title)
                .font(.system(.callout, design: .rounded, weight: .bold))
                .lineLimit(1)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.10))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(Capsule(style: .continuous))
        .foregroundStyle(.white.opacity(0.92))
    }
}

struct WrappingFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 10
    var verticalSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, maxWidth: proposal.width ?? .greatestFiniteMagnitude)
        let totalHeight = rows.reduce(0) { partial, row in
            partial + row.height
        } + max(0, CGFloat(rows.count - 1) * verticalSpacing)

        let maxRowWidth = rows.map(\.width).max() ?? 0
        return CGSize(width: maxRowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for element in row.elements {
                let yOffset = (row.height - element.size.height) / 2
                subviews[element.index].place(
                    at: CGPoint(x: x, y: y + yOffset),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(element.size)
                )
                x += element.size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        let limit = max(1, maxWidth.isFinite ? maxWidth : .greatestFiniteMagnitude)
        var rows: [Row] = [.init()]

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = rows[rows.count - 1].elements.isEmpty
                ? size.width
                : rows[rows.count - 1].width + horizontalSpacing + size.width

            if nextWidth > limit, !rows[rows.count - 1].elements.isEmpty {
                rows.append(.init())
            }

            rows[rows.count - 1].append(index: index, size: size, spacing: horizontalSpacing)
        }

        return rows
    }

    private struct Row {
        var elements: [Element] = []
        var width: CGFloat = 0
        var height: CGFloat = 0

        mutating func append(index: Int, size: CGSize, spacing: CGFloat) {
            if elements.isEmpty {
                width = size.width
            } else {
                width += spacing + size.width
            }
            height = max(height, size.height)
            elements.append(Element(index: index, size: size))
        }
    }

    private struct Element {
        let index: Int
        let size: CGSize
    }
}

struct StatusBadge: View {
    let text: String
    let tone: StatusTone

    enum StatusTone {
        case good
        case warning
        case neutral
        case bad
    }

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .clipShape(Capsule(style: .continuous))
    }

    private var backgroundColor: Color {
        switch tone {
        case .good:
            return Color.green.opacity(0.70)
        case .warning:
            return Color.orange.opacity(0.72)
        case .neutral:
            return Color.white.opacity(0.24)
        case .bad:
            return Color.red.opacity(0.72)
        }
    }
}

struct ValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
            Spacer(minLength: 8)
            Text(value)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.callout, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [AppPalette.accent, AppPalette.accentStrong],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(configuration.isPressed ? 0.85 : 1.0)
            )
            .clipShape(Capsule(style: .continuous))
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.callout, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(configuration.isPressed ? 0.18 : 0.12))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .clipShape(Capsule(style: .continuous))
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
