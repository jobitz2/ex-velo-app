import CoreMotion
import Foundation

/// Tracks whether the device is currently held steady enough to trust a
/// reading. VNDetectTrajectoriesRequest has no notion of camera motion — if the
/// phone itself pans or shakes, stationary background objects appear to move
/// across the frame exactly like a thrown ball would, and Vision can report
/// that as a bogus trajectory. This flags frames captured during meaningful
/// device rotation so RadarGunEngine can skip them instead of feeding shake
/// into the tracker.
final class MotionStabilityMonitor {
    /// Rotation rate (rad/s) above which the device is considered to be
    /// panning/shaking rather than just naturally handheld — a starting point
    /// tuned generously above typical hand tremor; may need adjusting against
    /// real handheld footage.
    private let rotationRateThreshold = 0.6

    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()

    /// Read from the sample-buffer queue inside RadarGunEngine; written from
    /// CMMotionManager's own update queue. Defaults to `true` so the first few
    /// frames before any motion sample has arrived aren't blocked.
    nonisolated(unsafe) private(set) var isStable = true

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        isStable = true
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let rate = motion.rotationRate
            let magnitude = (rate.x * rate.x + rate.y * rate.y + rate.z * rate.z).squareRoot()
            self.isStable = magnitude < self.rotationRateThreshold
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        isStable = true
    }
}
