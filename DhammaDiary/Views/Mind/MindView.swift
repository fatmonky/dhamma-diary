import SwiftUI
import SwiftData
import Charts

/// The Mind tab (spec 9): "How noisy is your mind now?", a vertical slide
/// between noisy and still, and the day's check-ins as a chart.
struct MindView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    /// True while the check-in on screen was opened from a notification.
    @Binding var openedFromNotification: Bool

    @State private var noise: Double = 50
    @State private var checks: [MindCheck] = []
    @State private var day = DateHelpers.currentReflectionDay
    @State private var lastRecordedAt: Date?
    @State private var status: MindCheckNotifications.Status = .off

    private let accent = ColorHelpers.accent

    var body: some View {
        VStack(spacing: 0) {
            // Kept out of the scrolling list, so dragging the slider never scrolls.
            checkIn
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)

            List {
                Section {
                    if let summary = MindDaySummary(checks: checks) {
                        MindDayChart(checks: checks, day: day)
                            .frame(height: 150)
                            .padding(.vertical, 6)
                        Text(summary.text())
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No check-ins yet today. The chart fills in as the day goes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Today")
                }

                if !checks.isEmpty {
                    Section {
                        ForEach(checks.reversed()) { check in
                            MindCheckRow(check: check)
                        }
                        .onDelete(perform: delete)
                    }
                }

                Section {
                    notificationsControl
                } header: {
                    Text("Check-ins")
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Mind")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            #if DEBUG
            seedForScreenshots()
            #endif
            reload()
            refreshStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                reload()
                refreshStatus()
            }
        }
        .onChange(of: openedFromNotification) { _, opened in
            // Each notification starts from the middle.
            if opened {
                noise = 50
                lastRecordedAt = nil
            }
        }
    }

    // MARK: - Check-in

    private var checkIn: some View {
        VStack(spacing: 12) {
            Text(MindCheckNotifications.question)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .center, spacing: 18) {
                VStack {
                    Text("Noisy")
                    Spacer()
                    Text("Still")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

                NoiseSlider(value: $noise)
                    .frame(width: 84)

                Text(MindDaySummary.word(for: noise))
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(.secondary)
                    .frame(width: 110, alignment: .leading)
                    .accessibilityHidden(true)
            }
            .frame(height: 230)

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Button("Record", action: record)
                    .buttonStyle(.borderedProminent)
                    .tint(accent)

                if let lastRecordedAt {
                    Text("Recorded at \(DateHelpers.timeString(for: lastRecordedAt)).")
                        .font(.footnote.italic())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Notifications

    @ViewBuilder
    private var notificationsControl: some View {
        switch status {
        case .off:
            Text("Three times a day, at a random moment between 9am and 9pm, the phone can ask how noisy your mind is.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Start check-ins") {
                Task { status = await MindCheckNotifications.start() }
            }
            .foregroundStyle(accent)
        case .on:
            Text("On: three times a day, at random, between 9am and 9pm.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Stop check-ins") {
                Task {
                    await MindCheckNotifications.stop()
                    status = .off
                }
            }
            .foregroundStyle(accent)
        case .blocked:
            Text("Notifications for Dhamma Diary are off in Settings, so the check-ins can't arrive.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                Link("Open Settings", destination: url)
                    .foregroundStyle(accent)
            }
            Button("Stop check-ins") {
                Task {
                    await MindCheckNotifications.stop()
                    status = .off
                }
            }
            .foregroundStyle(accent)
        }
    }

    private func refreshStatus() {
        Task { status = await MindCheckNotifications.status() }
    }

    // MARK: - Loading and saving

    private func reload() {
        day = DateHelpers.currentReflectionDay
        checks = MindCheckStore.checks(onDay: day, in: modelContext)
    }

    private func record() {
        let check = MindCheck(noise: noise, prompted: openedFromNotification)
        modelContext.insert(check)
        try? modelContext.save()
        lastRecordedAt = check.timestamp
        openedFromNotification = false
        noise = 50
        reload()
    }

    #if DEBUG
    /// For simulator screenshots on a throwaway simulator:
    /// `simctl launch … -debug.seedMind YES` adds three check-ins today.
    private func seedForScreenshots() {
        guard UserDefaults.standard.bool(forKey: "debug.seedMind"),
              MindCheckStore.checks(onDay: DateHelpers.currentReflectionDay, in: modelContext).isEmpty else { return }
        let start = Calendar.current.startOfDay(for: DateHelpers.currentReflectionDay)
        for (hour, minute, noise) in [(9, 40, 82.0), (14, 10, 18.0), (19, 25, 47.0)] {
            let time = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: start)!
            modelContext.insert(MindCheck(timestamp: time, noise: noise, prompted: true))
        }
        try? modelContext.save()
    }
    #endif

    private func delete(at offsets: IndexSet) {
        let shown = Array(checks.reversed())
        for index in offsets {
            modelContext.delete(shown[index])
        }
        try? modelContext.save()
        reload()
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

// MARK: - Pieces

/// A tall slider: drag up for noisy, down for still. No numbers.
struct NoiseSlider: View {
    @Binding var value: Double

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let fill = height * value / 100

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color(.secondarySystemBackground))
                Capsule()
                    .fill(ColorHelpers.accent.opacity(0.85))
                    .frame(height: max(fill, proxy.size.width))
                    .opacity(value < 1 ? 0.35 : 1)
            }
            .overlay(Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 0.5))
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let fraction = 1 - drag.location.y / height
                        value = min(max(fraction, 0), 1) * 100
                    }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("How noisy is your mind")
        .accessibilityValue(MindDaySummary.word(for: value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 10, 100)
            case .decrement: value = max(value - 10, 0)
            @unknown default: break
            }
        }
    }
}

/// The day's check-ins as points across the day, still at the bottom and
/// noisy at the top.
struct MindDayChart: View {
    let checks: [MindCheck]
    let day: Date

    /// At least 7am to 11pm, widened for check-ins outside it.
    private var domain: ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        var lower = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: start)!
        var upper = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: start)!
        if let first = checks.first?.timestamp { lower = min(lower, first) }
        if let last = checks.last?.timestamp { upper = max(upper, last) }
        return lower...upper
    }

    var body: some View {
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
}

private struct MindCheckRow: View {
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
    }
}
