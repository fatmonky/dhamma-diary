import XCTest
import SwiftData
@testable import DhammaDiary

/// A repeatable generator, so the random schedule can be tested.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

final class MindCheckScheduleTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
    }

    private func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func minutes(_ time: Date) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: time)
        return c.hour! * 60 + c.minute!
    }

    func testThreeTimesOneInEachWindowAnHourApart() {
        for seed in 0..<500 {
            var generator = SeededGenerator(state: UInt64(seed))
            let times = MindCheckSchedule.times(forDay: date(20), calendar: calendar, using: &generator)
            XCTAssertEqual(times.count, 3)
            let m = times.map(minutes)
            XCTAssertTrue((9 * 60..<13 * 60).contains(m[0]), "seed \(seed): \(m)")
            XCTAssertTrue((13 * 60..<17 * 60).contains(m[1]), "seed \(seed): \(m)")
            XCTAssertTrue((17 * 60..<21 * 60).contains(m[2]), "seed \(seed): \(m)")
            XCTAssertGreaterThanOrEqual(m[1] - m[0], 60, "seed \(seed): \(m)")
            XCTAssertGreaterThanOrEqual(m[2] - m[1], 60, "seed \(seed): \(m)")
            XCTAssertTrue(times.allSatisfy { calendar.isDate($0, inSameDayAs: date(20)) })
        }
    }

    func testTimesVaryFromDayToDay() {
        var generator = SeededGenerator(state: 42)
        let first = MindCheckSchedule.times(forDay: date(20), calendar: calendar, using: &generator).map(minutes)
        let second = MindCheckSchedule.times(forDay: date(21), calendar: calendar, using: &generator).map(minutes)
        XCTAssertNotEqual(first, second)
    }

    func testFirstPlanCoversAWeekAndSkipsPassedTimes() {
        var generator = SeededGenerator(state: 7)
        let now = date(20, 18, 0)
        let plan = MindCheckSchedule.plan(now: now, plannedThrough: nil, calendar: calendar, using: &generator)

        XCTAssertEqual(plan.plannedThrough, date(26))
        XCTAssertTrue(plan.times.allSatisfy { $0 > now })
        // Today keeps at most the evening window; the six days after keep all three.
        let today = plan.times.filter { calendar.isDate($0, inSameDayAs: now) }
        XCTAssertLessThanOrEqual(today.count, 1)
        XCTAssertEqual(plan.times.count - today.count, 18)
        XCTAssertEqual(plan.times, plan.times.sorted())
    }

    func testTopUpOnlyAddsDaysNotYetPlanned() {
        var generator = SeededGenerator(state: 7)
        let plan = MindCheckSchedule.plan(now: date(22, 10), plannedThrough: date(26), calendar: calendar, using: &generator)
        XCTAssertEqual(plan.plannedThrough, date(28))
        XCTAssertEqual(plan.times.count, 6)
        XCTAssertTrue(plan.times.allSatisfy { $0 >= date(27) })
    }

    func testFullyPlannedWeekAddsNothing() {
        var generator = SeededGenerator(state: 7)
        let plan = MindCheckSchedule.plan(now: date(20, 10), plannedThrough: date(26), calendar: calendar, using: &generator)
        XCTAssertEqual(plan.times, [])
        XCTAssertEqual(plan.plannedThrough, date(26))
    }
}

