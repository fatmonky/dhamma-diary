import SwiftUI
import WidgetKit

/// A short excerpt from tonight's passage on the Home Screen (spec 8.6).
/// The large size adds the question underneath. Like the question widget, it
/// shows no stones and no journal text.
struct PassageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TonightPassage", provider: PassageProvider()) { entry in
            PassageWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
                .widgetURL(URL(string: "dhammadiary://tonight"))
        }
        .configurationDisplayName("Tonight's passage")
        .description("A few lines from this evening's sutta passage.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct PassageEntry: TimelineEntry {
    let date: Date
    let ref: String
    let excerpt: String
    let question: String
}

struct PassageProvider: TimelineProvider {
    func placeholder(in context: Context) -> PassageEntry {
        PassageEntry(
            date: .now,
            ref: "AN 10.51",
            excerpt: "Suppose there was a woman or man who was young, youthful, and fond of adornments, and they check their own reflection in a clean bright mirror or a clear bowl of water. If they see any dirt or blemish there, they’d try to remove it.",
            question: "Look back at today as if in a clear mirror: which of these qualities did you see in yourself, and which did you not?"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PassageEntry) -> Void) {
        completion(entry(at: .now) ?? placeholder(in: context))
    }

    /// One entry now and one at the next 03:00, when the passage changes.
    func getTimeline(in context: Context, completion: @escaping (Timeline<PassageEntry>) -> Void) {
        let now = Date.now
        let next = DateHelpers.reflectionDayInterval(for: now).end
        let entries = [entry(at: now), entry(at: next)].compactMap { $0 }
        completion(Timeline(entries: entries.isEmpty ? [placeholder(in: context)] : entries, policy: .after(next)))
    }

    private func entry(at date: Date) -> PassageEntry? {
        let day = DateHelpers.reflectionDay(for: date)
        guard let passage = PassageSequence.passage(for: day) else { return nil }
        return PassageEntry(
            date: date,
            ref: passage.ref,
            excerpt: passage.excerpt.joined(separator: " "),
            question: passage.question
        )
    }
}

struct PassageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PassageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 10 : 6) {
            Text("TONIGHT · \(entry.ref)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color("AccentColor"))
                .tracking(0.5)
                .lineLimit(1)

            Text(entry.excerpt)
                .font(.system(family == .systemLarge ? .body : .subheadline, design: .serif).italic())
                .lineSpacing(2)
                .foregroundStyle(.primary)
                .lineLimit(family == .systemLarge ? 9 : 5)
                .minimumScaleFactor(0.85)

            if family == .systemLarge {
                Spacer(minLength: 0)
                Divider()
                Text(entry.question)
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(5)
                    .minimumScaleFactor(0.85)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

#Preview(as: .systemMedium) {
    PassageWidget()
} timeline: {
    PassageEntry(
        date: .now,
        ref: "AN 4.14",
        excerpt: "When a mendicant sees a sight with their eyes, they don’t get caught up in the features and details.",
        question: "When you saw, heard, smelled, tasted, touched or thought of something today, where did you get caught up in its features and details?"
    )
}
