import CoreMedia

/// Holds a short window of recently captured frames so a swing can be trimmed
/// out of continuous capture after the fact, instead of requiring the user to
/// start recording before contact.
actor RollingFrameBuffer {
    private var buffers: [CMSampleBuffer] = []
    private let retainedDuration: TimeInterval

    init(retainedDuration: TimeInterval) {
        self.retainedDuration = retainedDuration
    }

    func append(_ buffer: CMSampleBuffer) {
        buffers.append(buffer)
        evictOld(relativeTo: buffer)
    }

    func snapshot() -> [CMSampleBuffer] {
        buffers
    }

    private func evictOld(relativeTo latest: CMSampleBuffer) {
        let latestTime = CMSampleBufferGetPresentationTimeStamp(latest)
        let cutoff = CMTimeSubtract(latestTime, CMTime(seconds: retainedDuration, preferredTimescale: 600))
        buffers.removeAll { CMSampleBufferGetPresentationTimeStamp($0) < cutoff }
    }
}
