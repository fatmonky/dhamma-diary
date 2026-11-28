import SwiftUI
import SwiftData

/// "This week" (spec 8.3): the week's stones and roots, then each day from
/// Monday to today with its stones and the first line of its entry. It opens
/// like Daily Review (spec 10.4): the week's stones fall into a white and a
/// black heap first, and the review fades in once they settle.
struct WeekLookBackView: View {
    @Environment(\.modelContext) private var modelContext

    /// Passed to entries opened from here; see JournalEntryDetailView.
    var showsPassageLink = false

    @State private var week: WeekLookBack?
    @State private var openEntry: PersistentIdentifier?
    /// The week's stones in logging order, for the fall.
    @State private var stoneTypes: [StoneType] = []
    @State private var settled = false

    var body: some View {
        List {
            if let week {
                StoneDropPile(
                    types: stoneTypes,
                    label: "This week's stones",
                    value: week.white + week.black > 0 ? "\(week.white) white · \(week.black) black" : "No stones this week",
                    settled: $settled
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            if let week, settled {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(week.rangeText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if week.white + week.black > 0 {
                            Text("\(week.white) white · \(week.black) black")
                                .font(.system(.title3, design: .serif).weight(.semibold))
                            if !week.roots.isEmpty {
                                Text(week.roots.map { $0.count == 1 ? $0.name : "\($0.name) ×\($0.count)" }.joined(separator: ", "))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
                .transition(.opacity)

                Section {
                    // Not NavigationLinks: a row-wide link would swallow taps on
                    // the sutta link inside it.
                    ForEach(week.days) { day in
                        if let entry = day.entry {
                            DayRow(day: day, opensEntry: true)
                                .contentShape(Rectangle())
                                .onTapGesture { openEntry = entry.persistentModelID }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAction { openEntry = entry.persistentModelID }
                        } else {
                            DayRow(day: day, opensEntry: false)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(item: $openEntry) { id in
            JournalEntryDetailView(entryID: id, showsPassageLink: showsPassageLink)
        }
        .navigationTitle("This week")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Once per visit: coming back from an entry keeps the settled heaps.
            guard week == nil else { return }
            reload()
            #if DEBUG
            // For simulator screenshots: `simctl launch … -debug.openWeek YES -debug.openEntry YES`.
            if UserDefaults.standard.bool(forKey: "debug.openEntry") {
                openEntry = week?.days.last { $0.entry != nil }?.entry?.persistentModelID
            }
            #endif
        }
    }

    private func reload() {
        let today = DateHelpers.currentReflectionDay
        let stoneInterval = WeekLookBack.stoneInterval(currentDay: today)
        let start = stoneInterval.start
        let end = stoneInterval.end
        let stones = modelContext.fetchOrEmpty(FetchDescriptor<Stone>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp)]
        ))
        let entries = JournalStore.entries(in: WeekLookBack.entryInterval(currentDay: today), in: modelContext)
        week = WeekLookBack(currentDay: today, stones: stones, entries: entries)
        stoneTypes = stones.map(\.type)
        #if DEBUG
        stoneTypes = StoneDropDebug.override(stoneTypes)
        #endif
    }
}

private struct DayRow: View {
    let day: WeekLookBack.Day
    let opensEntry: Bool

    private static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Self.weekday.string(from: day.date))
                    .font(.subheadline.weight(.semibold))
                if let entry = day.entry {
                    PassageRefLink(passageID: entry.passageID, ref: entry.passageRef, title: entry.passageTitle, font: .caption)
                        .lineLimit(1)
                    Text(firstLine(of: entry.responseText))
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            // The stone counts, and under them the day's mind line in
            // Today's style (PJ, 22 Nov). Each shows only if there is one.
            VStack(alignment: .trailing, spacing: 6) {
                if day.white > 0 || day.black > 0 {
                    HStack(spacing: 12) {
                        if day.white > 0 {
                            count(.white, day.white)
                        }
                        if day.black > 0 {
                            count(.black, day.black)
                        }
                    }
                }
                MindSparkline(day: day.date, size: CGSize(width: 128, height: 56))
            }
            if opensEntry {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
    }

    private func count(_ type: StoneType, _ n: Int) -> some View {
        HStack(spacing: 4) {
            StoneIcon(type: type, size: 12)
            Text("\(n)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("\(n) \(type.rawValue)")
    }

    private func firstLine(of text: String) -> String {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
    }
}