final class MindDaySummaryTests: XCTestCase {
    private let base = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 9))!

    private func sample(_ hoursAfterNine: Double, _ noise: Double) -> MindDaySummary.Sample {
        MindDaySummary.Sample(timestamp: base.addingTimeInterval(hoursAfterNine * 3600), noise: noise)
    }

    private func hourLabel(_ date: Date) -> String {
        "\(Calendar.current.component(.hour, from: date)):00"
    }

    func testNoCheckInsGivesNoSummary() {
        XCTAssertNil(MindDaySummary(samples: []))
    }

    func testOneCheckIn() throws {
        let summary = try XCTUnwrap(MindDaySummary(samples: [sample(5, 30)]))
        XCTAssertEqual(summary.text(time: hourLabel), "1 check-in today, at 14:00.")
    }

    func testStillestAndNoisiest() throws {
        let summary = try XCTUnwrap(MindDaySummary(samples: [sample(8, 40), sample(0, 90), sample(4, 10)]))
        XCTAssertEqual(summary.text(time: hourLabel), "3 check-ins today. Stillest at 13:00, noisiest at 9:00.")
    }

    func testAllTheSame() throws {
        let summary = try XCTUnwrap(MindDaySummary(samples: [sample(0, 50), sample(4, 50)]))
        XCTAssertEqual(summary.text(time: hourLabel), "2 check-ins today, all about the same.")
    }

    func testSlideMapsUpToNoisyAndDownToStill() {
        XCTAssertEqual(MindDaySummary.noise(forSlide: 0, range: 170), 50)
        XCTAssertEqual(MindDaySummary.noise(forSlide: -170, range: 170), 100)
        XCTAssertEqual(MindDaySummary.noise(forSlide: 170, range: 170), 0)
        XCTAssertEqual(MindDaySummary.noise(forSlide: -85, range: 170), 75)
        // Past either end stays at the end.
        XCTAssertEqual(MindDaySummary.noise(forSlide: -400, range: 170), 100)
        XCTAssertEqual(MindDaySummary.noise(forSlide: 400, range: 170), 0)
    }

    func testWords() {
        XCTAssertEqual(MindDaySummary.word(for: 0), "Very still")
        XCTAssertEqual(MindDaySummary.word(for: 50), "In between")
        XCTAssertEqual(MindDaySummary.word(for: 100), "Very noisy")
    }
}

@MainActor
final class MindCheckStoreTests: XCTestCase {
    func testChecksFollowTheReflectionDay() throws {
        let container = try DhammaDiaryStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let calendar = Calendar.current
        let day = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20))!
        func at(_ dayOffset: Int, _ hour: Int) -> Date {
            calendar.date(byAdding: DateComponents(day: dayOffset, hour: hour), to: day)!
        }
        // 02:00 on the 20th belongs to the 19th; 02:00 on the 21st to the 20th.
        for time in [at(0, 2), at(0, 10), at(0, 20), at(1, 2), at(1, 10)] {
            context.insert(MindCheck(timestamp: time, noise: 50))
        }
        try context.save()

        let checks = MindCheckStore.checks(onDay: day, in: context)
        XCTAssertEqual(checks.map(\.timestamp), [at(0, 10), at(0, 20), at(1, 2)])
        XCTAssertEqual(checks.first?.dayKey, "2026-11-20")
        XCTAssertEqual(checks.last?.dayKey, "2026-11-20")
    }

    func testNoiseIsClamped() {
        XCTAssertEqual(MindCheck(noise: 140).noise, 100)
        XCTAssertEqual(MindCheck(noise: -3).noise, 0)
    }
}

/// A phone with v1 data keeps it after the update that adds MindCheck.
@MainActor
final class SchemaMigrationTests: XCTestCase {
    func testV1StoreOpensWithV2() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("v1.store")

        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let v1 = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            v1.mainContext.insert(Stone(type: .white))
            v1.mainContext.insert(JournalEntry(day: .now, passageID: "an10.51-mirror", passageRef: "AN 10.51", passageTitle: "Your Own Mind", question: "Q", responseText: "Kept"))
            try v1.mainContext.save()
        }

        let v2 = try DhammaDiaryStore.makeContainer(url: url)
        let context = v2.mainContext
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Stone>()), 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).first?.responseText, "Kept")

        context.insert(MindCheck(noise: 20))
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MindCheck>()), 1)
    }
}

/// The store stays in the app's own container (see `DhammaDiaryStore`).
final class StoreLocationTests: XCTestCase {
    private var root: URL!
    private var appStore: URL { root.appending(path: "app/Library/Application Support/default.store") }
    private var groupStore: URL { root.appending(path: "group/Library/Application Support/default.store") }
    private let fm = FileManager.default

    override func setUpWithError() throws {
        root = fm.temporaryDirectory.appending(path: UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: root)
    }

