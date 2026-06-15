import SwiftUI

// MARK: - Card container

/// A consistent surface used across the dashboard. Adapts to light/dark.
struct DashCard<Content: View>: View {
    var title: String? = nil
    var systemImage: String? = nil
    var accentColor: Color = Theme.blue
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
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.primary.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))
    }
}

// MARK: - Small uppercase label

struct SectionLabel: View {
    let text: String
    var color: Color = Color.secondary
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(color)
    }
}

// MARK: - Metric tile (label + big number)

struct MetricTile: View {
    let label: String
    let value: String
    var unit: String? = nil
    var color: Color = .primary
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: label)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                if let unit {
                    Text(unit).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                }
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
                    .monospacedDigit()
                    .frame(minWidth: 52)
                    .multilineTextAlignment(.center)
                stepButton("plus", action: onInc)
            }
        }
        .padding(.vertical, 7)
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.08)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
