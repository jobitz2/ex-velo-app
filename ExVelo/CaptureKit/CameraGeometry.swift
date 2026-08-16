/// The camera facts CalibrationEngine needs to turn pixel positions into real-world
/// distances: the active format's pixel dimensions and horizontal field of view.
struct CameraGeometry {
    let pixelWidth: Int
    let pixelHeight: Int
    let horizontalFieldOfViewDegrees: Float
}
