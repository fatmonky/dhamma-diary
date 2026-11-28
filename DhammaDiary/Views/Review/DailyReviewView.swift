import SwiftData
import SwiftUI

/// Daily Review (spec 10): the day's stones dropped into your hand, then the
/// day so far — stones, mind and diary entry.
struct DailyReviewView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var review: DailyReview?
    @State private var settled = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let review {
                    StoneDropPile(
                        types: review.stoneTypes,
                        label: "Today's stones",
                        value: review.tallyText,
                        settled: $settled
                    )
                }
                if settled, let review {
                    summary(review)
                        .transition(.opacity)
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Daily Review")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: start)
    }

    private func start() {
        // Once per visit: coming back from an entry keeps the settled pile.
        guard review == nil else { return }
        var loaded = DailyReview.load(day: DateHelpers.currentReflectionDay, in: modelContext)
        #if DEBUG
        loaded = DailyReview(
            day: loaded.day,
            stoneTypes: StoneDropDebug.override(loaded.stoneTypes),
            checks: loaded.checks,
            entry: loaded.entry
        )
        #endif
        review = loaded
    }

    // MARK: - The day so far

    private func summary(_ review: DailyReview) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            Text(DateHelpers.fullDateString(for: review.day))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            section("Stones") {
                Text(review.tallyText)
                    .font(.body)
            }

            section("Mind") {
                if let summary = MindDaySummary(checks: review.checks) {
                    MindDayChart(checks: review.checks, day: review.day)
                        .frame(height: 130)
                    Text(summary.text())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No mind check-ins yet today.")
                        .foregroundStyle(.secondary)
                }
            }

            section("Diary") {
                if let entry = review.entry {
                    NavigationLink {
                        JournalEntryDetailView(entryID: entry.persistentModelID)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(entry.passageRef) · \(entry.passageTitle)")
                                .font(.footnote)
                                .foregroundStyle(ColorHelpers.accent)
                            Text(entry.responseText)
                                .font(.system(.body, design: .serif))
                                .foregroundStyle(.primary)
                                .lineLimit(5)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("No diary entry yet.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}
