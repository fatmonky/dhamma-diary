import XCTest
@testable import DhammaDiary

final class OnboardingTests: XCTestCase {
    private func step(_ current: OnboardingStep?, hasStones: Bool, postFirstEntry: Bool = false) -> OnboardingStep {
        OnboardingStep.bootstrapped(from: current, hasStones: hasStones, showingPostFirstEntry: postFirstEntry)
    }

    func testFreshInstallStartsAtWelcome() {
        XCTAssertEqual(step(nil, hasStones: false), .welcome)
    }

    func testCompletedDoesNotRestartAfterAllStonesAreDeleted() {
        XCTAssertEqual(step(.completed, hasStones: false), .completed)
    }

    func testExistingUserWithStonesSkipsOnboarding() {
        XCTAssertEqual(step(nil, hasStones: true), .completed)
        XCTAssertEqual(step(.welcome, hasStones: true), .completed)
    }

    func testMidFlowStepsArePreserved() {
        for current in [OnboardingStep.firstLog, .reviewTour, .diaryTour, .mindInvite] {
            XCTAssertEqual(step(current, hasStones: true), current)
        }
    }

    func testTodayCoachIsKeptWhileThereAreNoStones() {
        XCTAssertEqual(step(.todayCoach, hasStones: false), .todayCoach)
    }

    func testFirstStoneMessageKeepsTheCurrentStep() {
        XCTAssertEqual(step(.todayCoach, hasStones: true, postFirstEntry: true), .todayCoach)
    }
}
