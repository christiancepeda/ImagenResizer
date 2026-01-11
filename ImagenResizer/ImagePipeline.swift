import Foundation
import AppKit

enum ResizeMode: String, CaseIterable, Identifiable {
    case fill = "Fill (Crop)"
    case fit = "Fit (Pad)"
    
    var id: String { self.rawValue }
}

struct ImagePipeline {
    
    enum OutputFormat: String, CaseIterable, Identifiable {
        case webp = "WebP"
        case png = "PNG"
        case jpg = "JPEG"
        
        var id: String { self.rawValue }
        
        var fileExtension: String {
            switch self {
            case .webp: return "webp"
            case .png: return "png"
            case .jpg: return "jpg"
            }
        }
    }
    
    enum PipelineError: Error {
        case loadFailed
        case resizeFailed
        case conversionFailed
    }
    
    /// Main processing function
    func process(fileURL: URL, outputDir: URL, targetSize: CGSize, mode: ResizeMode, format: OutputFormat, quality: Double, lossless: Bool) async throws -> URL {
        
        // Run all processing on a detached task to:
        // 1. Avoid blocking Main Actor (UI)
        // 2. Ensure a suspension point so UI updates can process (fixing "Publishing changes..." warning)
        return try await Task.detached(priority: .userInitiated) {
            
            // 1. Load Image
            // Note: NSImage(contentsOf:) is thread-safe for reading generally, but we should be careful.
            // Best to load data and init image.
            guard let originalImage = NSImage(contentsOf: fileURL) else {
                throw PipelineError.loadFailed
            }
            
            // 2. Resize
            // resize uses NSGraphicsContext, which is thread-local. It should be safe in a detached task as long as we don't access MainActor state.
            guard let resizedImage = self.resize(image: originalImage, to: targetSize, mode: mode) else {
                throw PipelineError.resizeFailed
            }
            
            // 3. Convert & Save
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            let finalURL = self.getUniqueFileURL(directory: outputDir, fileName: fileName, extension: format.fileExtension)
            
            switch format {
            case .webp:
                // Extract CGImage
                guard let cgImage = resizedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    throw PipelineError.resizeFailed
                }
                
                let webpData = try WebPEncoder.encode(image: cgImage, quality: quality, lossless: lossless)
                try webpData.write(to: finalURL)
                
            case .png:
                try self.saveImage(resizedImage, to: finalURL, type: .png)
                
            case .jpg:
                // Map 0-100 quality to 0.0-1.0
                let compression = CGFloat(quality / 100.0)
                try self.saveImage(resizedImage, to: finalURL, type: .jpeg, properties: [.compressionFactor: compression])
            }
            
            return finalURL
        }.value
    }
    
    private func saveImage(_ image: NSImage, to url: URL, type: NSBitmapImageRep.FileType, properties: [NSBitmapImageRep.PropertyKey: Any] = [:]) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            throw PipelineError.conversionFailed
        }
        
        guard let data = bitmapRep.representation(using: type, properties: properties) else {
            throw PipelineError.conversionFailed
        }
        
        try data.write(to: url)
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