    private func write(_ store: URL, _ text: String, modified: Date) throws {
        try fm.createDirectory(at: store.deletingLastPathComponent(), withIntermediateDirectories: true)
        for sidecar in ["", "-wal"] {
            let url = URL(fileURLWithPath: store.path + sidecar)
            try Data((text + sidecar).utf8).write(to: url)
            try fm.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        }
    }

    private func read(_ url: URL) -> String? {
        (try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) }
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testNoGroupStoreLeavesEverythingAlone() throws {
        try write(appStore, "app", modified: now)
        XCTAssertEqual(try DhammaDiaryStore.settleStoreLocation(appStore: appStore, groupStore: groupStore, now: now), .nothingToMove)
        XCTAssertEqual(read(appStore), "app")
    }

    func testGroupStoreAloneMovesIn() throws {
        try write(groupStore, "group", modified: now)
        XCTAssertEqual(try DhammaDiaryStore.settleStoreLocation(appStore: appStore, groupStore: groupStore, now: now), .movedFromGroup)
        XCTAssertEqual(read(appStore), "group")
        XCTAssertEqual(read(URL(fileURLWithPath: appStore.path + "-wal")), "group-wal")
        XCTAssertFalse(fm.fileExists(atPath: groupStore.path))
    }

    func testNewerGroupStoreWinsAndOlderAppStoreIsKept() throws {
        try write(appStore, "app", modified: now.addingTimeInterval(-3600))
        try write(groupStore, "group", modified: now)
        let result = try DhammaDiaryStore.settleStoreLocation(appStore: appStore, groupStore: groupStore, now: now)
        guard case .movedFromGroupKeepingOlder(let suffix) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(read(appStore), "group")
        XCTAssertEqual(read(DhammaDiaryStore.backupURL(appStore, suffix)), "app")
        XCTAssertFalse(fm.fileExists(atPath: groupStore.path))
    }

    func testNewerAppStoreWinsAndGroupCopyIsKept() throws {
        try write(appStore, "app", modified: now)
        try write(groupStore, "group", modified: now.addingTimeInterval(-3600))
        let result = try DhammaDiaryStore.settleStoreLocation(appStore: appStore, groupStore: groupStore, now: now)
        guard case .keptAppStore(let suffix) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(read(appStore), "app")
        XCTAssertEqual(read(DhammaDiaryStore.backupURL(groupStore, suffix)), "group")
        XCTAssertFalse(fm.fileExists(atPath: groupStore.path))
        // Settled once: the next launch has nothing to do.
        XCTAssertEqual(try DhammaDiaryStore.settleStoreLocation(appStore: appStore, groupStore: groupStore, now: now), .nothingToMove)
    }

    /// Real stores: an empty group store (from a build that opened a fresh
    /// one) must not win over older data in the app container.
    @MainActor
    func testEmptyNewerGroupStoreNeverWinsOverData() throws {
        try fm.createDirectory(at: appStore.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createDirectory(at: groupStore.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            let app = try DhammaDiaryStore.makeContainer(url: appStore)
            app.mainContext.insert(Stone(type: .white))
            try app.mainContext.save()
        }
        do {
            _ = try DhammaDiaryStore.makeContainer(url: groupStore)
        }
        // Make the empty one clearly newer.
        for sidecar in ["", "-wal", "-shm"] where fm.fileExists(atPath: groupStore.path + sidecar) {
            try fm.setAttributes([.modificationDate: Date.now.addingTimeInterval(3600)], ofItemAtPath: groupStore.path + sidecar)
        }
        XCTAssertEqual(DhammaDiaryStore.recordCount(appStore), 1)
        XCTAssertEqual(DhammaDiaryStore.recordCount(groupStore), 0)

        let result = try DhammaDiaryStore.settleStoreLocation(appStore: appStore, groupStore: groupStore)
        guard case .keptAppStore = result else { return XCTFail("\(result)") }
        let reopened = try DhammaDiaryStore.makeContainer(url: appStore)
        XCTAssertEqual(try reopened.mainContext.fetchCount(FetchDescriptor<Stone>()), 1)
    }

    func testBackupName() {
        let url = URL(fileURLWithPath: "/x/default.store")
        XCTAssertEqual(DhammaDiaryStore.backupURL(url, "before-1").lastPathComponent, "default-before-1.store")
    }
}
