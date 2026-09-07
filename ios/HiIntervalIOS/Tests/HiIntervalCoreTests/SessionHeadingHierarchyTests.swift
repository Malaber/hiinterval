import XCTest
@testable import HiIntervalCore

final class SessionHeadingHierarchyTests: XCTestCase {
    func testDefaultHierarchyPrioritizesCurrentExercise() {
        let hierarchy = SessionHeadingHierarchy()

        XCTAssertTrue(hierarchy.clearlyPrioritizesCurrentHeading)
        XCTAssertEqual(hierarchy.currentNamePointSize, 42)
        XCTAssertEqual(hierarchy.nextNamePointSize, 19)
    }

    func testEqualHeadingsDoNotClaimClearPriority() {
        let hierarchy = SessionHeadingHierarchy(
            currentNamePointSize: 20,
            nextNamePointSize: 20,
            nextSurfaceOpacity: 0.12,
            nextStrokeOpacity: 0.1
        )

        XCTAssertFalse(hierarchy.clearlyPrioritizesCurrentHeading)
    }

    func testHeavyNextTreatmentDoesNotClaimClearPriority() {
        XCTAssertFalse(
            SessionHeadingHierarchy(nextSurfaceOpacity: 0.3)
                .clearlyPrioritizesCurrentHeading
        )
        XCTAssertFalse(
            SessionHeadingHierarchy(nextStrokeOpacity: 0.3)
                .clearlyPrioritizesCurrentHeading
        )
    }
}
