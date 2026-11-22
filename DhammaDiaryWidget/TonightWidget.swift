import SwiftUI
import WidgetKit

/// Tonight's question on the Home Screen and Lock Screen (spec 8.4).
/// It shows no stones and no journal text: the Lock Screen is visible to others.
@main
struct DhammaDiaryWidgets: WidgetBundle {
    var body: some Widget {
        TonightWidget()
        PassageWidget()
        HighlightWidget()
        CheckInWidget()
        LogStoneWidget()
    }
}

struct TonightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TonightQuestion", provider: TonightProvider()) { entry in
            TonightWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
                .widgetURL(URL(string: "dhammadiary://tonight"))
        }
        .configurationDisplayName("Tonight's question")
        .description("The question for this evening's passage.")
        .supportedFamilies([.systemMedium, .accessoryRectangular])
    }
}

struct TonightEntry: TimelineEntry {
    let date: Date
    let ref: String
    let question: String
}

struct TonightProvider: TimelineProvider {
    func placeholder(in context: Context) -> TonightEntry {
        TonightEntry(
            date: .now,
            ref: "AN 10.51",
            question: "Look back at today as if in a clear mirror: which of these qualities did you see in yourself, and which did you not?"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TonightEntry) -> Void) {
        completion(entry(at: .now) ?? placeholder(in: context))
    }

    /// One entry now and one at the next 03:00, when the passage changes.
    func getTimeline(in context: Context, completion: @escaping (Timeline<TonightEntry>) -> Void) {
        let now = Date.now
        let next = DateHelpers.reflectionDayInterval(for: now).end
        let entries = [entry(at: now), entry(at: next)].compactMap { $0 }
        completion(Timeline(entries: entries.isEmpty ? [placeholder(in: context)] : entries, policy: .after(next)))
    }

    private func entry(at date: Date) -> TonightEntry? {
        let day = DateHelpers.reflectionDay(for: date)
        guard let passage = PassageSequence.passage(for: day) else { return nil }
        return TonightEntry(date: date, ref: passage.ref, question: passage.question)
    }
}

struct TonightWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TonightEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            Text(entry.question)
                .font(.system(.footnote, design: .serif).weight(.semibold))
                .lineLimit(3)
                .accessibilityLabel("Tonight's question: \(entry.question)")
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text("TONIGHT · \(entry.ref)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color("AccentColor"))
                    .tracking(0.5)
                Text(entry.question)
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(4)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview(as: .systemMedium) {
    TonightWidget()
} timeline: {
    TonightEntry(date: .now, ref: "AN 10.51", question: "Look back at today as if in a clear mirror: which of these qualities did you see in yourself, and which did you not?")
}
