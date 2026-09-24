import XCTest
@testable import HiIntervalCore

final class WorkoutLogoCropGeometryTests: XCTestCase {
    func testPortraitImageCropsCenteredSquareAndClampsVerticalDrag() {
        let crop = WorkoutLogoCropGeometry(sourceWidth: 600, sourceHeight: 1_200, viewportSide: 300, zoom: 1)
        XCTAssertEqual(crop.scale, 0.5)
        XCTAssertEqual(crop.cropSide, 600)
        XCTAssertEqual(crop.cropOrigin(offsetX: 0, offsetY: 0).x, 0)
        XCTAssertEqual(crop.cropOrigin(offsetX: 0, offsetY: 0).y, 300)
        XCTAssertEqual(crop.clampedOffset(x: 999, y: 999).x, 0)
        XCTAssertEqual(crop.clampedOffset(x: 999, y: 999).y, 150)
        XCTAssertEqual(crop.cropOrigin(offsetX: 0, offsetY: 999).y, 0)
        XCTAssertEqual(crop.cropOrigin(offsetX: 0, offsetY: -999).y, 600)
    }

    func testLandscapeImageCropsCenteredSquareAndClampsHorizontalDrag() {
        let crop = WorkoutLogoCropGeometry(sourceWidth: 1_200, sourceHeight: 600, viewportSide: 300, zoom: 1)
        XCTAssertEqual(crop.cropOrigin(offsetX: 0, offsetY: 0).x, 300)
        XCTAssertEqual(crop.cropOrigin(offsetX: 0, offsetY: 0).y, 0)
        XCTAssertEqual(crop.clampedOffset(x: 999, y: 999).x, 150)
        XCTAssertEqual(crop.clampedOffset(x: 999, y: 999).y, 0)
        XCTAssertEqual(crop.cropOrigin(offsetX: 999, offsetY: 0).x, 0)
        XCTAssertEqual(crop.cropOrigin(offsetX: -999, offsetY: 0).x, 600)
    }

    func testZoomMakesSquareSmallerAndKeepsCropInsideImage() {
        let crop = WorkoutLogoCropGeometry(sourceWidth: 800, sourceHeight: 800, viewportSide: 400, zoom: 2)
        XCTAssertEqual(crop.scale, 1)
        XCTAssertEqual(crop.cropSide, 400)
        XCTAssertEqual(crop.cropOrigin(offsetX: 0, offsetY: 0).x, 200)
        XCTAssertEqual(crop.cropOrigin(offsetX: 0, offsetY: 0).y, 200)
        XCTAssertEqual(crop.cropOrigin(offsetX: 999, offsetY: -999).x, 0)
        XCTAssertEqual(crop.cropOrigin(offsetX: 999, offsetY: -999).y, 400)
    }
}
