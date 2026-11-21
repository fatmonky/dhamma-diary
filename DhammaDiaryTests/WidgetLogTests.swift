import XCTest
import SwiftData
@testable import DhammaDiary

@MainActor
final class WidgetLogTests: XCTestCase {
    private let sharedName = "WidgetLogTests.shared"
    private let localName = "WidgetLogTests.local"
    private var shared: UserDefaults!
    private var local: UserDefaults!
    private var context: ModelContext!
    private var container: ModelContainer!

    override func setUp() async throws {
        shared = UserDefaults(suiteName: sharedName)
        local = UserDefaults(suiteName: localName)
        shared.removePersistentDomain(forName: sharedName)
        local.removePersistentDomain(forName: localName)
        container = try DhammaDiaryStore.makeContainer(inMemory: true)
        context = container.mainContext
    }

    override func tearDown() async throws {
        shared.removePersistentDomain(forName: sharedName)
        local.removePersistentDomain(forName: localName)
        context = nil
        container = nil
    }

    private let tapTime = Date(timeIntervalSince1970: 1_795_000_000)

    func testEachKindBecomesTheRightRecordWithTheTapTime() throws {
        WidgetLogQueue.append(WidgetLog(kind: .mind, timestamp: tapTime, noise: 90), defaults: shared)
        WidgetLogQueue.append(WidgetLog(kind: .whiteStone, timestamp: tapTime.addingTimeInterval(60)), defaults: shared)
        WidgetLogQueue.append(WidgetLog(kind: .blackStone, timestamp: tapTime.addingTimeInterval(120)), defaults: shared)

        XCTAssertEqual(WidgetLogImporter.run(into: context, shared: shared, local: local), 3)

        let checks = try context.fetch(FetchDescriptor<MindCheck>())
        XCTAssertEqual(checks.map(\.noise), [90])
        XCTAssertEqual(checks.first?.timestamp, tapTime)
        XCTAssertEqual(checks.first?.prompted, false)
        let stones = try context.fetch(FetchDescriptor<Stone>(sortBy: [SortDescriptor(\.timestamp)]))
        XCTAssertEqual(stones.map(\.type), [.white, .black])
        XCTAssertEqual(stones.first?.timestamp, tapTime.addingTimeInterval(60))
        XCTAssertEqual(stones.first?.dayKey, DateHelpers.reflectionDayKey(for: tapTime.addingTimeInterval(60)))
        XCTAssertTrue(WidgetLogQueue.pending(defaults: shared).isEmpty)
    }

    func testNothingIsImportedTwice() throws {
        let log = WidgetLog(kind: .mind, timestamp: tapTime, noise: 10)
        WidgetLogQueue.append(log, defaults: shared)
        WidgetLogImporter.run(into: context, shared: shared, local: local)

        // As if the queue hadn't been cleared after the first import.
        WidgetLogQueue.append(log, defaults: shared)
        XCTAssertEqual(WidgetLogImporter.run(into: context, shared: shared, local: local), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MindCheck>()), 1)
        XCTAssertTrue(WidgetLogQueue.pending(defaults: shared).isEmpty)
    }

    func testRemovingKeepsTapsThatArrivedMeanwhile() {
        let first = WidgetLog(kind: .whiteStone, timestamp: tapTime)
        let later = WidgetLog(kind: .blackStone, timestamp: tapTime.addingTimeInterval(5))
        WidgetLogQueue.append(first, defaults: shared)
        WidgetLogQueue.append(later, defaults: shared)
        WidgetLogQueue.remove(ids: [first.id], defaults: shared)
        XCTAssertEqual(WidgetLogQueue.pending(defaults: shared), [later])
    }

    func testLastNotedIsTheLatestTap() {
        XCTAssertNil(WidgetLogQueue.lastNoted(defaults: shared))
        WidgetLogQueue.append(WidgetLog(kind: .mind, timestamp: tapTime, noise: 50), defaults: shared)
        XCTAssertEqual(WidgetLogQueue.lastNoted(defaults: shared), tapTime)
    }

    func testCheckInsAndStonesKeepTheirOwnNotedTime() {
        let stoneTime = tapTime.addingTimeInterval(60)
        WidgetLogQueue.append(WidgetLog(kind: .mind, timestamp: tapTime, noise: 10), defaults: shared)
        XCTAssertEqual(WidgetLogQueue.lastNoted(.mind, defaults: shared), tapTime)
        XCTAssertNil(WidgetLogQueue.lastNoted(.stone, defaults: shared))

        WidgetLogQueue.append(WidgetLog(kind: .blackStone, timestamp: stoneTime), defaults: shared)
        XCTAssertEqual(WidgetLogQueue.lastNoted(.mind, defaults: shared), tapTime)
        XCTAssertEqual(WidgetLogQueue.lastNoted(.stone, defaults: shared), stoneTime)
    }

    func testEmptyQueueDoesNothing() {
        XCTAssertEqual(WidgetLogImporter.run(into: context, shared: shared, local: local), 0)
    }
}
