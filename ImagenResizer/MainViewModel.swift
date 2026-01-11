import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers


struct ProcessedImage: Identifiable {
    let id = UUID()
    let originalURL: URL
    var status: ImageStatus = .pending
    var message: String?
}

enum ImageStatus {
    case pending
    case processing
    case success(URL)
    case failure(Error)
}

struct LogMessage: Identifiable {
    let id = UUID()
    let text: String
    let type: LogType
    
    enum LogType {
        case info
        case success
        case error
    }
}

@MainActor
class MainViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var inputImages: [ProcessedImage] = []
    @Published var outputFolder: URL?
    @Published var isProcessing: Bool = false
    @Published var progress: Double = 0.0
    @Published var completedCount: Int = 0
    
    // Settings
    @Published var resizeMode: ResizeMode = .fill
    @Published var webpQuality: Double = 80.0
    @Published var isLossless: Bool = false
    
    // Logs
    @Published var logs: [LogMessage] = []
    
    // Cancellation
    private var processTask: Task<Void, Never>?
    private let pipeline = ImagePipeline()
    
    // Compute property for total
    var totalImages: Int { inputImages.count }
    
    // MARK: - User Actions
    
    func selectInputImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        
        if panel.runModal() == .OK {
            let newImages = panel.urls.map { ProcessedImage(originalURL: $0) }
            self.inputImages.append(contentsOf: newImages)
            log("Added \(newImages.count) images.", type: .info)
        }
    }
    
    func selectInputFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        
        if panel.runModal() == .OK, let folderURL = panel.url {
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
                // Filter images by checking conformance to UTType.image if possible, otherwise by extension
                let imageExtensions = ["png", "jpg", "jpeg", "heic", "tiff", "webp"]
                let validImages = fileURLs.filter { url in
                    imageExtensions.contains(url.pathExtension.lowercased())
                }
                
                let newImages = validImages.map { ProcessedImage(originalURL: $0) }
                self.inputImages.append(contentsOf: newImages)
                log("Added \(newImages.count) images from folder: \(folderURL.lastPathComponent).", type: .info)
                
            } catch {
                log("Failed to load folder: \(error.localizedDescription)", type: .error)
            }
        }
    }
    
    func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.message = "Select Output Folder"
        
        if panel.runModal() == .OK {
            self.outputFolder = panel.url
            log("Output folder set to: \(panel.url?.path ?? "Unknown")", type: .info)
        }
    }
    
    func openOutputFolder() {
        guard let url = outputFolder else { return }
        NSWorkspace.shared.open(url)
    }
    
    func clearList() {
        inputImages.removeAll()
        progress = 0
        completedCount = 0
        logs.removeAll()
        log("List cleared.", type: .info)
    }
    
    func cancelProcessing() {
        processTask?.cancel()
        isProcessing = false
        log("Processing cancelled by user.", type: .info)
    }
    
    // MARK: - Processing Logic
    
    func startConversion() {
        guard let outputDir = outputFolder else {
            log("Error: No output folder selected.", type: .error)
            return
        }
        
        guard !inputImages.isEmpty else {
            log("Error: No images to process.", type: .error)
            return
        }
        
        isProcessing = true
        progress = 0.0
        completedCount = 0
        
        // Reset statuses for pending items? Or just process all pending?
        // Let's reset all for simplicity of this "Batch" run style
        for i in 0..<inputImages.count {
            inputImages[i].status = .pending
            inputImages[i].message = nil
        }
        
        processTask = Task {
            log("Starting conversion of \(inputImages.count) images...", type: .info)
            
            // 1. Access Output Folder Security Scope
            let outputAccess = outputDir.startAccessingSecurityScopedResource()
            if !outputAccess {
                log("WARNING: Failed to acquire security access for output folder. Check App Sandbox > User Selected File > Read/Write.", type: .error)
            } else {
                log("Security access acquired for output folder.", type: .info)
            }
            
            defer {
                if outputAccess {
                    outputDir.stopAccessingSecurityScopedResource()
                }
            }
            
            for index in 0..<inputImages.count {
                if Task.isCancelled { break }
                
                let imageItem = inputImages[index]
                inputImages[index].status = .processing
                
                // 2. Access Input File Security Scope (if needed)
                let inputAccess = imageItem.originalURL.startAccessingSecurityScopedResource()
                
                do {
                    let finalURL = try await pipeline.process(
                        fileURL: imageItem.originalURL,
                        outputDir: outputDir,
                        mode: resizeMode,
                        quality: webpQuality,
                        lossless: isLossless
                    )
                    
                    inputImages[index].status = .success(finalURL)
                    log("✓ Converted: \(imageItem.originalURL.lastPathComponent)", type: .success)
                    
                } catch {
                    inputImages[index].status = .failure(error)
                    inputImages[index].message = error.localizedDescription
                    log("✗ Failed: \(imageItem.originalURL.lastPathComponent) - \(error.localizedDescription)", type: .error)
                }
                
                // Stop accessing input
                if inputAccess {
                    imageItem.originalURL.stopAccessingSecurityScopedResource()
                }
                
                completedCount += 1
                progress = Double(completedCount) / Double(inputImages.count)
            }
            
            isProcessing = false
            log("Batch processing completed.", type: .info)
            processTask = nil
        }
    }
    
    // MARK: - Logging Helper
    
    private func log(_ text: String, type: LogMessage.LogType) {
        let message = LogMessage(text: text, type: type)
        // Append to start of list for "newest first" (optional) OR end. Let's do end and scroll.
        logs.append(message)
    }
}
