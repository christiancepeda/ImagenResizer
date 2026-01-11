import XCTest
@testable import ImagenResizer

final class ImagePipelineTests: XCTestCase {
    
    // Mock image creation
    func createTestImage(width: CGFloat, height: CGFloat) -> NSImage {
        let size = CGSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }

    func testResizeFillLargeImage() {
        let pipeline = ImagePipeline()
        let original = createTestImage(width: 1600, height: 1600)
        let mode = ResizeMode.fill
        
        let processed = pipeline.resize(image: original, to: CGSize(width: 800, height: 800), mode: mode)
        XCTAssertNotNil(processed)
        XCTAssertEqual(processed?.size, CGSize(width: 800, height: 800))
    }
    
    func testResizeFitSmallImage() {
        let pipeline = ImagePipeline()
        let original = createTestImage(width: 100, height: 100)
        let mode = ResizeMode.fit
        
        // Even if smaller, it should output 800x800 canvas with image centered
        let processed = pipeline.resize(image: original, to: CGSize(width: 800, height: 800), mode: mode)
        XCTAssertNotNil(processed)
        XCTAssertEqual(processed?.size, CGSize(width: 800, height: 800))
    }
    
    func testResizeFillAspect() {
        // Landscape image 200x100 -> Fill 800x800
        // Should scale to 1600x800 and crop center
        let pipeline = ImagePipeline()
        let original = createTestImage(width: 200, height: 100)
        
        let processed = pipeline.resize(image: original, to: CGSize(width: 800, height: 800), mode: .fill)
        XCTAssertNotNil(processed)
        XCTAssertEqual(processed?.size, CGSize(width: 800, height: 800))
    }
    
    func testResizeCustomDimensions() {
        let pipeline = ImagePipeline()
        let original = createTestImage(width: 500, height: 500)
        let targetSize = CGSize(width: 100, height: 100)
        
        // Use fit mode for this test, arbitrary choice, just checking size.
        // Need to provide a format now.
        let processed = pipeline.resize(image: original, to: targetSize, mode: .fill)
        XCTAssertNotNil(processed)
        XCTAssertEqual(processed?.size, targetSize)
    }
    
    func testProcessToPNG() async throws {
         let pipeline = ImagePipeline()
         let width: CGFloat = 100
         let height: CGFloat = 100
         let original = createTestImage(width: width, height: height)
         
         // Create a temporary file for the input
         let tempDir = FileManager.default.temporaryDirectory
         let inputURL = tempDir.appendingPathComponent("test_input.png")
         let tiffData = original.tiffRepresentation!
         try tiffData.write(to: inputURL)
         
         let outputDir = tempDir
         
         let resultURL = try await pipeline.process(
             fileURL: inputURL,
             outputDir: outputDir,
             targetSize: CGSize(width: 50, height: 50),
             mode: .fill,
             format: .png,
             quality: 100,
             lossless: false
         )
         
         XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))
         XCTAssertEqual(resultURL.pathExtension, "png")
         
         // Cleanup
         try? FileManager.default.removeItem(at: inputURL)
         try? FileManager.default.removeItem(at: resultURL)
     }
     
     func testProcessToJPG() async throws {
         let pipeline = ImagePipeline()
         let width: CGFloat = 100
         let height: CGFloat = 100
         let original = createTestImage(width: width, height: height)
         
         // Create a temporary file for the input
         let tempDir = FileManager.default.temporaryDirectory
         let inputURL = tempDir.appendingPathComponent("test_input_jpg.png")
         let tiffData = original.tiffRepresentation!
         try tiffData.write(to: inputURL)
         
         let outputDir = tempDir
         
         let resultURL = try await pipeline.process(
             fileURL: inputURL,
             outputDir: outputDir,
             targetSize: CGSize(width: 50, height: 50),
             mode: .fill,
             format: .jpg,
             quality: 50,
             lossless: false
         )
         
         XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))
         XCTAssertEqual(resultURL.pathExtension, "jpg")
         
         // Cleanup
         try? FileManager.default.removeItem(at: inputURL)
         try? FileManager.default.removeItem(at: resultURL)
     }
}
