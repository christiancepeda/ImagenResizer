import Foundation
import AppKit

enum ResizeMode: String, CaseIterable, Identifiable {
    case fill = "Fill (Crop)"
    case fit = "Fit (Pad)"
    
    var id: String { self.rawValue }
}

struct ImagePipeline {
    
    private let targetSize = CGSize(width: 800, height: 800)
    
    enum PipelineError: Error {
        case loadFailed
        case resizeFailed
    }
    
    /// Main processing function
    func process(fileURL: URL, outputDir: URL, mode: ResizeMode, quality: Double, lossless: Bool) async throws -> URL {
        // 1. Load Image safely
        guard let originalImage = NSImage(contentsOf: fileURL) else {
            throw PipelineError.loadFailed
        }
        
        // 2. Resize
        guard let resizedImage = resize(image: originalImage, to: targetSize, mode: mode) else {
            throw PipelineError.resizeFailed
        }
        
        // 3. Convert to WebP
        // Run on a detached task to avoid blocking the main thread if the encoder is heavy (though async/await handles this well likely)
        let webpData = try await Task.detached(priority: .userInitiated) {
            return try WebPEncoder.encode(image: resizedImage, quality: quality, lossless: lossless)
        }.value
        
        // 4. Save
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        let finalURL = getUniqueFileURL(directory: outputDir, fileName: fileName, extension: "webp")
        
        try webpData.write(to: finalURL)
        return finalURL
    }
    
    // MARK: - Helper Methods
    
    /// Resizes the image according to the specified mode.
    func resize(image: NSImage, to size: CGSize, mode: ResizeMode) -> NSImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        
        // Use NSBitmapImageRep to force exact pixel dimensions (1x scale)
        // This avoids the issue where NSImage.lockFocus() uses the screen's scale (e.g. 2x on Retina), resulting in 1600x1600
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        
        rep.size = size // Set point size to match pixel size (72 DPI effectively)
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        
        // Clear background (transparent)
        NSColor.clear.set()
        NSRect(origin: .zero, size: size).fill()
        
        let originalSize = image.size
        var drawingRect: NSRect = .zero
        
        switch mode {
        case .fill:
            // Scale to fill logic (aspect fill)
            let widthRatio = size.width / originalSize.width
            let heightRatio = size.height / originalSize.height
            let scale = max(widthRatio, heightRatio)
            
            let scaledWidth = originalSize.width * scale
            let scaledHeight = originalSize.height * scale
            
            // Center the image
            let x = (size.width - scaledWidth) / 2.0
            let y = (size.height - scaledHeight) / 2.0
            
            drawingRect = NSRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
            
        case .fit:
            // Scale to fit logic (aspect fit)
            let widthRatio = size.width / originalSize.width
            let heightRatio = size.height / originalSize.height
            let scale = min(widthRatio, heightRatio)
            
            let scaledWidth = originalSize.width * scale
            let scaledHeight = originalSize.height * scale
            
            // Center the image
            let x = (size.width - scaledWidth) / 2.0
            let y = (size.height - scaledHeight) / 2.0
            
            drawingRect = NSRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
        }
        
        // Draw the original image into the calculated rect
        // .copy ensures we interact with the context correctly
        image.draw(in: drawingRect, from: NSRect(origin: .zero, size: originalSize), operation: .copy, fraction: 1.0)
        
        NSGraphicsContext.restoreGraphicsState()
        
        let newImage = NSImage(size: size)
        newImage.addRepresentation(rep)
        
        return newImage
    }
    
    /// Handles filename collisions by appending -1, -2, etc.
    private func getUniqueFileURL(directory: URL, fileName: String, extension fileExtension: String) -> URL {
        var counter = 0
        var currentURL = directory.appendingPathComponent("\(fileName).\(fileExtension)")
        
        while FileManager.default.fileExists(atPath: currentURL.path) {
            counter += 1
            currentURL = directory.appendingPathComponent("\(fileName)-\(counter).\(fileExtension)")
        }
        
        return currentURL
    }
}
