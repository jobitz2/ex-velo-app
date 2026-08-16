import CoreGraphics
import Foundation

/// Derives distance-to-ball from its known real-world size and apparent pixel size,
/// per docs/ASSESSMENT.md §2.4.1. Requires no extra hardware or user setup beyond
/// framing the shot, so this is the primary MVP strategy.
struct KnownObjectSizeCalibration: CalibrationStrategy {
    func calibrate(trajectory: TrackedTrajectory, context: CalibrationContext) -> CalibratedTrajectory? {
        guard !trajectory.detectedPoints.isEmpty else { return nil }

        let focalLengthPixels = CalibrationMath.focalLengthPixels(
            imageWidthPixels: context.frameWidthPixels,
            horizontalFieldOfViewDegrees: context.horizontalFieldOfViewDegrees
        )

        // Vision only exposes an observation-level moving-average radius (not a
        // per-point radius), normalized against image width to match Apple's
        // WWDC20 "Action & Vision" sample usage. That means depth is derived once
        // for the whole trajectory rather than per frame — an acceptable
        // approximation given the short post-contact window this MVP analyzes.
        let ballRadiusPixels = trajectory.averageRadius * CGFloat(context.frameWidthPixels)
        guard ballRadiusPixels > 0 else { return nil }
        let depthMeters = (BaseballConstants.radiusMeters * focalLengthPixels) / Double(ballRadiusPixels)

        let points = CalibrationGeometry.points(
            from: trajectory,
            depthMeters: depthMeters,
            focalLengthPixels: focalLengthPixels,
            context: context,
            heightOffsetMeters: 0
        )
        return CalibratedTrajectory(points: points, calibrationMethod: "known-object-size")
    }
}
