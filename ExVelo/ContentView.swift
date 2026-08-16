import SwiftUI

struct ContentView: View {
    @StateObject private var analysisCoordinator = SwingAnalysisCoordinator()

    var body: some View {
        ZStack(alignment: .top) {
            CaptureView { url in
                Task {
                    await analysisCoordinator.analyze(clipAt: url)
                }
            }
            SwingAnalysisStatusView(status: analysisCoordinator.status)
                .padding(.top, 60)
        }
    }
}

#Preview {
    ContentView()
}
