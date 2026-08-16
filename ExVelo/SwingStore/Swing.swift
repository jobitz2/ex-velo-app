import Foundation
import SwiftData

/// A single recorded swing's clip reference and computed metrics. Player/Session
/// grouping is a V1 item (see docs/ASSESSMENT.md milestone table) added once
/// profiles exist in the UI — MVP persists swings directly.
@Model
final class Swing {
    var capturedAt: Date
    var clipURL: URL?
    var exitVelocityMph: Double
    var launchAngleDegrees: Double
    var estimatedDistanceFeet: Double
    var calibrationMethod: String

    init(
        capturedAt: Date,
        clipURL: URL?,
        exitVelocityMph: Double,
        launchAngleDegrees: Double,
        estimatedDistanceFeet: Double,
        calibrationMethod: String
    ) {
        self.capturedAt = capturedAt
        self.clipURL = clipURL
        self.exitVelocityMph = exitVelocityMph
        self.launchAngleDegrees = launchAngleDegrees
        self.estimatedDistanceFeet = estimatedDistanceFeet
        self.calibrationMethod = calibrationMethod
    }
}
