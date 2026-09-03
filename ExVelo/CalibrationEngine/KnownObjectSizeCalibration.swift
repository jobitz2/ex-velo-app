import CoreGraphics
import Foundation

/// Derives distance-to-ball from its known real-world size and apparent pixel size,
/// per docs/ASSESSMENT.md §2.4.1. This is the app's sole calibration strategy — it
/// requires no extra hardware or user setup beyond framing the shot.
enum KnownObjectSizeCalibration {
    static func calibrate(trajectory: TrackedTrajectory, context: CalibrationContext) -> CalibratedTrajectory? {
        guard !trajectory.detectedPoints.isEmpty else { return nil }

        let focalLengthPixels = CalibrationMath.focalLengthPixels(
            imageWidthPixels: context.frameWidthPixels,
            horizontalFieldOfViewDegrees: context.horizontalFieldOfViewDegrees
        )

        // Vision only exposes an observation-level moving-average radius (not a
        // per-point radius), normalized against image width to match Apple's
        // WWDC20 "Action & Vision" sample usage. That means depth is derived once
        // for the whole trajectory rather than per frame — an acceptable
        // approximation given the short tracked window this reads.
        let ballRadiusPixels = trajectory.averageRadius * CGFloat(context.frameWidthPixels)
        guard ballRadiusPixels > 0 else { return nil }
        let depthMeters = (BaseballConstants.radiusMeters * focalLengthPixels) / Double(ballRadiusPixels)

        let points = CalibrationGeometry.points(
            from: trajectory,
            depthMeters: depthMeters,
            focalLengthPixels: focalLengthPixels,
            context: context
        )
        return CalibratedTrajectory(points: points)
    }
}
