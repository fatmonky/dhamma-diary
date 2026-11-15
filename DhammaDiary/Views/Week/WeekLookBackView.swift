import SwiftUI
import SwiftData

/// "This week" (spec 8.3): the week's stones and roots, then each day from
/// Monday to today with its stones and the first line of its entry.
struct WeekLookBackView: View {
    @Environment(\.modelContext) private var modelContext

    /// Passed to entries opened from here; see JournalEntryDetailView.
    var showsPassageLink = false

    @State private var week: WeekLookBack?

    var body: some View {
        List {
            if let week {
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

                Section {
                    ForEach(week.days) { day in
                        if let entry = day.entry {
                            NavigationLink {
                                JournalEntryDetailView(entryID: entry.persistentModelID, showsPassageLink: showsPassageLink)
                            } label: {
                                DayRow(day: day)
                            }
                        } else {
                            DayRow(day: day)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("This week")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
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
    }
}

private struct DayRow: View {
    let day: WeekLookBack.Day

    private static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(Self.weekday.string(from: day.date))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if day.white > 0 {
                    count(.white, day.white)
                }
                if day.black > 0 {
                    count(.black, day.black)
                }
            }
            if let entry = day.entry {
                Text("\(entry.passageRef) · \(entry.passageTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(firstLine(of: entry.responseText))
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
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
