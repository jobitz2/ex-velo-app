import CoreGraphics
import CoreVideo

/// Vision's VNDetectTrajectoriesRequest only reports one moving-average ball
/// radius for an entire trajectory (see TrackedTrajectory.averageRadius), which
/// implicitly assumes the ball stays at a constant distance from the camera for
/// the whole tracked window. That's wrong whenever the ball is thrown/hit toward
/// or away from the camera, or on any path that isn't purely lateral: its
/// apparent size actually changes frame to frame as it gets closer or farther.
/// This measures that per-frame apparent radius directly from the pixel buffer,
/// independent of Vision's aggregate estimate, so KnownObjectSizeCalibration can
/// derive a per-point depth instead of one shared depth for the whole trajectory.
enum BallRadiusEstimator {
    /// Casts rays outward from a point in 8 directions looking for the
    /// brightness-gradient edge of the ball against its background (the
    /// strongest intensity jump along each ray), and returns the median ray
    /// length as the apparent radius in pixels. `hintRadiusPixels` — Vision's own
    /// aggregate estimate — bounds the search window; it doesn't bias the result.
    /// Returns `nil` when too few rays find a clear edge to trust the
    /// measurement (e.g. the ball is against a low-contrast or cluttered
    /// background this frame).
    static func estimateRadiusPixels(
        pixelBuffer: CVPixelBuffer,
        normalizedPoint: CGPoint,
        hintRadiusPixels: CGFloat
    ) -> CGFloat? {
        guard hintRadiusPixels > 0 else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        // Plane 0 of a planar buffer (e.g. the live capture's NV12 frames) is
        // full-resolution 8-bit luma, which is exactly what we want; a
        // non-planar single-channel buffer (used in unit tests) reads the same
        // way from its one plane.
        let isPlanar = CVPixelBufferIsPlanar(pixelBuffer)
        guard let base = isPlanar ? CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) : CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }
        let width = isPlanar ? CVPixelBufferGetWidthOfPlane(pixelBuffer, 0) : CVPixelBufferGetWidth(pixelBuffer)
        let height = isPlanar ? CVPixelBufferGetHeightOfPlane(pixelBuffer, 0) : CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = isPlanar ? CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) : CVPixelBufferGetBytesPerRow(pixelBuffer)
        let luma = base.assumingMemoryBound(to: UInt8.self)

        func sample(_ x: Int, _ y: Int) -> Int? {
            guard x >= 0, x < width, y >= 0, y < height else { return nil }
            return Int(luma[y * bytesPerRow + x])
        }

        // Vision's points are normalized (0...1) with a lower-left origin.
        let centerX = Int(normalizedPoint.x * CGFloat(width))
        let centerY = Int((1 - normalizedPoint.y) * CGFloat(height))

        let maxSearch = Int((hintRadiusPixels * 3.5).rounded(.up))
        let minSearch = max(2, Int(hintRadiusPixels * 0.25))
        guard minSearch <= maxSearch, let centerValue = sample(centerX, centerY) else { return nil }

        let directionCount = 8
        var edgeDistances: [Int] = []
        for i in 0..<directionCount {
            let angle = Double(i) * .pi / Double(directionCount / 2)
            let dx = cos(angle)
            let dy = sin(angle)

            var previous = centerValue
            var bestEdgeStep: Int?
            var bestGradient = 0
            for step in minSearch...maxSearch {
                let x = centerX + Int((Double(step) * dx).rounded())
                let y = centerY + Int((Double(step) * dy).rounded())
                guard let value = sample(x, y) else { break }
                let gradient = abs(value - previous)
                if gradient > bestGradient {
                    bestGradient = gradient
                    bestEdgeStep = step
                }
                previous = value
            }
            // Require a real discontinuity, not sensor noise, before trusting
            // a ray's edge (luma is 0...255).
            if let bestEdgeStep, bestGradient > 18 {
                edgeDistances.append(bestEdgeStep)
            }
        }

        // Need most rays to agree there's an edge before trusting the frame;
        // background clutter easily fools one or two individual rays.
        guard edgeDistances.count >= 5 else { return nil }
        edgeDistances.sort()
        return CGFloat(edgeDistances[edgeDistances.count / 2])
    }
}
