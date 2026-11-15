import SwiftUI
import SwiftData

/// Past journal entries grouped by passage, newest first.
/// Step 5 of the build turns this into the Diary tab's "Passages" mode.
struct ByQuestionView: View {
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
                List {
                    ForEach(groups) { group in
                        Section {
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
                                            .font(.subheadline.weight(.semibold))
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
                            }
                            .buttonStyle(.plain)

                            if expandedPassageID == group.id {
                                ForEach(group.entries) { entry in
                                    NavigationLink {
                                        ReflectionDetailView(entryID: entry.persistentModelID)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(DateHelpers.fullDateString(for: entry.day))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(entry.question)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                            Text(entry.responseText)
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.day, order: .reverse)]
        )
        groups = PassageGroup.groups(from: modelContext.fetchOrEmpty(descriptor))
    }

    private func countText(for count: Int) -> String {
        "\(count) \(count == 1 ? "entry" : "entries")."
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
