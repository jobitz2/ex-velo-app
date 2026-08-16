import AVFoundation
import CoreMedia

enum ClipWriter {
    enum ClipWriterError: Error {
        case emptyBuffer
        case cannotAddInput
        case unknown
    }

    static func write(buffers: [CMSampleBuffer], to url: URL) async throws {
        guard let first = buffers.first,
              let formatDescription = CMSampleBufferGetFormatDescription(first) else {
            throw ClipWriterError.emptyBuffer
        }
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(dimensions.width),
            AVVideoHeightKey: Int(dimensions.height),
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        guard writer.canAdd(input) else { throw ClipWriterError.cannotAddInput }
        writer.add(input)

        writer.startWriting()
        writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(first))

        for buffer in buffers {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(2))
            }
            input.append(buffer)
        }
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status == .failed {
            throw writer.error ?? ClipWriterError.unknown
        }
    }
}
