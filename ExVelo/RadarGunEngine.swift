import CoreMedia
import Foundation

/// Consumes live camera frames off the main actor and turns them into a speed
/// reading: track the ball, calibrate its trajectory to real-world units, and
/// regress out a speed the moment enough points are tracked. Kept as a plain
/// (non-actor) class, called only from the capture session's sample-buffer queue —
/// Vision's per-frame cost is exactly why this must never touch the main thread.
final class RadarGunEngine {
    struct Reading {
        let trajectory: TrackedTrajectory?
        let speedMph: Double?
    }

    /// How long a trajectory can go without a new point before scanning resets, so
    /// the next thrown/hit ball starts a fresh reading instead of blending with a
    /// stale, no-longer-moving one.
    private let staleAfterSeconds: TimeInterval = 1.0

    private let tracker = LiveTrajectoryTracker()
    private var geometry: CameraGeometry?
    private var lastActivity: CFAbsoluteTime = 0

    func updateGeometry(_ geometry: CameraGeometry) {
        self.geometry = geometry
    }

    /// Clears tracked state so the next scan starts fresh — called when a new
    /// press-and-hold scan begins.
    func reset() {
        tracker.reset()
        lastActivity = 0
    }

    /// Call only from the sample-buffer delegate queue.
    func ingest(_ sampleBuffer: CMSampleBuffer) -> Reading {
        let now = CFAbsoluteTimeGetCurrent()
        if lastActivity > 0, now - lastActivity > staleAfterSeconds {
            tracker.reset()
        }

        let tracked = tracker.process(sampleBuffer: sampleBuffer)
        // The longest tracked trajectory is the likeliest candidate for the actual
        // ball; shorter ones are more often background clutter.
        guard let geometry, let best = tracked.max(by: { $0.trajectory.detectedPoints.count < $1.trajectory.detectedPoints.count }) else {
            return Reading(trajectory: nil, speedMph: nil)
        }
        lastActivity = now

        let context = CalibrationContext(
            frameWidthPixels: geometry.pixelWidth,
            frameHeightPixels: geometry.pixelHeight,
            horizontalFieldOfViewDegrees: geometry.horizontalFieldOfViewDegrees
        )
        guard let calibrated = KnownObjectSizeCalibration.calibrate(trajectory: best.trajectory, radiusPixels: best.radiusPixels, context: context),
              let speedMph = PhysicsEngine.computeSpeedMph(from: calibrated) else {
            return Reading(trajectory: best.trajectory, speedMph: nil)
        }
        return Reading(trajectory: best.trajectory, speedMph: speedMph)
    }
}
