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
    func testRecoversKnownExitVelocityAndLaunchAngle() {
        // Synthesize a no-drag parabola for a known exit velocity/launch angle at
        // contact, sampled the way a high-fps clip would (every ~4ms for 40ms),
        // and confirm the regression recovers v0 close to what generated it.
        let exitVelocity = 40.0 // m/s (~89.5 mph)
        let launchAngleDegrees = 28.0
        let angleRadians = launchAngleDegrees * .pi / 180
        let vx = exitVelocity * cos(angleRadians)
        let vy = exitVelocity * sin(angleRadians)
        let g = 9.81

        let points: [CalibratedPoint] = (0..<10).map { i in
            let t = Double(i) * 0.004
            let x = vx * t
            let y = vy * t - 0.5 * g * t * t
            return CalibratedPoint(xMeters: x, yMeters: y, depthMeters: 10, timestampSeconds: t)
        }

        guard let kinematics = VelocityRegression.kinematics(from: points) else {
            return XCTFail("Expected recovered kinematics")
        }
        XCTAssertEqual(kinematics.exitVelocityMetersPerSecond, exitVelocity, accuracy: 0.05)
        XCTAssertEqual(kinematics.launchAngleDegrees, launchAngleDegrees, accuracy: 0.1)
    }

    func testDeviceLevelPitchCorrectsLaunchAngle() {
        let points: [CalibratedPoint] = (0..<10).map { i in
            let t = Double(i) * 0.004
            return CalibratedPoint(xMeters: 40 * t, yMeters: 0, depthMeters: 10, timestampSeconds: t)
        }
        guard let level = VelocityRegression.kinematics(from: points, deviceLevelPitchDegrees: 0),
              let tilted = VelocityRegression.kinematics(from: points, deviceLevelPitchDegrees: 5) else {
            return XCTFail("Expected recovered kinematics")
        }
        XCTAssertEqual(tilted.launchAngleDegrees, level.launchAngleDegrees - 5, accuracy: 1e-6)
    }

    func testReturnsNilWithTooFewPoints() {
        let points = [
            CalibratedPoint(xMeters: 0, yMeters: 0, depthMeters: 10, timestampSeconds: 0),
            CalibratedPoint(xMeters: 1, yMeters: 1, depthMeters: 10, timestampSeconds: 0.01),
        ]
        XCTAssertNil(VelocityRegression.kinematics(from: points))
    }
}

final class DragFlightModelTests: XCTestCase {
    /// A batted ball at 100 mph / 25 degrees is a well-documented Statcast combo
    /// ("barreled" territory); real carry distances at that combo commonly fall
    /// in the low-to-mid 300s of feet. This model (constant drag coefficient, no
    /// spin/lift) computes ~319ft for these inputs — asserted with generous
    /// tolerance since it's an MVP approximation, not a Statcast-calibrated model.
    func testKnownExitVelocityAndAngleProducesExpectedDragAdjustedDistance() {
        let mph100 = 100.0 * 0.44704
        let result = DragFlightModel.project(exitVelocityMetersPerSecond: mph100, launchAngleDegrees: 25)
        let distanceFeet = result.carryDistanceMeters * 3.280839895
        XCTAssertEqual(distanceFeet, 319, accuracy: 20)
    }

    /// The core requirement from docs/ASSESSMENT.md §2.6: the vacuum formula
    /// R = v^2*sin(2*theta)/g ignores drag and overestimates real batted-ball
    /// distance by a wide margin. The drag model must always fall well short of it.
    func testDragDistanceIsSubstantiallyLessThanVacuumFormula() {
        let mph100 = 100.0 * 0.44704
        let angle = 28.0
        let result = DragFlightModel.project(exitVelocityMetersPerSecond: mph100, launchAngleDegrees: angle)
        let vacuumDistance = mph100 * mph100 * sin(2 * angle * .pi / 180) / 9.81
        XCTAssertLessThan(result.carryDistanceMeters, vacuumDistance * 0.75)
    }

    func testZeroVelocityProducesNoDistance() {
        let result = DragFlightModel.project(exitVelocityMetersPerSecond: 0, launchAngleDegrees: 25)
        XCTAssertEqual(result.carryDistanceMeters, 0, accuracy: 1e-9)
    }

    /// Drag mildly pulls the optimal launch angle for max distance below 45
    /// degrees (a well-known result for projectiles with drag and no lift); a
    /// very high launch angle should carry noticeably less than a near-optimal one.
    func testVeryHighLaunchAngleCarriesLessThanNearOptimalAngle() {
        let mph100 = 100.0 * 0.44704
        let nearOptimal = DragFlightModel.project(exitVelocityMetersPerSecond: mph100, launchAngleDegrees: 40)
        let high = DragFlightModel.project(exitVelocityMetersPerSecond: mph100, launchAngleDegrees: 60)
        XCTAssertLessThan(high.carryDistanceMeters, nearOptimal.carryDistanceMeters)
    }
}

final class PhysicsEngineTests: XCTestCase {
    func testComputeMetricsEndToEnd() {
        let exitVelocity = 44.7 // ~100 mph
        let launchAngleDegrees = 25.0
        let angleRadians = launchAngleDegrees * .pi / 180
        let vx = exitVelocity * cos(angleRadians)
        let vy = exitVelocity * sin(angleRadians)
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
        let trajectory = CalibratedTrajectory(points: points, calibrationMethod: "test")

        guard let metrics = PhysicsEngine.computeMetrics(from: trajectory) else {
            return XCTFail("Expected computed metrics")
        }
        XCTAssertEqual(metrics.exitVelocityMph, 100, accuracy: 1)
        XCTAssertEqual(metrics.launchAngleDegrees, launchAngleDegrees, accuracy: 0.5)
        XCTAssertGreaterThan(metrics.estimatedDistanceFeet, 250)
        XCTAssertLessThan(metrics.estimatedDistanceFeet, 400)
    }
}
