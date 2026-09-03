import Foundation

/// Shared pixel-to-meters conversion, given a per-point depth derived by
/// KnownObjectSizeCalibration from that point's own apparent ball radius —
/// not a single depth shared across the whole trajectory, so a ball moving
/// toward/away from the camera (or on any non-lateral path) is represented
/// correctly instead of assumed to stay at a constant distance.
enum CalibrationGeometry {
    static func points(
        from trajectory: TrackedTrajectory,
        depthsMeters: [Double],
        focalLengthPixels: Double,
        context: CalibrationContext
    ) -> [CalibratedPoint] {
        let principalX = Double(context.frameWidthPixels) / 2
        let principalY = Double(context.frameHeightPixels) / 2
        let detectedPoints = trajectory.detectedPoints
        let durationSeconds = trajectory.timeRange.duration.seconds

        return detectedPoints.enumerated().map { index, point in
            let depthMeters = depthsMeters[index]

            // Vision points are normalized (0...1) with a lower-left origin; flip Y
            // to a top-left pixel space before measuring the offset from center.
            let pixelX = Double(point.normalizedLocation.x) * Double(context.frameWidthPixels)
            let pixelY = (1 - Double(point.normalizedLocation.y)) * Double(context.frameHeightPixels)

            let xMeters = (pixelX - principalX) * depthMeters / focalLengthPixels
            let yMeters = (principalY - pixelY) * depthMeters / focalLengthPixels

            // detectedPoints don't carry individual timestamps, only the
            // observation's overall time range, so samples are treated as evenly
            // spaced across it.
            let fraction = detectedPoints.count > 1 ? Double(index) / Double(detectedPoints.count - 1) : 0
            let timestamp = durationSeconds * fraction

            return CalibratedPoint(xMeters: xMeters, yMeters: yMeters, depthMeters: depthMeters, timestampSeconds: timestamp)
        }
    }
}
