import SwiftUI
import SwiftData

/// The Diary tab's "Tonight" mode (spec 4.2): the day's stones, tonight's
/// passage and question, and the journal entry for the current reflection day.
struct TonightView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    /// Opens Passages at this passage's earlier entries.
    var onOpenPassageHistory: (String) -> Void = { _ in }

    /// The reflection day on screen. It follows the clock, except that it
    /// waits while there's unsaved text so a 3am rollover can't wipe it.
    @State private var day = DateHelpers.currentReflectionDay
    @State private var passage: Passage?
    @State private var entry: JournalEntry?
    @State private var stoneSummary: StoneDaySummary?
    @State private var earlierEntryCount = 0

    /// Held by DiaryView so unsaved text survives switching to Passages.
    @Binding var text: String
    @State private var savedText = ""
    @State private var lastSavedAt: Date?
    @State private var dayEndedBeforeSave = false
    @FocusState private var isEditorFocused: Bool

    private let accent = ColorHelpers.accent

    private var hasUnsavedText: Bool { text != savedText }

    /// An entry keeps the question it was written with (spec 3.2).
    private var question: String {
        entry?.question ?? passage?.question ?? ""
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(DateHelpers.fullDateString(for: day))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let stoneSummary {
                    StoneSummaryView(summary: stoneSummary)
                }

                if let passage {
                    PassageView(passage: passage, accent: accent)

                    questionSection
                    editorSection
                } else {
                    ContentUnavailableView(
                        "No passage tonight",
                        systemImage: "text.book.closed",
                        description: Text("Tonight's passage couldn't be loaded.")
                    )
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isEditorFocused = false
                }
            }
        }
        .onAppear {
            followClock()
            reload()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                followClock()
                reload()
            }
        }
        .task(id: DateHelpers.dayKey(for: day)) {
            // Move to the next reflection day at 03:00 while the screen is open.
            let end = DateHelpers.reflectionDayInterval(forDay: day).end
            let seconds = max(end.timeIntervalSinceNow, 0) + 1
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            followClock()
        }
    }

    // MARK: - Sections

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.bottom, 6)

            Text(question)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if earlierEntryCount > 0, let passage {
                Button {
                    onOpenPassageHistory(passage.id)
                } label: {
                    Text(earlierEntriesText)
                        .font(.footnote)
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextEditor(text: $text)
                .focused($isEditorFocused)
                .frame(minHeight: 220)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Take your time. There's no need to write anything.")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel("Journal entry")

            Text("Each day keeps one entry. Saving again replaces it.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .tint(accent)

                if let lastSavedAt {
                    Text("Saved at \(ReflectionDateFormatters.saveTimestamp.string(from: lastSavedAt)).")
                        .font(.footnote.italic())
                        .foregroundStyle(.secondary)
                }
            }

            if dayEndedBeforeSave {
                dayEndedNote
            }
        }
    }

    private var dayEndedNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A new day began at 3am, so this entry can't be added to the day before. Copy anything you'd like to keep before moving on.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Go to today's passage") {
                dayEndedBeforeSave = false
                day = DateHelpers.currentReflectionDay
                reload()
            }
            .font(.footnote)
            .foregroundStyle(accent)
        }
    }

    private var earlierEntriesText: String {
        "You've written on this passage \(earlierEntryCount) \(earlierEntryCount == 1 ? "time" : "times") before."
    }

    // MARK: - Loading and saving

    /// Moves to the current reflection day unless there's unsaved text.
    private func followClock() {
        let current = DateHelpers.currentReflectionDay
        guard current != day, !hasUnsavedText else { return }
        day = current
        reload()
    }

    private func reload() {
        entry = JournalStore.entry(forDay: day, in: modelContext)
        let set = PassageSet.bundled
        passage = entry.flatMap { set.passage(withID: $0.passageID) } ?? PassageSequence.passage(for: day, in: set)
        stoneSummary = StoneDaySummary(stones: stones(on: day))

        let key = DateHelpers.dayKey(for: day)
        earlierEntryCount = passage.map { passage in
            JournalStore.entries(forPassage: passage.id, in: modelContext).filter { $0.dayKey != key }.count
        } ?? 0

        // Keep text being written; otherwise show what's saved.
        let saved = entry?.responseText ?? ""
        if !hasUnsavedText {
            text = saved
        }
        savedText = saved
        lastSavedAt = entry?.updatedAt
    }

    private func stones(on day: Date) -> [Stone] {
        let interval = DateHelpers.reflectionDayInterval(forDay: day)
        let start = interval.start
        let end = interval.end
        let predicate = #Predicate<Stone> { $0.timestamp >= start && $0.timestamp < end }
        let descriptor = FetchDescriptor<Stone>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return modelContext.fetchOrEmpty(descriptor)
    }

    private func save() {
        guard let passage else { return }
        isEditorFocused = false
        let copy = entry.map {
            JournalPassageCopy(passageID: $0.passageID, passageRef: $0.passageRef, passageTitle: $0.passageTitle, question: $0.question)
        } ?? passage.journalCopy

        let result = JournalStore.save(
            text: text,
            day: day,
            currentDay: DateHelpers.currentReflectionDay,
            passage: copy,
            in: modelContext
        )
        switch result {
        case .notCurrentDay:
            dayEndedBeforeSave = true
            return
        case .deleted, .nothingToSave:
            text = ""
        case .saved:
            break
        }
        dayEndedBeforeSave = false
        savedText = text
        reload()
        followClock()
    }
}

// MARK: - Pieces

private struct StoneSummaryView: View {
    let summary: StoneDaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(summary.rows, id: \.type) { row in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle()
                        .fill(row.type == .white ? ColorHelpers.whiteStoneColor : ColorHelpers.blackStoneColor)
                        .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 0.5))
                        .frame(width: 9, height: 9)
                    Text(row.countText)
                        .foregroundStyle(.primary)
                    if !row.roots.isEmpty {
                        Text(row.roots.joined(separator: ", "))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .font(.footnote)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        summary.rows.map { row in
            row.roots.isEmpty ? "\(row.countText) stones" : "\(row.countText) stones: \(row.roots.joined(separator: ", "))"
        }
        .joined(separator: ". ")
    }
}

/// Title, reference line, italic excerpt with "…" between blocks, and a link
/// to the full sutta on SuttaCentral.
struct PassageView: View {
    let passage: Passage
    var accent: Color = ColorHelpers.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(passage.title)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("\(passage.ref) · translated by Bhikkhu Sujato")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(passage.blocks.enumerated()), id: \.offset) { index, block in
                    if index > 0 {
                        Text("…")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("Passage continues later in the sutta")
                    }
                    ForEach(Array(block.enumerated()), id: \.offset) { _, segment in
                        Text(segment)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .font(.system(.body, design: .serif).italic())
            .lineSpacing(3)
            .textSelection(.enabled)

            Link(destination: passage.url) {
                Label("Read the full sutta", systemImage: "arrow.up.right")
                    .labelStyle(TrailingIconLabelStyle())
                    .font(.footnote)
                    .foregroundStyle(accent)
            }
        }
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
                .imageScale(.small)
        }
    }
}
