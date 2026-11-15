import SwiftUI
import SwiftData

/// One journal entry, editable. Blank text deletes it. Previous/next move
/// between entries for the same passage (spec 4.2).
struct JournalEntryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let entryID: PersistentIdentifier

    @State private var editedText = ""
    @State private var currentID: PersistentIdentifier?
    @State private var didDelete = false

    private var entry: JournalEntry? {
        guard let currentID else { return nil }
        return modelContext.model(for: currentID) as? JournalEntry
    }

    var body: some View {
        Group {
            if let entry {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(DateHelpers.fullDateString(for: entry.day))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Last saved \(ReflectionDateFormatters.detailTimestamp.string(from: entry.updatedAt))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("\(entry.passageRef) · \(entry.passageTitle)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(entry.question)
                            .font(.system(.title3, design: .serif).weight(.semibold))
                    }

                    TextEditor(text: $editedText)
                        .frame(maxHeight: .infinity)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.secondarySystemBackground))
                        )

                    navigationControls(for: entry)
                }
                .padding()
                .navigationTitle("Journal Entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            save(entry, forceTimestamp: true)
                        }
                    }
                }
                .onDisappear {
                    save(entry)
                }
            } else {
                ContentUnavailableView("Entry not found", systemImage: "questionmark.circle")
            }
        }
        .onAppear {
            if currentID == nil {
                currentID = entryID
            }
            editedText = entry?.responseText ?? ""
        }
    }

    private func navigationControls(for entry: JournalEntry) -> some View {
        let siblings = JournalStore.entries(forPassage: entry.passageID, in: modelContext)
        let currentIndex = siblings.firstIndex { $0.persistentModelID == entry.persistentModelID }
        let previous = currentIndex.flatMap { $0 > 0 ? siblings[$0 - 1] : nil }
        let next = currentIndex.flatMap { $0 < siblings.count - 1 ? siblings[$0 + 1] : nil }

        return HStack {
            Button("← previous for this passage") {
                move(to: previous)
            }
            .disabled(previous == nil)
            .foregroundStyle(previous == nil ? .secondary : Color(red: 0.53, green: 0.38, blue: 0.22))
            .opacity(previous == nil ? 0.45 : 1)

            Spacer()

            Button("next for this passage →") {
                move(to: next)
            }
            .disabled(next == nil)
            .foregroundStyle(next == nil ? .secondary : Color(red: 0.53, green: 0.38, blue: 0.22))
            .opacity(next == nil ? 0.45 : 1)
        }
        .font(.footnote)
    }

    private func move(to target: JournalEntry?) {
        guard let target else { return }
        if let current = entry {
            save(current)
        }
        currentID = target.persistentModelID
        editedText = target.responseText
    }

    private func save(_ entry: JournalEntry, forceTimestamp: Bool = false) {
        guard !didDelete, entry.responseText != editedText || forceTimestamp else { return }
        if JournalStore.update(entry, text: editedText, in: modelContext) == .deleted {
            didDelete = true
            dismiss()
        }
    }
}
