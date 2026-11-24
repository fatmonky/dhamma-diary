#if DEBUG
import Foundation
import SwiftData

/// Sample data for App Store screenshots, on throwaway simulators only:
/// `simctl launch … -debug.demoData YES`. It runs only on an empty store and
/// never in release builds. The entries are invented, not anyone's journal.
enum DemoData {
    static func seedIfRequested(in context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "debug.demoData") else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<Stone>())) ?? 0
        guard existing == 0 else { return }

        let calendar = Calendar.current
        let today = DateHelpers.currentReflectionDay
        let passages = PassageSet.bundled.passages
        // Start the sequence one full round ago, so tonight is passage 1 again.
        let firstDay = calendar.date(byAdding: .day, value: -passages.count, to: today)!
        PassageSequence.sharedDefaults.set(DateHelpers.dayKey(forDay: firstDay, calendar: calendar), forKey: PassageSequence.firstDayStorageKey)

        for back in stride(from: passages.count, through: 0, by: -1) {
            let day = calendar.date(byAdding: .day, value: -back, to: today)!
            let seed = back
            let isToday = back == 0

            // Stones: two to five a day, today only up to the afternoon.
            for (i, stone) in stones(seed: seed).enumerated() {
                if isToday && i > 2 { break }
                let time = calendar.date(bySettingHour: stone.hour, minute: stone.minute, second: 0, of: day)!
                context.insert(Stone(type: stone.type, note: stone.note, timestamp: time, roots: stone.roots))
            }

            // Mind check-ins: four a day, today three.
            for (i, check) in checks(seed: seed).enumerated() {
                if isToday && i > 2 { break }
                let time = calendar.date(bySettingHour: check.hour, minute: check.minute, second: 0, of: day)!
                context.insert(MindCheck(timestamp: time, noise: check.noise, prompted: i != 1))
            }

            // Journal entries on most past evenings.
            if !isToday, seed % 4 != 3 {
                let index = PassageSequence.index(firstDay: firstDay, currentDay: day, passageCount: passages.count)
                let passage = passages[index]
                let written = calendar.date(bySettingHour: 21, minute: 30, second: 0, of: day)!
                context.insert(JournalEntry(
                    day: day,
                    passageID: passage.id,
                    passageRef: passage.ref,
                    passageTitle: passage.title,
                    question: passage.question,
                    responseText: entries[seed % entries.count],
                    createdAt: written
                ))
            }
        }
        try? context.save()
    }

    private struct DemoStone {
        let hour: Int, minute: Int, type: StoneType, roots: [StoneRoot], note: String
    }

    private struct DemoCheck {
        let hour: Int, minute: Int, noise: Double
    }

    private static func stones(seed: Int) -> [DemoStone] {
        let all: [DemoStone] = [
            DemoStone(hour: 8, minute: 12, type: .white, roots: [.kindness], note: "Let someone go ahead of me in the queue."),
            DemoStone(hour: 10, minute: 40, type: .black, roots: [.illWill], note: "Irritated in the meeting. Noticed it late."),
            DemoStone(hour: 13, minute: 5, type: .white, roots: [.renunciation], note: "Put the phone away at lunch."),
            DemoStone(hour: 15, minute: 50, type: .black, roots: [.sensual], note: ""),
            DemoStone(hour: 18, minute: 20, type: .white, roots: [.harmlessness], note: "Spoke gently when I wanted to snap."),
        ]
        let count = 2 + (seed * 7) % 4
        return Array(all.prefix(count))
    }

    private static func checks(seed: Int) -> [DemoCheck] {
        let shapes: [[Double]] = [
            [72, 40, 25, 48],
            [55, 80, 35, 20],
            [30, 62, 70, 38],
            [65, 45, 15, 30],
        ]
        let noise = shapes[seed % shapes.count]
        return [
            DemoCheck(hour: 9, minute: 20, noise: noise[0]),
            DemoCheck(hour: 12, minute: 45, noise: noise[1]),
            DemoCheck(hour: 16, minute: 10, noise: noise[2]),
            DemoCheck(hour: 20, minute: 35, noise: noise[3]),
        ]
    }

    private static let entries = [
        "Caught myself rehearsing an argument on the walk home. When I looked at it, there was nothing to win.\nThe evening was quieter after that.",
        "Spoke too quickly at lunch. It was true, but not timely. Tomorrow: wait a breath before answering.",
        "A slow, plain day. Fewer stones than usual, and the mind felt lighter for it.",
        "Most of the noise today came from planning things that may never happen. Noticing that was enough to let some of it go.",
        "Was kind to a stranger without thinking about it. Wanted to remember how easy that felt.",
        "Irritation came up twice, both times when I was tired. Going to bed earlier.",
    ]
}
#endif
