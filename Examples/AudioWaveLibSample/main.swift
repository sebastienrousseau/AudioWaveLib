import AudioWaveLib
import Cocoa
import CoreGraphics
import Foundation

// A class that acts as a delegate for the AudioWaveLibProviderDelegate protocol.
class DemoDelegate: NSObject, AudioWaveLibProviderDelegate {
    // A window to display the waveform image.
    var window: NSWindow?
    // The color to fill the waveform.
    var fillColor: NSColor = .white
    // The color to stroke the waveform lines.
    var strokeColor: NSColor = .black
    // The width of the waveform lines.
    var lineWidth: CGFloat = 1.0

    // Called when sample data is processed.
    func sampleProcessed(provider: AudioWaveLibProvider) {
        print("Sample processed")
        // Retrieve sample data from the provider.
        guard let sampleData = provider.getSampleData() else {
            print("No sample data available.")
            return
        }
        print("Sample data available")
        // Set the size of the waveform image.
        let imageSize = CGSize(width: 300, height: 100)
        // Generate waveform image.
        if let image = generateWaveformImage(sampleData: sampleData, imageSize: imageSize) {
            print("Image generated")
            // Display the waveform image.
            displayImage(image)
            // Saving image in multiple formats
            saveImageToFile(image: image, format: .png)
        } else {
            print("Failed to generate waveform image.")
        }
    }

    // Called when the status of the provider is updated with an error.
    func statusUpdated(provider _: AudioWaveLibProvider, withError error: Error) {
        print("An error occurred: \(error.localizedDescription)")
    }

    // Generates a waveform image from the given sample data and size.
    private func generateWaveformImage(sampleData: [Float], imageSize: CGSize) -> NSImage? {
        // Determine the screen's backing scale factor.
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        // Calculate the bitmap size based on the image size and scale.
        let bitmapSize = NSSize(width: imageSize.width / 2 * scale, height: imageSize.height * scale)

        // Create an NSBitmapImageRep object to represent the bitmap.
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(bitmapSize.width),
            pixelsHigh: Int(bitmapSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        // Set the size of the bitmap.
        bitmapRep.size = bitmapSize
        // Save the current graphics state.
        NSGraphicsContext.saveGraphicsState()
        // Create a graphics context for the bitmap.
        let context = NSGraphicsContext(bitmapImageRep: bitmapRep)?.cgContext
        // Fill the bitmap with the fill color.
        context?.setFillColor(fillColor.cgColor)
        context?.fill(CGRect(origin: .zero, size: imageSize))

        // Calculate waveform parameters.
        let maxValue = sampleData.max() ?? 0
        let minValue = sampleData.min() ?? 0
        let heightNormalizationFactor = imageSize.height / CGFloat(maxValue - minValue)
        let path = NSBezierPath()
        path.lineWidth = lineWidth / scale

        // Move to the starting point of the waveform path.
        path.move(to: CGPoint(x: 0, y: imageSize.height / 2))

        // Iterate over sample data to create waveform path.
        for (index, value) in sampleData.enumerated() {
            let x = CGFloat(index) / CGFloat(sampleData.count) * imageSize.width
            let y = (CGFloat(value) - CGFloat(minValue)) * heightNormalizationFactor + imageSize.height / 2
            path.line(to: CGPoint(x: x, y: y))
        }

        // Complete the waveform path.
        path.line(to: CGPoint(x: imageSize.width, y: imageSize.height / 2))

        // Check for macOS version compatibility for adding path to the context.
        if #available(macOS 14, *) {
            context?.addPath(path.cgPath)
        } else {
            // Manually draw the waveform using Core Graphics for older macOS versions.
            let context = NSGraphicsContext.current?.cgContext

            // Set up drawing attributes.
            context?.setStrokeColor(strokeColor.cgColor)
            context?.setLineWidth(lineWidth / scale)
            context?.setLineCap(.round)

            // Begin path.
            context?.beginPath()
            context?.move(to: CGPoint(x: 0, y: imageSize.height / 2))

            // Draw waveform path.
            let parameters = WaveformParameters(
                context: context,
                path: path,
                imageSize: imageSize,
                sampleData: sampleData,
                minValue: minValue,
                heightNormalizationFactor: heightNormalizationFactor
            )
            drawWaveformPath(with: parameters)

            // Complete the path back to the starting point.
            context?.addLine(to: CGPoint(x: imageSize.width, y: imageSize.height / 2))

            // Draw the path.
            context?.strokePath()
        }

        // Stroke the waveform path.
        context?.setStrokeColor(strokeColor.cgColor)
        context?.strokePath()

        // Restore the graphics state.
        NSGraphicsContext.restoreGraphicsState()

        // Create an NSImage from the bitmap.
        return NSImage(size: imageSize, flipped: false) { dstRect -> Bool in
            bitmapRep.draw(in: dstRect)
            return true
        }
    }

