import SwiftUI
import SwiftData

/// The Diary tab's "Entries" mode (spec 4.2, PJ 25 Nov): every journal entry
/// by date, newest first. Each row shows only the date and sutta title; it
/// drops down to show the passage and question, then the entry (PJ 26 Nov),
/// which opens in full.
struct EntriesView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var entries: [JournalEntry] = []
    @State private var openPassages: Set<PersistentIdentifier> = []

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No entries yet",
                    systemImage: "text.book.closed",
                    description: Text("Saved journal entries appear here, newest first.")
                )
            } else {
                List {
                    ForEach(entries) { entry in
                        Section {
                            passageToggle(for: entry)
                            if openPassages.contains(entry.persistentModelID) {
                                if let passage = PassageSet.bundled.passage(withID: entry.passageID) {
                                    VStack(alignment: .leading, spacing: 14) {
                                        PassageView(passage: passage, showsTitle: false)
                                        Text(entry.question.questionLines)
                                            .font(.system(.headline, design: .serif))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(.vertical, 6)
                                }
                                NavigationLink {
                                    JournalEntryDetailView(entryID: entry.persistentModelID)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Your entry")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Text(entry.responseText)
                                            .font(.system(.body, design: .serif))
                                            .foregroundStyle(.primary)
                                            .lineLimit(6)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .listSectionSpacing(12)
            }
        }
        .onAppear(perform: reload)
    }

    private func passageToggle(for entry: JournalEntry) -> some View {
        let isOpen = openPassages.contains(entry.persistentModelID)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isOpen {
                    openPassages.remove(entry.persistentModelID)
                } else {
                    openPassages.insert(entry.persistentModelID)
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DateHelpers.fullDateString(for: entry.day))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("\(entry.passageRef) \(entry.passageTitle)")
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
                Spacer(minLength: 0)
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isOpen ? "Hides the sutta and entry" : "Shows the sutta and entry")
    }

    private func reload() {
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.day, order: .reverse)]
        )
        entries = modelContext.fetchOrEmpty(descriptor)
        #if DEBUG
        // For simulator screenshots: `-debug.expandFirst YES` opens the first sutta.
        if UserDefaults.standard.bool(forKey: "debug.expandFirst"), let first = entries.first {
            openPassages.insert(first.persistentModelID)
        }
        #endif
    }
}

/// The date and the start of the entry.
struct EntryDateRow: View {
    let entry: JournalEntry
    var lineLimit = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DateHelpers.fullDateString(for: entry.day))
                .font(.subheadline.weight(.semibold))
            Text(entry.responseText)
                .font(.system(.body, design: .serif))
                .foregroundStyle(.primary)
                .lineLimit(lineLimit)
        }
        .padding(.vertical, 4)
    }
}
