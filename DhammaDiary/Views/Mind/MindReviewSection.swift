import SwiftUI
import SwiftData
import Charts

/// "Mind today" at the top of Review (spec 9.6): the day's check-ins as a
/// chart, the summary line, the list, and the check-in notifications switch.
struct MindReviewSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var checks: [MindCheck]
    @State private var status: MindCheckNotifications.Status = .off

    let day: Date
    private let accent = ColorHelpers.accent

    init(day: Date) {
        self.day = day
        let interval = DateHelpers.reflectionDayInterval(forDay: day)
        let start = interval.start
        let end = interval.end
        _checks = Query(
            filter: #Predicate<MindCheck> { $0.timestamp >= start && $0.timestamp < end },
            sort: \.timestamp
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mind today")
                .font(.headline)

            if let summary = MindDaySummary(checks: checks) {
                MindDayChart(checks: checks, day: day)
                    .frame(height: 140)
                Text(summary.text())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    ForEach(checks.reversed()) { check in
                        MindCheckRow(check: check)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button(role: .destructive) {
                                    modelContext.delete(check)
                                    try? modelContext.save()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        if check.id != checks.first?.id {
                            Divider()
                        }
                    }
                }
            } else {
                Text("No check-ins yet today. On Today, press the stone and slide up or down to note how noisy your mind is.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            notificationsControl
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
        .padding(.horizontal)
        .onAppear(perform: refreshStatus)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshStatus() }
        }
    }

    // MARK: - Notifications

    @ViewBuilder
    private var notificationsControl: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            switch status {
            case .off:
                Text("Reminders are off.")
                    .foregroundStyle(.secondary)
                Button("Remind me 3 times a day") {
                    Task { status = await MindCheckNotifications.start() }
                }
                .foregroundStyle(accent)
            case .on:
                Text("Reminders: 3 a day, at random, 9am–9pm.")
                    .foregroundStyle(.secondary)
                Button("Stop") {
                    Task {
                        await MindCheckNotifications.stop()
                        status = .off
                    }
                }
                .foregroundStyle(accent)
            case .blocked:
                Text("Notifications are off in Settings.")
                    .foregroundStyle(.secondary)
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    Link("Open Settings", destination: url)
                        .foregroundStyle(accent)
                }
                Button("Stop") {
                    Task {
                        await MindCheckNotifications.stop()
                        status = .off
                    }
                }
                .foregroundStyle(accent)
            }
        }
        .font(.footnote)
        .buttonStyle(.plain)
    }

    private func refreshStatus() {
        Task { status = await MindCheckNotifications.status() }
    }
}

enum MindCheckStore {
    /// The check-ins of the reflection day `day`, earliest first.
    static func checks(onDay day: Date, in context: ModelContext) -> [MindCheck] {
        let interval = DateHelpers.reflectionDayInterval(forDay: day)
        let start = interval.start
        let end = interval.end
        let descriptor = FetchDescriptor<MindCheck>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return context.fetchOrEmpty(descriptor)
    }
}

/// The day's check-ins as points across the day, still at the bottom and
/// noisy at the top.
struct MindDayChart: View {
    let checks: [MindCheck]
    let day: Date

    var body: some View {
        Chart(checks) { check in
            LineMark(x: .value("Time", check.timestamp), y: .value("Noise", check.noise))
                .foregroundStyle(ColorHelpers.accent.opacity(0.3))
                .interpolationMethod(.monotone)
            PointMark(x: .value("Time", check.timestamp), y: .value("Noise", check.noise))
                .foregroundStyle(ColorHelpers.accent)
                .symbolSize(60)
        }
        .chartXScale(domain: MindDayChart.domain(for: checks.map(\.timestamp), day: day))
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    Text(value.as(Double.self) == 0 ? "Still" : "Noisy")
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .accessibilityLabel("Today's check-ins")
        .accessibilityValue(MindDaySummary(checks: checks)?.text() ?? "")
    }

    /// At least 7am to 11pm, widened for check-ins outside it.
    static func domain(for times: [Date], day: Date) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        var lower = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: start)!
        var upper = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: start)!
        if let first = times.min() { lower = min(lower, first) }
        if let last = times.max() { upper = max(upper, last) }
        return lower...upper
    }
}

/// The outline of the day's noisy–still chart, small, beside Today's
/// stone counts. Tapping it opens Review.
struct MindSparkline: View {
    @Query private var checks: [MindCheck]
    let day: Date

    init(day: Date) {
        self.day = day
        let interval = DateHelpers.reflectionDayInterval(forDay: day)
        let start = interval.start
        let end = interval.end
        _checks = Query(
            filter: #Predicate<MindCheck> { $0.timestamp >= start && $0.timestamp < end },
            sort: \.timestamp
        )
    }

    var body: some View {
        let domain = MindDayChart.domain(for: checks.map(\.timestamp), day: day)
        let span = domain.upperBound.timeIntervalSince(domain.lowerBound)

        Canvas { context, size in
            let inset: CGFloat = 5
            let width = size.width - inset * 2
            let height = size.height - inset * 2
            let points = checks.map { check in
                CGPoint(
                    x: inset + width * check.timestamp.timeIntervalSince(domain.lowerBound) / span,
                    y: inset + height * (1 - check.noise / 100)
                )
            }
            // A faint midline, so an empty day still reads as a chart.
            var mid = Path()
            mid.move(to: CGPoint(x: inset, y: size.height / 2))
            mid.addLine(to: CGPoint(x: size.width - inset, y: size.height / 2))
            context.stroke(mid, with: .color(.secondary.opacity(0.25)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))

            if points.count > 1 {
                var line = Path()
                line.addLines(points)
                context.stroke(line, with: .color(ColorHelpers.accent.opacity(0.5)), lineWidth: 1)
            }
            for point in points {
                context.fill(Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)), with: .color(ColorHelpers.accent))
            }
        }
        .frame(width: 72, height: 30)
        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.4), lineWidth: 0.75))
        .accessibilityElement()
        .accessibilityLabel("Mind today")
        .accessibilityValue(MindDaySummary(checks: checks)?.text() ?? "No check-ins yet")
    }
}

struct MindCheckRow: View {
    let check: MindCheck

    var body: some View {
        HStack(spacing: 12) {
            Text(DateHelpers.timeString(for: check.timestamp))
                .font(.subheadline.monospacedDigit())
                .frame(width: 76, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule()
                        .fill(ColorHelpers.accent.opacity(0.7))
                        .frame(width: max(proxy.size.width * check.noise / 100, 6))
                }
            }
            .frame(height: 6)
            Text(MindDaySummary.word(for: check.noise))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(DateHelpers.timeString(for: check.timestamp)), \(MindDaySummary.word(for: check.noise))")
        .accessibilityHint("Touch and hold for Delete")
    }
}
