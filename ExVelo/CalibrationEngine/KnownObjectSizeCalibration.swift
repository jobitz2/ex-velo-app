import CoreGraphics
import Foundation

/// Derives distance-to-ball from its known real-world size and apparent pixel size,
/// per docs/ASSESSMENT.md §2.4.1. This is the app's sole calibration strategy — it
/// requires no extra hardware or user setup beyond framing the shot.
enum KnownObjectSizeCalibration {
    /// `radiusPixels`, parallel to `trajectory.detectedPoints`, is each point's own
    /// measured apparent ball radius (see BallRadiusEstimator) — used to derive a
    /// per-point depth so a ball moving toward/away from the camera, or on any
    /// angled path, is calibrated correctly instead of assumed to stay at a
    /// constant distance for the whole trajectory. Any point beyond
    /// `radiusPixels`'s length (a frame whose measurement was inconclusive) falls
    /// back to Vision's trajectory-wide average radius.
    static func calibrate(trajectory: TrackedTrajectory, radiusPixels: [CGFloat], context: CalibrationContext) -> CalibratedTrajectory? {
        guard !trajectory.detectedPoints.isEmpty else { return nil }

        let focalLengthPixels = CalibrationMath.focalLengthPixels(
            imageWidthPixels: context.frameWidthPixels,
            horizontalFieldOfViewDegrees: context.horizontalFieldOfViewDegrees
        )

        let fallbackRadiusPixels = trajectory.averageRadius * CGFloat(context.frameWidthPixels)
        let depthsMeters: [Double] = trajectory.detectedPoints.indices.map { index in
            let ballRadiusPixels = index < radiusPixels.count && radiusPixels[index] > 0 ? radiusPixels[index] : fallbackRadiusPixels
            guard ballRadiusPixels > 0 else { return 0 }
            return (BaseballConstants.radiusMeters * focalLengthPixels) / Double(ballRadiusPixels)
        }
        guard depthsMeters.allSatisfy({ $0 > 0 }) else { return nil }

        let points = CalibrationGeometry.points(
            from: trajectory,
            depthsMeters: depthsMeters,
            focalLengthPixels: focalLengthPixels,
            context: context
        )
        return CalibratedTrajectory(points: points)
    }
}
