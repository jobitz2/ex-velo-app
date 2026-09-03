import XCTest
import CoreVideo
@testable import ExVelo

final class BallRadiusEstimatorTests: XCTestCase {
    private func makeGrayscaleBuffer(width: Int, height: Int, fill: (Int, Int) -> UInt8) -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_OneComponent8, nil, &pixelBuffer)
        guard let buffer = pixelBuffer else {
            fatalError("Failed to create test pixel buffer")
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<height {
            for x in 0..<width {
                base[y * bytesPerRow + x] = fill(x, y)
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }

    func testRecoversKnownDiscRadius() {
        let width = 120, height = 120
        let discRadius = 18.0
        let centerX = 60.0, centerY = 60.0
        let buffer = makeGrayscaleBuffer(width: width, height: height) { x, y in
            let dx = Double(x) - centerX
            let dy = Double(y) - centerY
            return (dx * dx + dy * dy).squareRoot() <= discRadius ? 235 : 25
        }

        // Vision points are normalized (0...1) with a lower-left origin, so a
        // point at pixel (60, 60) from the top is y = 1 - 60/120 in that space.
        let normalizedPoint = CGPoint(x: centerX / Double(width), y: 1 - centerY / Double(height))
        let measured = BallRadiusEstimator.estimateRadiusPixels(
            pixelBuffer: buffer,
            normalizedPoint: normalizedPoint,
            hintRadiusPixels: 15
        )

        guard let measured else {
            return XCTFail("Expected a radius measurement")
        }
        XCTAssertEqual(measured, discRadius, accuracy: 2)
    }

    func testTracksShrinkingApparentRadiusAsObjectRecedes() {
        // A smaller disc (farther away) at the same center should measure a
        // proportionally smaller radius — this is exactly the signal
        // KnownObjectSizeCalibration needs to detect a ball moving away.
        let width = 120, height = 120
        let nearRadius = 20.0
        let farRadius = 10.0
        let centerX = 60.0, centerY = 60.0

        func buffer(radius: Double) -> CVPixelBuffer {
            makeGrayscaleBuffer(width: width, height: height) { x, y in
                let dx = Double(x) - centerX
                let dy = Double(y) - centerY
                return (dx * dx + dy * dy).squareRoot() <= radius ? 235 : 25
            }
        }

        let normalizedPoint = CGPoint(x: centerX / Double(width), y: 1 - centerY / Double(height))
        let nearMeasured = BallRadiusEstimator.estimateRadiusPixels(
            pixelBuffer: buffer(radius: nearRadius), normalizedPoint: normalizedPoint, hintRadiusPixels: 15
        )
        let farMeasured = BallRadiusEstimator.estimateRadiusPixels(
            pixelBuffer: buffer(radius: farRadius), normalizedPoint: normalizedPoint, hintRadiusPixels: 15
        )

        guard let nearMeasured, let farMeasured else {
            return XCTFail("Expected radius measurements for both frames")
        }
        XCTAssertGreaterThan(nearMeasured, farMeasured)
    }

    func testReturnsNilOnFeaturelessImage() {
        let width = 60, height = 60
        let buffer = makeGrayscaleBuffer(width: width, height: height) { _, _ in 128 }

        let measured = BallRadiusEstimator.estimateRadiusPixels(
            pixelBuffer: buffer,
            normalizedPoint: CGPoint(x: 0.5, y: 0.5),
            hintRadiusPixels: 10
        )
        XCTAssertNil(measured)
    }
}
