// macOS 12+ / Swift from Xcode 14: no packages, network, or installation.
// Usage: xcrun swift encode_motion.swift /path/to/frames /path/to/new-preview.mp4
import Foundation
import AVFoundation
import CoreGraphics
import CoreVideo
import ImageIO

enum EncodeError: Error, CustomStringConvertible {
    case failed(String)
    var description: String {
        switch self { case .failed(let text): return text }
    }
}

let width = 560, height = 700, frameCount = 180
let fps: Int32 = 30

func fail(_ message: String) -> EncodeError { .failed(message) }

func loadFrame(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw fail("Cannot decode PNG: \(url.path)")
    }
    guard image.width == width && image.height == height else {
        throw fail("Wrong dimensions in \(url.lastPathComponent): \(image.width)x\(image.height), expected \(width)x\(height)")
    }
    return image
}

func encode() throws {
    guard CommandLine.arguments.count == 3 else {
        throw fail("Usage: xcrun swift encode_motion.swift FRAME_DIRECTORY NEW_OUTPUT.mp4")
    }
    let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let output = URL(fileURLWithPath: CommandLine.arguments[2])
    guard output.pathExtension.lowercased() == "mp4" else { throw fail("Output must end in .mp4") }
    guard !FileManager.default.fileExists(atPath: output.path) else {
        throw fail("Refusing to overwrite existing output: \(output.path)")
    }
    let frames = (0..<frameCount).map {
        directory.appendingPathComponent(String(format: "frame-%04d.png", $0))
    }
    // Validate every source before creating an output; extra unrelated files are ignored.
    for url in frames { try autoreleasepool { _ = try loadFrame(url) } }

    let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
    var completed = false
    defer { if !completed && writer.status == .writing { writer.cancelWriting() } }
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width, AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 3_000_000,
            AVVideoExpectedSourceFrameRateKey: fps,
            AVVideoMaxKeyFrameIntervalKey: fps,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        ]
    ]
    guard writer.canApply(outputSettings: settings, forMediaType: .video) else {
        throw fail("H.264 settings are unsupported on this Mac")
    }
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false
    guard writer.canAdd(input) else { throw fail("Cannot add video input") }
    writer.add(input)
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ])
    guard writer.startWriting() else { throw fail("startWriting: \(String(describing: writer.error))") }
    writer.startSession(atSourceTime: .zero)
    guard let pool = adaptor.pixelBufferPool else { throw fail("Pixel buffer pool unavailable") }
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var appended = 0
    for (index, url) in frames.enumerated() {
        try autoreleasepool {
            let deadline = Date().addingTimeInterval(30)
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing else { throw fail("Writer stopped: \(String(describing: writer.error))") }
                guard Date() < deadline else { throw fail("Encoder readiness timeout at frame \(index)") }
                Thread.sleep(forTimeInterval: 0.002)
            }
            let image = try loadFrame(url)
            var optionalBuffer: CVPixelBuffer?
            let allocation = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer)
            guard allocation == kCVReturnSuccess, let buffer = optionalBuffer else {
                throw fail("Pixel buffer allocation failed: \(allocation)")
            }
            guard CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess else {
                throw fail("Pixel buffer lock failed")
            }
            defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
            guard let address = CVPixelBufferGetBaseAddress(buffer),
                  let context = CGContext(data: address, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                    space: colorSpace,
                    bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else {
                throw fail("Cannot create BGRA drawing context")
            }
            let rect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
            // Opaque dark backdrop under transparent pixels; source PNGs draw over it.
            context.setFillColor(red: 0.04, green: 0.07, blue: 0.09, alpha: 1)
            context.fill(rect)
            context.interpolationQuality = .high
            context.draw(image, in: rect)
            let time = CMTime(value: Int64(index), timescale: fps)
            guard adaptor.append(buffer, withPresentationTime: time) else {
                throw fail("Cannot append frame \(index): \(String(describing: writer.error))")
            }
            appended += 1
        }
    }
    input.markAsFinished()
    writer.endSession(atSourceTime: CMTime(value: Int64(frameCount), timescale: fps))
    let finished = DispatchSemaphore(value: 0)
    writer.finishWriting { finished.signal() }
    guard finished.wait(timeout: .now() + 60) == .success else { throw fail("finishWriting timed out") }
    guard writer.status == .completed else { throw fail("Encoding failed: \(String(describing: writer.error))") }
    completed = true

    // Independently decode the MP4 to verify actual output, not just append calls.
    let asset = AVURLAsset(url: output)
    guard let track = asset.tracks(withMediaType: .video).first else { throw fail("Output contains no video track") }
    let reader = try AVAssetReader(asset: asset)
    let decoded = AVAssetReaderTrackOutput(track: track,
        outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    guard reader.canAdd(decoded) else { throw fail("Cannot attach output verification reader") }
    reader.add(decoded)
    guard reader.startReading() else { throw fail("Cannot read output: \(String(describing: reader.error))") }
    var decodedCount = 0
    while autoreleasepool(invoking: { () -> Bool in
        guard let sample = decoded.copyNextSampleBuffer() else { return false }
        if let buffer = CMSampleBufferGetImageBuffer(sample),
           CVPixelBufferGetWidth(buffer) == width, CVPixelBufferGetHeight(buffer) == height {
            decodedCount += 1
        }
        return true
    }) {}
    guard reader.status == .completed, appended == frameCount, decodedCount == frameCount else {
        throw fail("Verification failed: appended=\(appended), decoded=\(decodedCount), reader=\(reader.status.rawValue), error=\(String(describing: reader.error))")
    }
    let duration = CMTimeGetSeconds(asset.duration)
    guard duration.isFinite, abs(duration - 6.0) <= 1.0 / Double(fps) else {
        throw fail("Unexpected output duration: \(duration)")
    }
    print("VERIFIED: \(decodedCount) decoded frames, \(width)x\(height), \(fps) fps, \(duration) seconds -> \(output.path)")
}

do { try encode() }
catch {
    FileHandle.standardError.write(Data("ENCODE FAILED: \(error)\n".utf8))
    exit(1)
}
