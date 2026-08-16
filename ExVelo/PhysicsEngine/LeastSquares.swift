import Foundation

/// Small, dependency-free ordinary-least-squares fits used to recover the initial
/// velocity vector from a handful of tracked points.
enum LeastSquares {
    /// Fits y = m*t + b.
    static func linearFit(_ samples: [(t: Double, y: Double)]) -> (slope: Double, intercept: Double)? {
        guard samples.count >= 2 else { return nil }
        let n = Double(samples.count)
        var sumT = 0.0, sumY = 0.0, sumTY = 0.0, sumT2 = 0.0
        for sample in samples {
            sumT += sample.t
            sumY += sample.y
            sumTY += sample.t * sample.y
            sumT2 += sample.t * sample.t
        }
        let denominator = n * sumT2 - sumT * sumT
        guard abs(denominator) > .ulpOfOne else { return nil }
        let slope = (n * sumTY - sumT * sumY) / denominator
        let intercept = (sumY - slope * sumT) / n
        return (slope: slope, intercept: intercept)
    }

    /// Fits y = a*t^2 + b*t + c via the normal equations, solved with Cramer's rule.
    static func quadraticFit(_ samples: [(t: Double, y: Double)]) -> (a: Double, b: Double, c: Double)? {
        guard samples.count >= 3 else { return nil }
        let n = Double(samples.count)
        var sumT = 0.0, sumT2 = 0.0, sumT3 = 0.0, sumT4 = 0.0
        var sumY = 0.0, sumTY = 0.0, sumT2Y = 0.0
        for sample in samples {
            let t = sample.t
            let y = sample.y
            let t2 = t * t
            sumT += t
            sumT2 += t2
            sumT3 += t2 * t
            sumT4 += t2 * t2
            sumY += y
            sumTY += t * y
            sumT2Y += t2 * y
        }

        // Normal equations for [a, b, c]:
        // [sumT4 sumT3 sumT2] [a]   [sumT2Y]
        // [sumT3 sumT2 sumT ] [b] = [sumTY ]
        // [sumT2 sumT  n    ] [c]   [sumY  ]
        guard let solution = solve3x3(
            rows: [
                (sumT4, sumT3, sumT2),
                (sumT3, sumT2, sumT),
                (sumT2, sumT, n),
            ],
            rhs: (sumT2Y, sumTY, sumY)
        ) else { return nil }
        return (a: solution.0, b: solution.1, c: solution.2)
    }

    private static func solve3x3(
        rows: [(Double, Double, Double)],
        rhs: (Double, Double, Double)
    ) -> (Double, Double, Double)? {
        func determinant(_ m: [[Double]]) -> Double {
            m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
                - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
                + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
        }

        let (a1, b1, c1) = rows[0]
        let (a2, b2, c2) = rows[1]
        let (a3, b3, c3) = rows[2]
        let (d1, d2, d3) = rhs

        let mainMatrix = [[a1, b1, c1], [a2, b2, c2], [a3, b3, c3]]
        let determinantMain = determinant(mainMatrix)
        guard abs(determinantMain) > 1e-12 else { return nil }

        let xMatrix = [[d1, b1, c1], [d2, b2, c2], [d3, b3, c3]]
        let yMatrix = [[a1, d1, c1], [a2, d2, c2], [a3, d3, c3]]
        let zMatrix = [[a1, b1, d1], [a2, b2, d2], [a3, b3, d3]]

        return (
            determinant(xMatrix) / determinantMain,
            determinant(yMatrix) / determinantMain,
            determinant(zMatrix) / determinantMain
        )
    }
}
