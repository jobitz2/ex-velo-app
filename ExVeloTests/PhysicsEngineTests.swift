import XCTest
@testable import ExVelo

final class LeastSquaresTests: XCTestCase {
    func testLinearFitRecoversKnownSlopeAndIntercept() {
        // y = 3*t + 2, sampled exactly.
        let samples: [(t: Double, y: Double)] = (0..<10).map { i in
            let t = Double(i) * 0.1
            return (t: t, y: 3 * t + 2)
        }
        guard let fit = LeastSquares.linearFit(samples) else {
            return XCTFail("Expected a linear fit")
        }
        XCTAssertEqual(fit.slope, 3, accuracy: 1e-9)
        XCTAssertEqual(fit.intercept, 2, accuracy: 1e-9)
    }

    func testQuadraticFitRecoversKnownParabola() {
        // y = -4.905*t^2 + 20*t + 1 (gravity-like deceleration).
        let samples: [(t: Double, y: Double)] = (0..<10).map { i in
            let t = Double(i) * 0.05
            return (t: t, y: -4.905 * t * t + 20 * t + 1)
        }
        guard let fit = LeastSquares.quadraticFit(samples) else {
            return XCTFail("Expected a quadratic fit")
        }
        XCTAssertEqual(fit.a, -4.905, accuracy: 1e-6)
        XCTAssertEqual(fit.b, 20, accuracy: 1e-6)
        XCTAssertEqual(fit.c, 1, accuracy: 1e-6)
    }
}

final class VelocityRegressionTests: XCTestCase {
    func testRecoversKnownSpeed() {
        // Synthesize a no-drag parabola for a known speed/launch angle, sampled
        // the way a high-fps clip would (every ~4ms for 40ms), and confirm the
        // regression recovers the speed close to what generated it.
        let speed = 40.0 // m/s (~89.5 mph)
        let launchAngleDegrees = 28.0
        let angleRadians = launchAngleDegrees * .pi / 180
        let vx = speed * cos(angleRadians)
        let vy = speed * sin(angleRadians)
        let g = 9.81

        let points: [CalibratedPoint] = (0..<10).map { i in
            let t = Double(i) * 0.004
            let x = vx * t
            let y = vy * t - 0.5 * g * t * t
            return CalibratedPoint(xMeters: x, yMeters: y, depthMeters: 10, timestampSeconds: t)
        }

        guard let recovered = VelocityRegression.speedMetersPerSecond(from: points) else {
            return XCTFail("Expected a recovered speed")
        }
        XCTAssertEqual(recovered, speed, accuracy: 0.05)
    }

    func testReturnsNilWithTooFewPoints() {
        let points = [
            CalibratedPoint(xMeters: 0, yMeters: 0, depthMeters: 10, timestampSeconds: 0),
            CalibratedPoint(xMeters: 1, yMeters: 1, depthMeters: 10, timestampSeconds: 0.01),
        ]
        XCTAssertNil(VelocityRegression.speedMetersPerSecond(from: points))
    }
}

final class PhysicsEngineTests: XCTestCase {
    func testComputeSpeedMphEndToEnd() {
        let speed = 44.7 // ~100 mph
        let launchAngleDegrees = 25.0
        let angleRadians = launchAngleDegrees * .pi / 180
        let vx = speed * cos(angleRadians)
        let vy = speed * sin(angleRadians)
        let g = 9.81

        let points: [CalibratedPoint] = (0..<10).map { i in
            let t = Double(i) * 0.004
            return CalibratedPoint(
                xMeters: vx * t,
                yMeters: vy * t - 0.5 * g * t * t,
                depthMeters: 10,
                timestampSeconds: t
            )
        }
        let trajectory = CalibratedTrajectory(points: points)

        guard let speedMph = PhysicsEngine.computeSpeedMph(from: trajectory) else {
            return XCTFail("Expected a computed speed")
        }
        XCTAssertEqual(speedMph, 100, accuracy: 1)
    }
}
