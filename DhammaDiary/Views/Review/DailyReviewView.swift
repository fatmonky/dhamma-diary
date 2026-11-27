import SpriteKit
import SwiftData
import SwiftUI

/// Daily Review (spec 10): the day's stones dropped into your hand, then the
/// day so far — stones, mind and diary entry.
struct DailyReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var review: DailyReview?
    @State private var scene: StoneDropScene?
    @State private var feedback = StoneDropFeedback()
    @State private var settled = false

    private static let pileHeight: CGFloat = 330

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                pile
                if settled, let review {
                    summary(review)
                        .transition(.opacity)
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Daily Review")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            scene?.isPaused = false
            start()
        }
        .onDisappear {
            // Leaving mid-fall: no more sound or taps from a screen that's gone.
            feedback.isMuted = true
            feedback.stop()
            scene?.isPaused = true
        }
    }

    // MARK: - Pile

    @ViewBuilder
    private var pile: some View {
        if let review, !review.stoneTypes.isEmpty {
            GeometryReader { proxy in
                ZStack {
                    if let scene {
                        SpriteView(scene: scene, options: [.allowsTransparency])
                            // With Reduce Motion the pile settles out of sight first.
                            .opacity(reduceMotion && !settled ? 0 : 1)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { scene?.skipToEnd() }
                .onAppear { makeScene(review, size: proxy.size) }
            }
            .frame(height: Self.pileHeight)
            .accessibilityElement()
            .accessibilityLabel("Today's stones")
            .accessibilityValue(review.tallyText)
            .accessibilityHint(settled ? "" : "Double-tap to skip.")
        }
    }

    private func start() {
        // Once per visit: coming back from an entry keeps the settled pile.
        guard review == nil else { return }
        var loaded = DailyReview.load(day: DateHelpers.currentReflectionDay, in: modelContext)
        #if DEBUG
        // For simulator checks: `-debug.dropCount 40` drops that many stones instead.
        let count = UserDefaults.standard.integer(forKey: "debug.dropCount")
        if count > 0 {
            loaded = DailyReview(
                day: loaded.day,
                stoneTypes: (0..<count).map { $0 % 3 == 2 ? .black : .white },
                checks: loaded.checks,
                entry: loaded.entry
            )
        }
        #endif
        review = loaded
        if loaded.stoneTypes.isEmpty {
            settled = true
        }
    }

    private func makeScene(_ review: DailyReview, size: CGSize) {
        guard scene == nil, size.width > 0 else { return }
        feedback.prepare()
        let scene = StoneDropScene(types: review.stoneTypes, size: size, feedback: feedback)
        scene.onSettled = {
            withAnimation(.easeIn(duration: reduceMotion ? 0.6 : 0.8)) {
                settled = true
            }
        }
        if reduceMotion {
            scene.dropAllQuietly()
        }
        self.scene = scene
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