    // Struct to hold parameters for drawing waveform.
    struct WaveformParameters {
        let context: CGContext?
        let path: NSBezierPath
        let imageSize: CGSize
        let sampleData: [Float]
        let minValue: Float
        let heightNormalizationFactor: CGFloat
    }

    // Draws the waveform path with given parameters.
    private func drawWaveformPath(with parameters: WaveformParameters) {
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let context = parameters.context
        let path = parameters.path
        let imageSize = parameters.imageSize
        let sampleData = parameters.sampleData
        let minValue = parameters.minValue
        let heightNormalizationFactor = parameters.heightNormalizationFactor

        // Move to the starting point of the waveform path.
        path.move(to: CGPoint(x: 0, y: imageSize.height / 2))

        // Iterate over sample data to draw waveform path.
        for (index, value) in sampleData.enumerated() {
            let horizontalPosition = CGFloat(index) / CGFloat(sampleData.count) * imageSize.width
            let verticalPosition = (CGFloat(value) - CGFloat(minValue)) * heightNormalizationFactor + imageSize.height / 2
            path.line(to: CGPoint(x: horizontalPosition, y: verticalPosition))
        }

        // Complete the waveform path.
        path.line(to: CGPoint(x: imageSize.width, y: imageSize.height / 2))

        // Check for macOS version compatibility for adding path to the context.
        if #available(macOS 14, *) {
            context?.addPath(path.cgPath)
        } else {
            // Manually draw the waveform using Core Graphics for older macOS versions.
            context?.setStrokeColor(strokeColor.cgColor)
            context?.setLineWidth(lineWidth / scale)
            context?.setLineCap(.round)

            // Begin path.
            context?.beginPath()
            context?.move(to: CGPoint(x: 0, y: imageSize.height / 2))

            // Draw waveform path.
            for (index, value) in sampleData.enumerated() {
                let horizontalPosition = CGFloat(index) / CGFloat(sampleData.count) * imageSize.width
                let verticalPosition = (CGFloat(value) - CGFloat(minValue)) * heightNormalizationFactor + imageSize.height / 2
                context?.addLine(to: CGPoint(x: horizontalPosition, y: verticalPosition))
            }

            // Complete the path back to the starting point.
            context?.addLine(to: CGPoint(x: imageSize.width, y: imageSize.height / 2))
            // Stroke the path.
            context?.strokePath()
        }

        // Stroke the waveform path.
        context?.setStrokeColor(strokeColor.cgColor)
        context?.strokePath()
    }

    // Display the given image in a window.
    private func displayImage(_ image: NSImage) {
        let scaledSize = NSSize(width: image.size.width, height: image.size.height)
        let imageView = NSImageView(image: image)
        imageView.frame = NSRect(origin: .zero, size: scaledSize)
        imageView.imageScaling = .scaleProportionallyUpOrDown

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: scaledSize.width, height: scaledSize.height), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window?.contentView = imageView
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Saves the given image to a file with the specified format.
    // Expanded to support multiple formats
    private func saveImageToFile(image: NSImage, format: ImageFormat) {
        let fileExtension: String
        switch format {
        case .png:
            fileExtension = "png"
        default:
            return
        }

        var data: Data?
        data = image.tiffRepresentation

        guard let imageData = data else {
            print("Failed to prepare image data for saving.")
            return
        }

        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("waveform.\(fileExtension)")
        do {
            try imageData.write(to: fileURL!)
            print("Waveform image saved as \(fileExtension.uppercased()) to \(fileURL!.path)")
        } catch {
            print("Error saving image: \(error)")
        }
    }
}

// Enum to represent supported image formats.
enum ImageFormat {
    case png, tiff
}

// Instantiate DemoDelegate.
let delegate = DemoDelegate()
// URL of the audio file.
let url = URL(fileURLWithPath: "file.mp3")
// Create an instance of AudioWaveLibProvider with the audio file URL.
guard let provider = try? AudioWaveLibProvider(url: url) else {
    fatalError("Failed to initialize AudioWaveLibProvider.")
}

// Set the delegate of the provider.
provider.delegate = delegate
// Create sample data from the audio file.
provider.createSampleData()

// Start the application event loop.
let app = NSApplication.shared
app.run()
