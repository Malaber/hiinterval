import XCTest
@testable import HiIntervalCore

final class ExerciseEditorPresentationTests: XCTestCase {
    func testNewExerciseStartsWithNameFocus() {
        XCTAssertEqual(ExerciseEditorPresentation.initialFocus(isNew: true), .name)
    }

    func testExistingExerciseDoesNotStealFocus() {
        XCTAssertNil(ExerciseEditorPresentation.initialFocus(isNew: false))
    }
}
