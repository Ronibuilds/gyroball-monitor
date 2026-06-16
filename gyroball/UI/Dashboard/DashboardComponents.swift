import SwiftUI

// MARK: - Card container

enum CardTier { case standard, hero }

/// A consistent surface used across the dashboard. `.hero` matches the floating
/// widget's material + shadow so a live session reads as the same object.
struct DashCard<Content: View>: View {
    var title: String? = nil
    var systemImage: String? = nil
    var accentColor: Color = Theme.blue
    var tier: CardTier = .standard
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                HStack(spacing: 8) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(accentColor)
                            .frame(width: 22, height: 22)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(accentColor.opacity(0.16)))
                    }
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
            }
            content()
        }
        .padding(tier == .hero ? 20 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(Color.primary.opacity(tier == .hero ? 0.10 : 0.07), lineWidth: 1))
        .shadow(color: .black.opacity(tier == .hero ? 0.18 : 0), radius: tier == .hero ? 18 : 0, y: tier == .hero ? 6 : 0)
    }

    private var radius: CGFloat { tier == .hero ? 20 : 14 }
    @ViewBuilder private var background: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        switch tier {
        case .hero:     shape.fill(.regularMaterial)
        case .standard: shape.fill(Color.primary.opacity(0.045))
        }
    }
}

// MARK: - Clickable wrapper

/// Wraps any content in a button with hover affordance (subtle lift + stroke +
/// trailing chevron). The primitive that makes the dashboard feel navigable.
struct ClickableCard<Content: View>: View {
    var action: () -> Void
    var showsChevron: Bool = true
    @ViewBuilder var content: () -> Content
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .trailing) {
                content()
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .opacity(hovering ? 1 : 0)
                        .padding(.trailing, 14)
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.primary.opacity(hovering ? 0.14 : 0), lineWidth: 1))
        .scaleEffect(hovering ? 1.006 : 1)
        .animation(.easeOut(duration: 0.14), value: hovering)
        .onHover { hovering = $0 }
    }
}

// MARK: - Small uppercase label

struct SectionLabel: View {
    let text: String
    var color: Color = Color.secondary
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold)).tracking(1.5)
            .foregroundStyle(color)
    }
}

// MARK: - Metric tile

struct MetricTile: View {
    let label: String
    let value: String
    var unit: String? = nil
    var color: Color = .primary
    /// When set, renders a thin target bar under the value.
    var rpm: Double? = nil
    var target: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: label)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit().foregroundStyle(color)
                if let unit { Text(unit).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary) }
            }
            if let rpm, let target {
                TargetBar(rpm: rpm, target: target).frame(maxWidth: 120)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Goal stepper row

struct GoalStepper: View {
    let label: String
    let value: String
    var onDec: () -> Void
    var onInc: () -> Void
    var body: some View {
        HStack {
            Text(label).font(.system(size: 13))
            Spacer()
            HStack(spacing: 10) {
                stepButton("minus", action: onDec)
                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit().frame(minWidth: 52).multilineTextAlignment(.center)
                stepButton("plus", action: onInc)
            }
        }
        .padding(.vertical, 7)
    }
    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.08)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Streak badge

struct StreakBadge: View {
    let count: Int
    var best: Int = 0
    var body: some View {
        Label("\(count)-day streak", systemImage: "flame.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(Color.orange.opacity(0.16)))
            .help(best > 0 ? "Best streak: \(best) days" : "")
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let symbol: String
    let title: String
    var hint: String? = nil
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.06)))
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            if let hint {
                Text(hint).font(.system(size: 11)).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}

func cardBackground(_ color: Color) -> some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(color.opacity(0.07))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(color.opacity(0.14), lineWidth: 1))
}
