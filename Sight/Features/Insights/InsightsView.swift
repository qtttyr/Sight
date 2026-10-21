import SightCore
import SwiftUI

struct InsightsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme

    private struct CountItem: Identifiable {
        let id: String
        let label: String
        let count: Int
        let total: Int
    }

    private var scoredEvents: [SortEvent] {
        model.events.filter { $0.score != nil }
    }

    private var averageConfidence: Int {
        guard !scoredEvents.isEmpty else { return 0 }
        let total = scoredEvents.reduce(Float(0)) { $0 + ($1.score ?? 0) }
        return Int((total / Float(scoredEvents.count)) * 100)
    }

    private var movedCount: Int {
        model.events.filter { $0.outcome == .moved }.count
    }

    private var reviewCount: Int {
        model.events.filter { $0.outcome == .review || $0.outcome == .skipped }.count
    }

    private var categoryItems: [CountItem] {
        let grouped = Dictionary(grouping: model.events.compactMap(\.category), by: { $0 })
        let total = max(grouped.values.reduce(0) { $0 + $1.count }, 1)
        return grouped
            .map { CountItem(id: $0.key, label: $0.key, count: $0.value.count, total: total) }
            .sorted { $0.count > $1.count }
    }

    private var confidenceItems: [CountItem] {
        let changes = [0.2, 0.4, 0.6, 0.8, 1.0]
        var buckets = Array(repeating: 0, count: 5)
        for event in scoredEvents {
            let score = min(max(event.score ?? 0, 0), 1)
            let index = min(4, max(0, Int(score * 5.0 - 0.0001)))
            buckets[index] += 1
        }
        let total = max(buckets.reduce(0, +), 1)
        return zip(changes, buckets).enumerated().map { index, pair in
            let lower = index == 0 ? 0 : Int(changes[index - 1] * 100)
            let upper = Int(pair.0 * 100)
            return CountItem(
                id: "\(lower)-\(upper)",
                label: "\(lower)–\(upper)%",
                count: pair.1,
                total: total
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                HStack(spacing: 16) {
                    SightCard(padding: 20) {
                        MetricView(value: "\(model.events.count)", label: "FILES SEEN")
                    }
                    SightCard(padding: 20) {
                        MetricView(value: "\(movedCount)", label: "MOVED")
                    }
                    SightCard(padding: 20) {
                        MetricView(value: "\(reviewCount)", label: "REVIEWED")
                    }
                    SightCard(padding: 20) {
                        MetricView(value: "\(averageConfidence)", label: "AVG CONFIDENCE", suffix: "%")
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    categoryCard
                    confidenceCard
                }

                HStack(alignment: .top, spacing: 16) {
                    modelCard
                    rulesCard
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 38)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        HStack(alignment: .top) {
            SectionHeader(title: "INSIGHTS", subtitle: "What Sight has learned.")
            Spacer()
            if let summary = model.lastSummary {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("LAST SWEEP")
                        .font(SightFont.micro())
                        .foregroundStyle(theme.textFaint)
                    Text(duration(summary.duration))
                        .font(SightFont.mono())
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
    }

    private var categoryCard: some View {
        SightCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("BY CATEGORY")
                    .font(SightFont.micro())
                    .tracking(0.14)
                    .foregroundStyle(theme.textTertiary)

                if categoryItems.isEmpty {
                    Text("No classified files yet.")
                        .font(SightFont.body())
                        .foregroundStyle(theme.textFaint)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                } else {
                    ForEach(categoryItems) { item in
                        HStack(spacing: 14) {
                            Text(item.label)
                                .font(SightFont.body())
                                .foregroundStyle(theme.textSecondary)
                                .frame(width: 78, alignment: .leading)
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(theme.line).frame(height: 3)
                                    Capsule()
                                        .fill(theme.paper)
                                        .frame(
                                            width: max(3, proxy.size.width * CGFloat(item.count) / CGFloat(item.total)),
                                            height: 3
                                        )
                                }
                            }
                            .frame(height: 3)
                            Text("\(item.count)")
                                .font(SightFont.micro())
                                .foregroundStyle(theme.textTertiary)
                                .frame(width: 28, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var confidenceCard: some View {
        SightCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("CONFIDENCE")
                    .font(SightFont.micro())
                    .tracking(0.14)
                    .foregroundStyle(theme.textTertiary)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(confidenceItems) { item in
                        VStack(spacing: 8) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(theme.paper.opacity(item.count == 0 ? 0.12 : 0.9))
                                .frame(height: max(3, 90 * CGFloat(item.count) / CGFloat(max(item.total, 1))))
                            Text(item.label)
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(theme.textFaint)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var modelCard: some View {
        SightCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("MODEL")
                    .font(SightFont.micro())
                    .tracking(0.14)
                    .foregroundStyle(theme.textTertiary)

                detailRow("STATE", value: model.modelState.title)
                detailRow("DIMENSION", value: model.config.dimension.label)
                detailRow("VISION", value: model.config.loadVision ? "ON" : "OFF")
                detailRow("AUDIO", value: model.config.loadAudio ? "ON" : "OFF")
                detailRow("ON DISK", value: ByteCountFormatter.string(
                    fromByteCount: model.modelDiskUsage,
                    countStyle: .file
                ))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var rulesCard: some View {
        SightCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("RULE FINGERPRINTS")
                    .font(SightFont.micro())
                    .tracking(0.14)
                    .foregroundStyle(theme.textTertiary)

                if model.rules.isEmpty {
                    Text("Add rules to see their semantic signatures.")
                        .font(SightFont.body())
                        .foregroundStyle(theme.textFaint)
                } else {
                    ForEach(model.rules.prefix(4)) { rule in
                        HStack(spacing: 14) {
                            Text(rule.name)
                                .font(SightFont.body())
                                .foregroundStyle(theme.textSecondary)
                                .frame(width: 72, alignment: .leading)
                            VectorFingerprint(values: model.ruleFingerprints[rule.id] ?? [])
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(SightFont.micro())
                .tracking(0.08)
                .foregroundStyle(theme.textFaint)
            Spacer()
            Text(value)
                .font(SightFont.mono())
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func duration(_ duration: Duration) -> String {
        let components = duration.components
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        if seconds < 1 {
            return String(format: "%.0f ms", seconds * 1000)
        }
        return String(format: "%.1f s", seconds)
    }
}
