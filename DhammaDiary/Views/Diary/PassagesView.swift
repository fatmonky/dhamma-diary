import SwiftUI
import SwiftData

/// The Diary tab's "Passages" mode (spec 4.2): past journal entries grouped
/// by passage, newest first. Tapping a passage shows its entries.
struct PassagesView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var expandedPassageID: String?

    @State private var groups: [PassageGroup] = []

    var body: some View {
        Group {
            if groups.isEmpty {
                ContentUnavailableView(
                    "No entries yet",
                    systemImage: "text.book.closed",
                    description: Text("Saved journal entries appear here, grouped by passage.")
                )
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(groups) { group in
                            Section {
                                header(for: group)
                                if expandedPassageID == group.id {
                                    ForEach(group.entries) { entry in
                                        NavigationLink {
                                            JournalEntryDetailView(entryID: entry.persistentModelID)
                                        } label: {
                                            EntryRow(entry: entry)
                                        }
                                    }
                                }
                            }
                            .id(group.id)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .onAppear {
                        if let expandedPassageID {
                            proxy.scrollTo(expandedPassageID, anchor: .top)
                        }
                    }
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func header(for group: PassageGroup) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedPassageID = expandedPassageID == group.id ? nil : group.id
            }
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.ref)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(group.title)
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(.primary)
                    Text(countText(for: group.entries.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: expandedPassageID == group.id ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(expandedPassageID == group.id ? "Hides entries" : "Shows entries")
    }

    private func reload() {
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.day, order: .reverse)]
        )
        groups = PassageGroup.groups(from: modelContext.fetchOrEmpty(descriptor))
    }

    private func countText(for count: Int) -> String {
        "\(count) \(count == 1 ? "entry" : "entries")"
    }
}

private struct EntryRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DateHelpers.fullDateString(for: entry.day))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.question.questionLines)
                .font(.system(.subheadline, design: .serif).weight(.semibold))
                .foregroundStyle(.primary)
            Text(entry.responseText)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(6)
        }
        .padding(.vertical, 4)
    }
}

/// Entries for one passage. The heading uses the newest entry's copies.
struct PassageGroup: Identifiable {
    let id: String
    let ref: String
    let title: String
    let entries: [JournalEntry]

    /// Groups entries (already sorted newest first) by passage ID,
    /// ordering groups by their newest entry.
    static func groups(from entries: [JournalEntry]) -> [PassageGroup] {
        var order: [String] = []
        var byPassage: [String: [JournalEntry]] = [:]
        for entry in entries {
            if byPassage[entry.passageID] == nil {
                order.append(entry.passageID)
            }
            byPassage[entry.passageID, default: []].append(entry)
        }
        return order.compactMap { id in
            guard let entries = byPassage[id], let newest = entries.first else { return nil }
            return PassageGroup(id: id, ref: newest.passageRef, title: newest.passageTitle, entries: entries)
        }
    }
}
