import Foundation
import AppKit
import SDWebImageWebPCoder

/// A wrapper around SDWebImageWebPCoder to handle WebP encoding.
/// This ensures we can easily swap out the implementation or mock it if needed.
struct WebPEncoder {
    
    enum EncoderError: Error {
        case encodingFailed
        case invalidImage
    }
    
    /// Encodes a CGImage to WebP data.
    /// - Parameters:
    ///   - image: The CGImage to encode.
    ///   - quality: The quality factor (0.0 to 100.0) for lossy compression. Ignored if lossless is true.
    ///   - lossless: Whether to use lossless compression.
    /// - Returns: The encoded WebP data.
    static func encode(image: CGImage, quality: Double, lossless: Bool) throws -> Data {
        // Ensure the coder is registered.
        // Accessing shared instances might be main thread bound depending on implementation, 
        // but typically coder registration should be done once or is thread safe.
        // However, SDImageWebPCoder itself is a class.
        // To be strictly safe for background execution, we assume SDWebImage handles concurrency.
        let coder = SDImageWebPCoder.shared
        // We probably don't need to re-register every time if it's already done in App Delegate,
        // but for safety here we keep it. Note: SDImageCodersManager access may be thread-safe.
        SDImageCodersManager.shared.addCoder(coder)
        
        let compressionQuality = quality / 100.0
        
        var options: [SDImageCoderOption: Any] = [
            .encodeCompressionQuality: compressionQuality,
            .encodeWebPMethod: 4 // Default method (efficiency vs speed)
        ]
        
        if lossless {
            options[.encodeCompressionQuality] = 1.0
        }
        
        // Encode using the coder
        // Note: SDImageCoder protocol expects NSImage/UIImage usually for `encodedData(with:format:options:)`
        // BUT we need to avoid NSImage on background thread if possible, or at least avoid the MainActor constraint.
        // SDWebImageWebPCoder DOES have `encodedData(with:format:options:)` which takes UIImage/NSImage.
        // Does it verify thread?
        // Actually, creating a temporary NSImage wrapping a CGImage on a background thread IS generally safe 
        // IF we don't draw into it or use it for UI.
        // The issue before was passing `resizedImage` (NSImage) created on MainActor into the closure.
        
        // Let's wrap the CGImage in an NSImage locally here.
        // Since this is a local NSImage not attached to any view, it's safer.
        let tempImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        
        guard let data = coder.encodedData(with: tempImage, format: .webP, options: options) else {
            throw EncoderError.encodingFailed
        }
        
        return data
    }
}
