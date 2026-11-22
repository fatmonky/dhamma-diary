import AppIntents
import SwiftUI
import WidgetKit

/// Check in, or log a stone, from the Home Screen (spec 9.8). Taps are
/// queued for the app to import; nothing about the mind or stones is shown
/// except the time of the last tap.
struct CheckInWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MindCheckIn", provider: CheckInProvider()) { entry in
            CheckInWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
                .widgetURL(URL(string: "dhammadiary://today"))
        }
        .configurationDisplayName("Mind check-in")
        .description("Note how noisy your mind is, or log a stone, without opening the app.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct CheckInEntry: TimelineEntry {
    let date: Date
    /// The last check-in tap and the last stone tap, if they were in the
    /// current reflection day.
    let mindNoted: Date?
    let stoneNoted: Date?
}

struct CheckInProvider: TimelineProvider {
    func placeholder(in context: Context) -> CheckInEntry {
        CheckInEntry(date: .now, mindNoted: nil, stoneNoted: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CheckInEntry) -> Void) {
        completion(entry(at: .now))
    }

    /// Reloaded after every tap; otherwise the "Noted" lines clear at 03:00.
    func getTimeline(in context: Context, completion: @escaping (Timeline<CheckInEntry>) -> Void) {
        let now = Date.now
        let next = DateHelpers.reflectionDayInterval(for: now).end
        completion(Timeline(entries: [entry(at: now), entry(at: next)], policy: .after(next)))
    }

    private func entry(at date: Date) -> CheckInEntry {
        let today = DateHelpers.reflectionDayInterval(for: date)
        func noted(_ group: WidgetLogQueue.NotedGroup) -> Date? {
            WidgetLogQueue.lastNoted(group).flatMap { today.contains($0) ? $0 : nil }
        }
        return CheckInEntry(date: date, mindNoted: noted(.mind), stoneNoted: noted(.stone))
    }
}

struct CheckInWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CheckInEntry

    private let accent = Color("AccentColor")

    var body: some View {
        switch family {
        case .systemSmall: small
        case .accessoryRectangular: lockScreen
        default: medium
        }
    }

    /// Lock Screen: the question and three buttons in one row. Drawn in the
    /// Lock Screen's single tint, so the buttons are outlined, not coloured.
    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Noisy mind?")
                    .font(.system(.footnote, design: .serif).weight(.semibold))
                Spacer(minLength: 4)
                if let noted = entry.mindNoted {
                    Text(DateHelpers.timeString(for: noted))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Noted at \(DateHelpers.timeString(for: noted))")
                }
            }
            .lineLimit(1)
            HStack(spacing: 4) {
                lockScreenButton("Noisy", noise: 90)
                lockScreenButton("Between", noise: 50)
                lockScreenButton("Still", noise: 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func lockScreenButton(_ title: String, noise: Double) -> some View {
        Button(intent: LogMindCheckIntent(noise: noise)) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.primary.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mind: \(title == "Between" ? "in between" : title.lowercased())")
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How noisy is your mind now?")
                .font(.system(.footnote, design: .serif).weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            mindButtons
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Two halves: the check-in on the left, the stones on the right, each
    /// with its own "Noted at …" line.
    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                heading("Noisy mind?")
                mindButtons
                Spacer(minLength: 0)
                NotedLine(noted: entry.mindNoted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                heading("Log stone?")
                Spacer(minLength: 0)
                HStack(spacing: 16) {
                    StoneButton(white: true)
                    StoneButton(white: false)
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                NotedLine(noted: entry.stoneNoted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .serif).weight(.semibold))
            .lineLimit(1)
    }

    private var mindButtons: some View {
        VStack(spacing: 4) {
            mindButton("Noisy", noise: 90)
            mindButton("In between", noise: 50)
            mindButton("Still", noise: 10)
        }
    }

    private func mindButton(_ title: String, noise: Double) -> some View {
        Button(intent: LogMindCheckIntent(noise: noise)) {
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(Capsule().fill(accent.opacity(0.14)))
                .foregroundStyle(accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mind: \(title.lowercased())")
    }
}

/// "Noted at 14:10." Always takes its line, so the layout doesn't shift after a tap.
struct NotedLine: View {
    let noted: Date?

    var body: some View {
        Text(noted.map { "Noted at \(DateHelpers.timeString(for: $0))." } ?? " ")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

/// A white or black stone that logs itself when tapped.
struct StoneButton: View {
    let white: Bool
    var size: CGFloat = 52

    var body: some View {
        Button(intent: LogStoneIntent(white: white)) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: white
                            ? [Color(white: 1), Color(white: 0.78)]
                            : [Color(white: 0.38), Color(white: 0.06)],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 1,
                        endRadius: size * 0.65
                    )
                )
                .overlay(Circle().stroke(Color.secondary.opacity(0.45), lineWidth: 0.75))
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(white ? "Log a white stone" : "Log a black stone")
    }
}

/// Log a white or black stone (spec 8.9): a small Home Screen widget, and a
/// round Lock Screen one where the white stone is a ring and the black stone
/// a filled disc, since the Lock Screen draws everything in one tint.
struct LogStoneWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LogStone", provider: CheckInProvider()) { entry in
            LogStoneWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
                .widgetURL(URL(string: "dhammadiary://today"))
        }
        .configurationDisplayName("Log a stone")
        .description("Log a white or black stone without opening the app.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct LogStoneWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CheckInEntry

    var body: some View {
        if family == .accessoryCircular {
            circular
        } else {
            small
        }
    }

    /// Simplified (for example on CarPlay): just the two stones, larger, to
    /// tap at a glance.
    private var small: some View {
        SimplifiedReader { simplified in
            if simplified {
                HStack(spacing: 12) {
                    StoneButton(white: true, size: 62)
                    StoneButton(white: false, size: 62)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                detailedSmall
            }
        }
    }

    private var detailedSmall: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Log stone?")
                .font(.system(.subheadline, design: .serif).weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack(spacing: 14) {
                StoneButton(white: true)
                StoneButton(white: false)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            NotedLine(noted: entry.stoneNoted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            HStack(spacing: 5) {
                Button(intent: LogStoneIntent(white: true)) {
                    Circle()
                        .strokeBorder(lineWidth: 2.5)
                        .frame(width: 24, height: 24)
                        .padding(2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log a white stone")

                Button(intent: LogStoneIntent(white: false)) {
                    Circle()
                        .frame(width: 24, height: 24)
                        .padding(2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log a black stone")
            }
        }
    }
}

#Preview(as: .systemMedium) {
    CheckInWidget()
} timeline: {
    CheckInEntry(date: .now, mindNoted: .now, stoneNoted: nil)
}
