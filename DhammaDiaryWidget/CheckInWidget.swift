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
        .supportedFamilies([.systemSmall, .systemMedium])
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
        if family == .systemSmall {
            small
        } else {
            medium
        }
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
                notedLine(entry.mindNoted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                heading("Log stone?")
                Spacer(minLength: 0)
                HStack(spacing: 16) {
                    stoneButton(white: true)
                    stoneButton(white: false)
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                notedLine(entry.stoneNoted)
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

    /// Always takes its line, so the halves don't shift after a tap.
    private func notedLine(_ noted: Date?) -> some View {
        Text(noted.map { "Noted at \(DateHelpers.timeString(for: $0))." } ?? " ")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
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

    private func stoneButton(white: Bool) -> some View {
        Button(intent: LogStoneIntent(white: white)) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: white
                            ? [Color(white: 1), Color(white: 0.78)]
                            : [Color(white: 0.38), Color(white: 0.06)],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 1,
                        endRadius: 34
                    )
                )
                .overlay(Circle().stroke(Color.secondary.opacity(0.45), lineWidth: 0.75))
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(white ? "Log a white stone" : "Log a black stone")
    }
}

/// Control Center, Lock Screen and Action button (spec 9.8). Controls can
/// only be buttons or toggles, so each level is its own control; place them
/// side by side. The icons are custom symbols from
/// scripts/icon/make_control_symbols.py.
@available(iOS 18.0, *)
struct MindCheckInControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.whitestone.DhammaDiary.MindCheckInControl") {
            ControlWidgetButton(action: OpenTodayIntent()) {
                Label("Mind check-in", image: "stone.book")
            }
        }
        .displayName("Mind check-in")
        .description("Opens Today, ready to slide the stone.")
    }
}

@available(iOS 18.0, *)
struct MindStillControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        mindLevelControl(kind: "com.whitestone.DhammaDiary.MindStillControl", title: "Still", symbol: "mind.still", noise: 10)
    }
}

@available(iOS 18.0, *)
struct MindBetweenControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        mindLevelControl(kind: "com.whitestone.DhammaDiary.MindBetweenControl", title: "In between", symbol: "mind.between", noise: 50)
    }
}

@available(iOS 18.0, *)
struct MindNoisyControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        mindLevelControl(kind: "com.whitestone.DhammaDiary.MindNoisyControl", title: "Noisy", symbol: "mind.noisy", noise: 90)
    }
}

/// One tap notes this level, without opening the app.
@available(iOS 18.0, *)
private func mindLevelControl(kind: String, title: String, symbol: String, noise: Double) -> some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: kind) {
        ControlWidgetButton(action: LogMindCheckIntent(noise: noise)) {
            Label(title, image: symbol)
        }
    }
    .displayName("Mind: \(title)")
    .description("Notes that your mind is \(title.lowercased()) now, without opening the app.")
}

#Preview(as: .systemMedium) {
    CheckInWidget()
} timeline: {
    CheckInEntry(date: .now, mindNoted: .now, stoneNoted: nil)
}
