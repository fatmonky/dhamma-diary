import SwiftUI

/// Placeholder while the passage set is built (build step 4).
/// Step 5 replaces it with the Diary tab's "Tonight" mode: stone summary,
/// passage, question and journal entry, saved through `JournalStore`.
struct ReflectionTodayView: View {
    private var today: Date {
        Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(DateHelpers.fullDateString(for: today))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Tonight's passage and question will appear here.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
