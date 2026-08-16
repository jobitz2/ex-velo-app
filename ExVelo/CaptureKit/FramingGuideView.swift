import SwiftUI

/// Suggests where to place the ball/tee in frame so the fixed-distance and
/// known-object-size calibration strategies both have a predictable starting point.
struct FramingGuideView: View {
    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(
                x: proxy.size.width * 0.15,
                y: proxy.size.height * 0.35,
                width: proxy.size.width * 0.7,
                height: proxy.size.height * 0.3
            )
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    FramingGuideView()
        .background(Color.black)
}
