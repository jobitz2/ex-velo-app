import Foundation

/// Numerically integrates a batted ball's flight forward from its exit velocity
/// and launch angle, applying air drag, instead of the vacuum projectile-range
/// formula R = v^2*sin(2*theta)/g (which ignores drag and overestimates distance
/// by a wide margin at baseball speeds). Magnus lift from spin is a documented V2
/// enhancement (see docs/ASSESSMENT.md §2.6) — not modeled here, since spin isn't
/// measured yet.
enum DragFlightModel {
    struct Parameters {
        var ballMassKg = BaseballConstants.massKg
        var ballRadiusMeters = BaseballConstants.radiusMeters
        var dragCoefficient = 0.35
        var airDensityKgPerCubicMeter = 1.225
        var gravityMetersPerSecondSquared = 9.81
        var timeStepSeconds = 0.001
        var maxFlightTimeSeconds = 10.0
    }

    struct Result {
        let carryDistanceMeters: Double
        let flightTimeSeconds: Double
        let apexHeightMeters: Double
    }

    /// Projects flight from launch until the ball returns to launch height (the
    /// same height-datum convention the vacuum formula uses, so this is a drop-in,
    /// more realistic replacement for it).
    static func project(
        exitVelocityMetersPerSecond: Double,
        launchAngleDegrees: Double,
        parameters: Parameters = Parameters()
    ) -> Result {
        let angleRadians = launchAngleDegrees * .pi / 180
        var vx = exitVelocityMetersPerSecond * cos(angleRadians)
        var vy = exitVelocityMetersPerSecond * sin(angleRadians)
        var x = 0.0
        var y = 0.0
        var apex = 0.0
        var t = 0.0

        let area = Double.pi * parameters.ballRadiusMeters * parameters.ballRadiusMeters
        let dragFactor = 0.5 * parameters.airDensityKgPerCubicMeter * parameters.dragCoefficient * area / parameters.ballMassKg
        let dt = parameters.timeStepSeconds

        while t < parameters.maxFlightTimeSeconds {
            let speed = (vx * vx + vy * vy).squareRoot()
            let dragAx = speed > 0 ? -dragFactor * speed * vx : 0
            let dragAy = speed > 0 ? -dragFactor * speed * vy : 0
            let ay = dragAy - parameters.gravityMetersPerSecondSquared

            vx += dragAx * dt
            vy += ay * dt
            x += vx * dt
            y += vy * dt
            t += dt

            apex = max(apex, y)

            if y <= 0 && t > dt {
                break
            }
        }

        return Result(carryDistanceMeters: x, flightTimeSeconds: t, apexHeightMeters: apex)
    }
}
