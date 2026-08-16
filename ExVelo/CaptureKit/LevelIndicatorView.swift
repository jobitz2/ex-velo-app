import SwiftUI

struct LevelIndicatorView: View {
    let pitchDegrees: Double
    let rollDegrees: Double

    private var isLevel: Bool { abs(pitchDegrees) < 2 && abs(rollDegrees) < 2 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                .frame(width: 60, height: 60)
            Circle()
                .fill(isLevel ? Color.green : Color.yellow)
                .frame(width: 14, height: 14)
                .offset(x: CGFloat(rollDegrees) * 2, y: CGFloat(pitchDegrees) * 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLevel ? "Level" : "Not level")
    }
}

#Preview {
    LevelIndicatorView(pitchDegrees: 1, rollDegrees: -3)
        .padding()
        .background(Color.black)
}
