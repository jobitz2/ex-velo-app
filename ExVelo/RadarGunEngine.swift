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

    /// Vision's own measure of how well a trajectory's points fit a parabola
    /// (0...1). A trajectory built from camera shake or background clutter
    /// rather than a real ball tends to fit poorly; requiring a high confidence
    /// here is the main defense against handheld-shake false positives.
    private let minimumConfidence: Float = 0.85

    private let tracker = LiveTrajectoryTracker()
    private let motionMonitor = MotionStabilityMonitor()
    private var geometry: CameraGeometry?
    private var lastActivity: CFAbsoluteTime = 0

    func updateGeometry(_ geometry: CameraGeometry) {
        self.geometry = geometry
    }

    /// Starts device-motion monitoring — called when a scan begins.
    func start() {
        motionMonitor.start()
    }

    /// Stops device-motion monitoring — called when a scan ends.
    func stop() {
        motionMonitor.stop()
    }

    /// Clears tracked state so the next scan starts fresh — called when a new
    /// press-and-hold scan begins.
    func reset() {
        tracker.reset()
        lastActivity = 0
    }

    /// Call only from the sample-buffer delegate queue.
    func ingest(_ sampleBuffer: CMSampleBuffer) -> Reading {
        // The device itself moving makes stationary background objects appear
        // to move across the frame just like a thrown ball would; rather than
        // try to distinguish real motion from shake after the fact, skip
        // feeding these frames into the tracker at all, and drop whatever was
        // mid-track so it doesn't blend with clean frames once stability
        // returns.
        guard motionMonitor.isStable else {
            tracker.reset()
            return Reading(trajectory: nil, speedMph: nil)
        }

        let now = CFAbsoluteTimeGetCurrent()
        if lastActivity > 0, now - lastActivity > staleAfterSeconds {
            tracker.reset()
        }

        let tracked = tracker.process(sampleBuffer: sampleBuffer)
        // Filter to trajectories Vision itself is confident actually fit a
        // parabola before ranking by point count — a longer but poorly-fit
        // trajectory is more likely clutter than a real ball.
        let candidates = tracked.filter { $0.trajectory.confidence >= minimumConfidence }
        guard let geometry, let best = candidates.max(by: { $0.trajectory.detectedPoints.count < $1.trajectory.detectedPoints.count }) else {
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
