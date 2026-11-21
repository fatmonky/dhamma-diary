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
    @State private var perDay = MindCheckNotifications.perDay

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
                MindDayChart(checks: checks, day: day, zoomable: true)
                    .frame(height: 140)
                Text("Pinch to zoom in on part of the day. Double-tap to see it all.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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
                Button("Turn on") {
                    Task { status = await MindCheckNotifications.start() }
                }
                .foregroundStyle(accent)
            case .on:
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Reminders:")
                        .foregroundStyle(.secondary)
                    perDayMenu
                    Text("9am–9pm")
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
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

    /// "3 a day ⌄": how many reminders a day, 1–6.
    private var perDayMenu: some View {
        Menu {
            Picker("Reminders a day", selection: $perDay) {
                ForEach(MindCheckSchedule.perDayRange.reversed(), id: \.self) { count in
                    Text(count == 1 ? "Once a day" : "\(count) times a day").tag(count)
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text("\(perDay) a day")
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
            }
            .foregroundStyle(accent)
        }
        .onChange(of: perDay) { _, count in
            Task { await MindCheckNotifications.setPerDay(count) }
        }
        .accessibilityLabel("Reminders a day: \(perDay)")
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
/// noisy at the top. With `zoomable`, pinch to zoom the time axis; once
/// zoomed, drag sideways to move along the day; double-tap to zoom out.
struct MindDayChart: View {
    let checks: [MindCheck]
    let day: Date
    var zoomable = false

    /// Seconds of the day on screen; nil shows the whole day.
    @State private var visibleLength: TimeInterval?
    @State private var lengthAtPinchStart: TimeInterval?
    @State private var scrollStart: Date = .distantPast

    /// Closest zoom: half an hour across the chart.
    private static let shortestLength: TimeInterval = 30 * 60

    var body: some View {
        let domain = Self.domain(for: checks.map(\.timestamp), day: day)
        let full = domain.upperBound.timeIntervalSince(domain.lowerBound)
        let length = min(visibleLength ?? full, full)

        Chart(checks) { check in
            LineMark(x: .value("Time", check.timestamp), y: .value("Noise", check.noise))
                .foregroundStyle(ColorHelpers.accent.opacity(0.3))
                .interpolationMethod(.monotone)
            PointMark(x: .value("Time", check.timestamp), y: .value("Noise", check.noise))
                .foregroundStyle(ColorHelpers.accent)
                .symbolSize(60)
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: 0...100)
        .chartScrollableAxes(length < full ? .horizontal : [])
        .chartXVisibleDomain(length: length)
        .chartScrollPosition(x: $scrollStart)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    Text(value.as(Double.self) == 0 ? "Still" : "Noisy")
                }
            }
        }
        .chartXAxis {
            if length > 6 * 3600 {
                AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour())
                }
            } else if length > 2 * 3600 {
                AxisMarks(values: .stride(by: .hour, count: 1)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour())
                }
            } else {
                AxisMarks(values: .stride(by: .minute, count: 15)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
        }
        .simultaneousGesture(zoomable ? pinch(domain: domain, full: full, length: length) : nil)
        .onTapGesture(count: 2) {
            guard zoomable else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                visibleLength = nil
                scrollStart = domain.lowerBound
            }
        }
        .onAppear {
            if scrollStart < domain.lowerBound { scrollStart = domain.lowerBound }
        }
        .accessibilityLabel("Today's check-ins")
        .accessibilityValue(MindDaySummary(checks: checks)?.text() ?? "")
    }

    /// Pinching out zooms in around the middle of what's on screen.
    private func pinch(domain: ClosedRange<Date>, full: TimeInterval, length: TimeInterval) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = lengthAtPinchStart ?? length
                lengthAtPinchStart = start
                let newLength = min(max(start / value.magnification, Self.shortestLength), full)
                let currentStart = max(scrollStart, domain.lowerBound)
                let middle = currentStart.addingTimeInterval(min(length, full) / 2)
                let latestStart = domain.upperBound.addingTimeInterval(-newLength)
                let newStart = min(max(middle.addingTimeInterval(-newLength / 2), domain.lowerBound), latestStart)
                visibleLength = newLength >= full ? nil : newLength
                scrollStart = newStart
            }
            .onEnded { _ in
                lengthAtPinchStart = nil
            }
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

/// The shape of the day's noisy–still line, under Today's stone counts:
/// just the line, no frame or dots. Nothing shows before the first
/// check-in. Tapping it opens Review.
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
            let inset: CGFloat = 2
            let width = size.width - inset * 2
            let height = size.height - inset * 2
            let points = checks.map { check in
                CGPoint(
                    x: inset + width * check.timestamp.timeIntervalSince(domain.lowerBound) / span,
                    y: inset + height * (1 - check.noise / 100)
                )
            }
            let colour = GraphicsContext.Shading.color(ColorHelpers.accent)
            if points.count > 1 {
                var line = Path()
                line.addLines(points)
                context.stroke(line, with: colour, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            } else if let point = points.first {
                // One check-in: a mark the width of the line.
                context.fill(Path(ellipseIn: CGRect(x: point.x - 1.5, y: point.y - 1.5, width: 3, height: 3)), with: colour)
            }
        }
        .frame(width: 200, height: checks.isEmpty ? 0 : 30)
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
