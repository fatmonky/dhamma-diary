import SwiftUI
import SwiftData

/// The Diary tab's "Passages" mode (spec 4.2, PJ 25 Nov): every passage in
/// the app, in the order the nights bring them, with its question. Tapping
/// one opens its text and any entries written for it.
struct PassagesView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var expandedPassageID: String?

    @State private var entriesByPassage: [String: [JournalEntry]] = [:]

    private let passages = PassageSet.bundled.passages
    private let tonightID = PassageSequence.passage()?.id

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(passages.enumerated()), id: \.element.id) { index, passage in
                    Section {
                        header(for: passage, night: index + 1)
                        if expandedPassageID == passage.id {
                            PassageView(passage: passage, showsTitle: false)
                                .padding(.vertical, 6)
                            ForEach(entriesByPassage[passage.id] ?? []) { entry in
                                NavigationLink {
                                    JournalEntryDetailView(entryID: entry.persistentModelID)
                                } label: {
                                    EntryDateRow(entry: entry, lineLimit: 2)
                                }
                            }
                        }
                    }
                    .id(passage.id)
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(12)
            .onAppear {
                if let expandedPassageID {
                    proxy.scrollTo(expandedPassageID, anchor: .top)
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func header(for passage: Passage, night: Int) -> some View {
        let isOpen = expandedPassageID == passage.id
        let count = entriesByPassage[passage.id]?.count ?? 0
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedPassageID = isOpen ? nil : passage.id
            }
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Night \(night) · \(passage.ref)")
                            .foregroundStyle(.secondary)
                        if passage.id == tonightID {
                            Text("Tonight")
                                .foregroundStyle(ColorHelpers.accent)
                        }
                    }
                    .font(.caption)
                    Text(passage.title)
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(.primary)
                    Text(passage.question.questionLines)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(.secondary)
                        .lineLimit(isOpen ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)
                    if count > 0 {
                        Text("\(count) \(count == 1 ? "entry" : "entries")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isOpen ? "Hides the passage" : "Shows the passage and its entries")
    }

    private func reload() {
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.day, order: .reverse)]
        )
        let groups = PassageGroup.groups(from: modelContext.fetchOrEmpty(descriptor))
        entriesByPassage = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.entries) })
        #if DEBUG
        // For simulator screenshots: `-debug.expandFirst YES` opens the first passage.
        if UserDefaults.standard.bool(forKey: "debug.expandFirst"), expandedPassageID == nil {
            expandedPassageID = passages.first?.id
        }
        #endif
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
