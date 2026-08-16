import SwiftUI

/// Draws a trajectory's detected points over a video frame. Vision's points are
/// normalized (0...1) with a lower-left origin; SwiftUI is top-left, so Y is flipped.
struct TrajectoryOverlayView: View {
    let trajectory: TrackedTrajectory?

    var body: some View {
        Canvas { context, size in
            guard let trajectory else { return }
            for point in trajectory.detectedPoints {
                let x = point.normalizedLocation.x * size.width
                let y = (1 - point.normalizedLocation.y) * size.height
                let dot = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: dot), with: .color(.yellow))
            }
        }
        .allowsHitTesting(false)
    }
}
