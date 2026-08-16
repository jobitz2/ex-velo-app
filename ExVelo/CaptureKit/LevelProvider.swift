import CoreMotion

/// Publishes device tilt so the framing guide can show a level indicator and so
/// PhysicsEngine has a horizontal reference independent of how the phone is held.
@MainActor
final class LevelProvider: ObservableObject {
    @Published private(set) var rollDegrees: Double = 0
    @Published private(set) var pitchDegrees: Double = 0

    private let motionManager = CMMotionManager()

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            // CMAttitude's pitch/roll are relative to the phone lying flat on a
            // table (both 0 there), which is useless for a phone held upright like
            // a camera. Deriving level from the raw gravity vector instead — same
            // technique camera bubble-level apps use — makes "level" mean "held
            // upright, pointed at true horizontal" rather than "lying flat."
            let gravity = motion.gravity
            let rollRadians = atan2(gravity.x, -gravity.y)
            let tiltRadians = atan2(gravity.z, -gravity.y)
            self.rollDegrees = rollRadians * 180 / .pi
            self.pitchDegrees = tiltRadians * 180 / .pi
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    /// The horizontal reference PhysicsEngine measures launch angle against: how
    /// far the camera axis is tilted up/down from true horizontal, derived from
    /// gravity rather than the raw video frame.
    var horizontalReferenceDegrees: Double { pitchDegrees }
}
