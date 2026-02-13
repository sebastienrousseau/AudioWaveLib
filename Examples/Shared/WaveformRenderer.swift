import Cocoa
import CoreGraphics
import Foundation
import AudioWaveLib

/// Enum to represent supported image formats.
public enum ImageFormat {
    case png, tiff
}

/// A reusable waveform renderer class for macOS applications.
/// Extracted from the original DemoDelegate for better separation of concerns.
public class WaveformRenderer: BaseAudioDelegate {
    // MARK: - Configuration Properties

    /// The color to fill the window background.
    public var windowFillColor: NSColor = .white
    /// The color to fill the waveform area.
    public var fillColor: NSColor = .clear
    /// The color to stroke the waveform lines.
    public var strokeColor: NSColor = .black
    /// The width of the waveform lines.
    public var lineWidth: CGFloat = 1.0

    // MARK: - Private Properties

    /// A window to display the waveform image.
    private var window: NSWindow?

    // MARK: - Initialization

    public override init() {
        super.init()
    }

    // MARK: - AudioWaveLibProviderDelegate Implementation

    /// Called when sample data is processed.
    public override func sampleProcessed(provider: AudioWaveLibProvider) {
        print("Sample processed")

        // Retrieve sample data from the provider.
        guard let sampleData = provider.sampleData else {
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
            // Save image in PNG format
            saveImageToFile(image: image, format: .png)
        } else {
            print("Failed to generate waveform image.")
        }
    }

    // MARK: - Public Methods

    /// Generate a waveform image from sample data.
    /// - Parameters:
    ///   - sampleData: Audio sample data
    ///   - imageSize: Desired image size
    /// - Returns: Generated NSImage or nil if generation failed
    public func generateWaveformImage(
        sampleData: [Float],
        imageSize: CGSize
    ) -> NSImage? {
        // Determine the screen's backing scale factor.
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0

        // Calculate the bitmap size based on the image size and scale.
        let bitmapSize = NSSize(
            width: imageSize.width / 2 * scale,
            height: imageSize.height * scale
        )

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

        // Draw waveform path.
        drawWaveformPath(with: WaveformDrawingParameters(
            context: context,
            path: path,
            imageSize: imageSize,
            sampleData: sampleData,
            minValue: minValue,
            heightNormalizationFactor: heightNormalizationFactor,
            scale: scale
        ))

        // Restore the graphics state.
        NSGraphicsContext.restoreGraphicsState()

        // Create an NSImage from the bitmap.
        return NSImage(size: imageSize, flipped: false) { dstRect -> Bool in
            bitmapRep.draw(in: dstRect)
            return true
        }
    }

    /// Display the given image in a window.
    /// - Parameter image: The image to display
    public func displayImage(_ image: NSImage) {
        let scaledSize = NSSize(width: image.size.width, height: image.size.height)
        let imageView = NSImageView(image: image)
        imageView.frame = NSRect(origin: .zero, size: scaledSize)
        imageView.imageScaling = .scaleProportionallyUpOrDown

        window = NSWindow(contentRect: NSRect(
            x: 0,
            y: 0,
            width: scaledSize.width,
            height: scaledSize.height
        ), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)

        window?.backgroundColor = windowFillColor
        window?.contentView = imageView
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Save the given image to a file with the specified format.
    /// - Parameters:
    ///   - image: The image to save
    ///   - format: The image format
    public func saveImageToFile(image: NSImage, format: ImageFormat) {
        let fileExtension: String
        switch format {
        case .png:
            fileExtension = "png"
        case .tiff:
            fileExtension = "tiff"
        }

        var data: Data?
        data = image.tiffRepresentation

        guard let imageData = data else {
            print("Failed to prepare image data for saving.")
            return
        }

        let fileURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent(
            "waveform.\(fileExtension)"
        )

        do {
            try imageData.write(to: fileURL!)
            print("Waveform image saved as \(fileExtension.uppercased()) to \(fileURL!.path)")
        } catch {
            print("Error saving image: \(error)")
        }
    }
}

// MARK: - Private Implementation

extension WaveformRenderer {
    /// Parameters for waveform drawing operations.
    private struct WaveformDrawingParameters {
        let context: CGContext?
        let path: NSBezierPath
        let imageSize: CGSize
        let sampleData: [Float]
        let minValue: Float
        let heightNormalizationFactor: CGFloat
        let scale: CGFloat
    }

    /// Draws the waveform path with given parameters.
    private func drawWaveformPath(with parameters: WaveformDrawingParameters) {
        let context = parameters.context
        let path = parameters.path
        let imageSize = parameters.imageSize
        let sampleData = parameters.sampleData
        let minValue = parameters.minValue
        let heightNormalizationFactor = parameters.heightNormalizationFactor
        let scale = parameters.scale

        // Calculate waveform points once to eliminate duplication
        let waveformPoints = calculateWaveformPoints(
            sampleData: sampleData,
            minValue: minValue,
            heightNormalizationFactor: heightNormalizationFactor,
            imageSize: imageSize
        )

        // Move to the starting point of the waveform path.
        path.move(to: CGPoint(x: 0, y: imageSize.height / 2))

        // Draw waveform path using pre-calculated points.
        for point in waveformPoints {
            path.line(to: point)
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

            // Draw waveform path using the same pre-calculated points.
            for point in waveformPoints {
                context?.addLine(to: point)
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

    /// Helper method to calculate waveform points.
    private func calculateWaveformPoints(
        sampleData: [Float],
        minValue: Float,
        heightNormalizationFactor: CGFloat,
        imageSize: CGSize
    ) -> [CGPoint] {
        return sampleData.enumerated().map { index, value in
            let horizontalPosition = CGFloat(index) / CGFloat(sampleData.count) * imageSize.width
            let verticalPosition = (
                CGFloat(value) - CGFloat(minValue)
            ) * heightNormalizationFactor + imageSize.height / 2
            return CGPoint(x: horizontalPosition, y: verticalPosition)
        }
    }
}