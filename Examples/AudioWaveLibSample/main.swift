import AudioWaveLib
import Cocoa
import Foundation

// Include shared components directly for this example
// In a real Swift Package, these would be proper module imports

// MARK: - AudioUtils (Extracted from shared utilities)
struct AudioUtils {
    static func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0.0 }
        let sumSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumSquares / Float(samples.count))
    }

    static func extractAudioMetrics(_ samples: [Float]) -> [String: Float] {
        guard !samples.isEmpty else { return [:] }
        let maxAmplitude = samples.max() ?? 0.0
        let minAmplitude = samples.min() ?? 0.0
        let rmsLevel = calculateRMS(samples)
        return [
            "maxAmplitude": maxAmplitude,
            "minAmplitude": minAmplitude,
            "rmsLevel": rmsLevel,
            "sampleCount": Float(samples.count)
        ]
    }
}

// MARK: - WaveformRenderer (Extracted from DemoDelegate)
class WaveformRenderer: NSObject, AudioWaveLibProviderDelegate, @unchecked Sendable {
    // Configuration properties
    var windowFillColor: NSColor = .white
    var fillColor: NSColor = .clear
    var strokeColor: NSColor = .black
    var lineWidth: CGFloat = 1.0

    private var window: NSWindow?

    func sampleProcessed(provider: AudioWaveLibProvider) {
        print("Sample processed")
        guard let sampleData = provider.sampleData else {
            print("No sample data available.")
            return
        }

        print("Sample data available - \(sampleData.count) samples")

        // Display metrics using shared utility
        let metrics = AudioUtils.extractAudioMetrics(sampleData)
        print("Audio metrics: Max: \(String(format: "%.3f", metrics["maxAmplitude"] ?? 0)), " +
              "RMS: \(String(format: "%.3f", metrics["rmsLevel"] ?? 0))")

        let imageSize = CGSize(width: 300, height: 100)
        if let image = generateWaveformImage(sampleData: sampleData, imageSize: imageSize) {
            print("Image generated")
            displayImage(image)
            saveImageToFile(image: image, format: .png)
        } else {
            print("Failed to generate waveform image.")
        }
    }

    func statusUpdated(provider: AudioWaveLibProvider, withError error: Error) {
        if let audioError = error as? AudioWaveLibProviderError {
            switch audioError {
            case .invalidURL:
                print("❌ Invalid audio file URL")
            case .fileInitializationFailed(let message):
                print("❌ File initialization failed: \(message)")
            case .invalidFrameCountOrFormat:
                print("❌ Invalid audio format or frame count")
            case .audioProcessingFailed(let message):
                print("❌ Audio processing failed: \(message)")
            }
        } else {
            print("❌ Error: \(error.localizedDescription)")
        }
    }

    private enum ImageFormat { case png, tiff }

    private func generateWaveformImage(sampleData: [Float], imageSize: CGSize) -> NSImage? {
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let bitmapSize = NSSize(width: imageSize.width / 2 * scale, height: imageSize.height * scale)

        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(bitmapSize.width), pixelsHigh: Int(bitmapSize.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }

        bitmapRep.size = bitmapSize
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: bitmapRep)?.cgContext
        context?.setFillColor(fillColor.cgColor)
        context?.fill(CGRect(origin: .zero, size: imageSize))

        let maxValue = sampleData.max() ?? 0
        let minValue = sampleData.min() ?? 0
        let heightNormalizationFactor = imageSize.height / CGFloat(maxValue - minValue)
        let path = NSBezierPath()
        path.lineWidth = lineWidth / scale

        // Simplified waveform drawing
        path.move(to: CGPoint(x: 0, y: imageSize.height / 2))
        for (index, value) in sampleData.enumerated() {
            let x = CGFloat(index) / CGFloat(sampleData.count) * imageSize.width
            let y = (CGFloat(value) - CGFloat(minValue)) * heightNormalizationFactor + imageSize.height / 2
            path.line(to: CGPoint(x: x, y: y))
        }
        path.line(to: CGPoint(x: imageSize.width, y: imageSize.height / 2))

        context?.setStrokeColor(strokeColor.cgColor)
        context?.setLineWidth(lineWidth / scale)
        context?.setLineCap(.round)
        context?.beginPath()

        // Handle macOS version compatibility for cgPath
        if #available(macOS 14.0, *) {
            context?.addPath(path.cgPath)
        } else {
            // Manually draw the waveform for older macOS versions
            path.move(to: CGPoint(x: 0, y: imageSize.height / 2))
            for (index, value) in sampleData.enumerated() {
                let x = CGFloat(index) / CGFloat(sampleData.count) * imageSize.width
                let y = (CGFloat(value) - CGFloat(minValue)) * heightNormalizationFactor + imageSize.height / 2
                context?.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context?.strokePath()

        NSGraphicsContext.restoreGraphicsState()
        return NSImage(size: imageSize, flipped: false) { dstRect in
            bitmapRep.draw(in: dstRect)
            return true
        }
    }

    private func displayImage(_ image: NSImage) {
        DispatchQueue.main.async { [self] in
            let scaledSize = image.size
            let imageView = NSImageView(image: image)
            imageView.frame = NSRect(origin: .zero, size: scaledSize)
            imageView.imageScaling = .scaleProportionallyUpOrDown

            let contentRect = NSRect(x: 0, y: 0, width: scaledSize.width, height: scaledSize.height)
            window = NSWindow(
                contentRect: contentRect,
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false
            )
            window?.backgroundColor = windowFillColor
            window?.contentView = imageView
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func saveImageToFile(image: NSImage, format: ImageFormat) {
        let fileExtension = format == .png ? "png" : "tiff"
        guard let data = image.tiffRepresentation,
              let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
                .appendingPathComponent("waveform.\(fileExtension)") else {
            print("Failed to prepare image data for saving.")
            return
        }

        do {
            try data.write(to: fileURL)
            print("Waveform image saved as \(fileExtension.uppercased()) to \(fileURL.path)")
        } catch {
            print("Error saving image: \(error)")
        }
    }
}

// Instantiate WaveformRenderer using the extracted component.
let waveformRenderer = WaveformRenderer()

// Configure waveform appearance (optional)
waveformRenderer.strokeColor = .systemBlue
waveformRenderer.lineWidth = 1.5
// URL of the audio file.
let url = URL(fileURLWithPath: "file.mp3")
// Create an instance of AudioWaveLibProvider with the audio file URL.
guard let provider = try? AudioWaveLibProvider(url: url) else {
    fatalError("Failed to initialize AudioWaveLibProvider.")
}

// Set the delegate of the provider.
provider.delegate = waveformRenderer
// Create sample data from the audio file.
provider.createSampleData()

// Start the application event loop.
let app = NSApplication.shared
app.run()
