import SwiftUI

struct ContentView: View {
    @StateObject private var captureController = CaptureSessionController()
    @StateObject private var radarGun = RadarGunCoordinator()

    var body: some View {
        CaptureView(captureController: captureController, radarGun: radarGun)
    }
}

#Preview {
    ContentView()
}
