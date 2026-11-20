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
    /// The last widget tap, if it was in the current reflection day.
    let lastNoted: Date?
}

struct CheckInProvider: TimelineProvider {
    func placeholder(in context: Context) -> CheckInEntry {
        CheckInEntry(date: .now, lastNoted: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CheckInEntry) -> Void) {
        completion(entry(at: .now))
    }

    /// Reloaded after every tap; otherwise the "Noted" line clears at 03:00.
    func getTimeline(in context: Context, completion: @escaping (Timeline<CheckInEntry>) -> Void) {
        let now = Date.now
        let next = DateHelpers.reflectionDayInterval(for: now).end
        completion(Timeline(entries: [entry(at: now), entry(at: next)], policy: .after(next)))
    }

    private func entry(at date: Date) -> CheckInEntry {
        let today = DateHelpers.reflectionDayInterval(for: date)
        let noted = WidgetLogQueue.lastNoted().flatMap { today.contains($0) ? $0 : nil }
        return CheckInEntry(date: date, lastNoted: noted)
    }
}

struct CheckInWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CheckInEntry

    private let accent = Color("AccentColor")

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
            Text("How noisy is your mind now?")
                .font(.system(family == .systemSmall ? .footnote : .subheadline, design: .serif).weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if family == .systemSmall {
                VStack(spacing: 4) {
                    mindButton("Noisy", noise: 90)
                    mindButton("In between", noise: 50)
                    mindButton("Still", noise: 10)
                }
            } else {
                HStack(spacing: 6) {
                    mindButton("Still", noise: 10)
                    mindButton("In between", noise: 50)
                    mindButton("Noisy", noise: 90)
                }

                HStack(spacing: 10) {
                    Text("Log a stone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    stoneButton(white: true)
                    stoneButton(white: false)
                }

                if let noted = entry.lastNoted {
                    Text("Noted at \(DateHelpers.timeString(for: noted)).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func mindButton(_ title: String, noise: Double) -> some View {
        Button(intent: LogMindCheckIntent(noise: noise)) {
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, family == .systemSmall ? 4 : 6)
                .background(Capsule().fill(accent.opacity(0.14)))
                .foregroundStyle(accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mind: \(title.lowercased())")
    }

    private func stoneButton(white: Bool) -> some View {
        Button(intent: LogStoneIntent(white: white)) {
            Circle()
                .fill(white ? Color(white: 0.92) : Color(white: 0.15))
                .overlay(Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 0.75))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(white ? "Log a white stone" : "Log a black stone")
    }
}

/// Control Center, Lock Screen and Action button: opens Today (spec 9.8).
@available(iOS 18.0, *)
struct MindCheckInControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.whitestone.DhammaDiary.MindCheckInControl") {
            ControlWidgetButton(action: OpenTodayIntent()) {
                Label("Mind check-in", systemImage: "waveform")
            }
        }
        .displayName("Mind check-in")
        .description("Opens Today, ready to slide the stone.")
    }
}

#Preview(as: .systemMedium) {
    CheckInWidget()
} timeline: {
    CheckInEntry(date: .now, lastNoted: .now)
}
