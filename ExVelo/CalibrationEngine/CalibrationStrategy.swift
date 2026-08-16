/// A swappable strategy for solving the monocular scale problem: turning a
/// trajectory's normalized image-plane points into real-world positions.
/// See docs/ASSESSMENT.md §2.4/§6 for the three-tier design this protocol enables
/// (known-object-size → guided-placement → LiDAR, added later without touching
/// callers of CalibrationEngine).
protocol CalibrationStrategy {
    func calibrate(trajectory: TrackedTrajectory, context: CalibrationContext) -> CalibratedTrajectory?
}

/// Tries each strategy in order and returns the first that can produce a result.
/// Order is priority: a more accurate strategy (e.g. a future LiDARCalibration)
/// is simply prepended, with no changes needed anywhere else in the pipeline.
struct CalibrationEngine {
    let strategies: [CalibrationStrategy]

    static let `default` = CalibrationEngine(strategies: [
        KnownObjectSizeCalibration(),
        GuidedPlacementCalibration(),
    ])

    func calibrate(trajectory: TrackedTrajectory, context: CalibrationContext) -> CalibratedTrajectory? {
        for strategy in strategies {
            if let result = strategy.calibrate(trajectory: trajectory, context: context) {
                return result
            }
        }
        return nil
    }
}
