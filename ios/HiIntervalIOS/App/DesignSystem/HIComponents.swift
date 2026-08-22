import SwiftUI

struct HIPage<Content: View>: View {
    @ViewBuilder private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            HITheme.canvas.ignoresSafeArea()
            content()
        }
        .foregroundStyle(HITheme.textPrimary)
    }
}

struct HISurfaceCard<Content: View>: View {
    private let padding: CGFloat
    @ViewBuilder private let content: () -> Content

    init(
        padding: CGFloat = HITheme.Spacing.medium,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HITheme.surface, in: RoundedRectangle(cornerRadius: HITheme.Radius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: HITheme.Radius.medium)
                    .stroke(HITheme.stroke, lineWidth: 1)
            }
    }
}

struct HISectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: HITheme.Spacing.xSmall) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(HITheme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(HITheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct HIStatTile: View {
    let value: String
    let label: String
    let systemImage: String
    var tint: Color = HITheme.accent

    var body: some View {
        HISurfaceCard {
            VStack(alignment: .leading, spacing: HITheme.Spacing.small) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(tint)
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text(label)
                    .font(.caption)
                    .foregroundStyle(HITheme.textSecondary)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}

struct HIEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: HITheme.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(HITheme.accent)
                .frame(width: 72, height: 72)
                .background(HITheme.accent.opacity(0.12), in: Circle())
            Text(title)
                .font(.title3.bold())
            Text(message)
                .font(.body)
                .foregroundStyle(HITheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(HITheme.Spacing.large)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct HIProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 14
    var tint: Color = HITheme.accent

    private var clampedProgress: Double { min(1, max(0, progress)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(HITheme.surfaceStrong, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: clampedProgress)
        }
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(clampedProgress * 100)) percent")
    }
}

struct HIPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color(red: 0.02, green: 0.12, blue: 0.12))
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, HITheme.Spacing.medium)
            .background(HITheme.heroGradient, in: RoundedRectangle(cornerRadius: HITheme.Radius.medium))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct HISecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(HITheme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, HITheme.Spacing.medium)
            .background(HITheme.surfaceStrong, in: RoundedRectangle(cornerRadius: HITheme.Radius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: HITheme.Radius.medium)
                    .stroke(HITheme.stroke, lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct HIIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .foregroundStyle(HITheme.textPrimary)
            .frame(width: 52, height: 52)
            .background(HITheme.surfaceStrong, in: Circle())
            .overlay { Circle().stroke(HITheme.stroke, lineWidth: 1) }
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

enum HIDurationFormatter {
    static func string(seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        let hours = safeSeconds / 3_600
        let minutes = (safeSeconds % 3_600) / 60
        let remainder = safeSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%02d:%02d", minutes, remainder)
    }

    static func compactString(seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        if safeSeconds >= 3_600 {
            return "\(safeSeconds / 3_600)h \((safeSeconds % 3_600) / 60)m"
        }
        if safeSeconds >= 60 {
            return "\(safeSeconds / 60)m \(safeSeconds % 60)s"
        }
        return "\(safeSeconds)s"
    }
}

extension View {
    func hiNavigationStyle() -> some View {
        toolbarBackground(HITheme.canvasRaised, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
