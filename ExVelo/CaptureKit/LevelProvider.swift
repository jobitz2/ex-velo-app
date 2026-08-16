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
            self.rollDegrees = motion.attitude.roll * 180 / .pi
            self.pitchDegrees = motion.attitude.pitch * 180 / .pi
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    /// The horizontal reference PhysicsEngine measures launch angle against,
    /// derived from the device's pitch rather than the raw video frame.
    var horizontalReferenceDegrees: Double { pitchDegrees }
}
