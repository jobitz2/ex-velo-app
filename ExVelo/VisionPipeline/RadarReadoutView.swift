import SwiftUI

/// The core radar-gun readout: a big speed number while a ball is tracked, or a
/// scanning indicator while waiting for the next pitch/hit to cross the frame.
struct RadarReadoutView: View {
    let status: RadarGunCoordinator.Status

    var body: some View {
        Group {
            switch status {
            case .scanning:
                VStack(spacing: 4) {
                    Text("--")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("SCANNING")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            case let .reading(speedMph):
                VStack(spacing: 4) {
                    Text(speedMph, format: .number.precision(.fractionLength(1)))
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("MPH")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .animation(.default, value: status)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        RadarReadoutView(status: .reading(speedMph: 87.3))
    }
}
