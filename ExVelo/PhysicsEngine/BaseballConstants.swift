/// Physical constants for a regulation baseball, shared by CalibrationEngine
/// (known-object-size depth estimation) and PhysicsEngine (drag model) so the
/// two never drift out of sync.
enum BaseballConstants {
    /// ~2.9in / 7.35cm diameter, halved.
    static let radiusMeters = 0.03675
    static let massKg = 0.145
}
