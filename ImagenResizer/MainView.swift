import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerView
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // MARK: - Content
            HSplitView {
                // Left: Input List
                inputListView
                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                
                // Right: Controls & Log
                VStack(spacing: 0) {
                    controlsView
                        .padding()
                    
                    Divider()
                    
                    logView
                }
                .frame(minWidth: 300, maxWidth: 400, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            
            Divider()
            
            // MARK: - Footer (Status & Global Actions)
            footerView
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    // MARK: - Subviews
    
    var headerView: some View {
        HStack {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading) {
                Text("Image Resizer & WebP Converter")
                    .font(.title2)
                    .bold()
                Text("Resize to 800x800 and convert to WebP")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Clear List") {
                viewModel.clearList()
            }
            .disabled(viewModel.isProcessing || viewModel.inputImages.isEmpty)
        }
    }
    
    var inputListView: some View {
        List {
            if viewModel.inputImages.isEmpty {
                Text("No images selected. Use the buttons to add images.")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(viewModel.inputImages) { item in
                    HStack {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: item.originalURL.path))
                            .resizable()
                            .frame(width: 32, height: 32)
                        
                        VStack(alignment: .leading) {
                            Text(item.originalURL.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(item.originalURL.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                        
                        Spacer()
                        
                        statusIcon(for: item.status)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            viewModel.handleDrop(providers: providers)
        }
    }
    
    @ViewBuilder
    func statusIcon(for status: ImageStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .foregroundColor(.secondary)
        case .processing:
            ProgressView()
                .scaleEffect(0.5)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failure:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
        }
    }
    
    var controlsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // 1. Input Selection
            GroupBox(label: Label("Input", systemImage: "tray.and.arrow.down")) {
                HStack {
                    Button("Choose Images...") {
                        viewModel.selectInputImages()
                    }
                    Button("Choose Folder...") {
                        viewModel.selectInputFolder()
                    }
                }
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // 2. Output & Settings
            GroupBox(label: Label("Settings", systemImage: "gearshape")) {
                VStack(alignment: .leading, spacing: 12) {
                    
                    // Output Folder
                    HStack {
                        Button("Output Folder...") {
                            viewModel.selectOutputFolder()
                        }
                        if let out = viewModel.outputFolder {
                            Text(out.lastPathComponent)
                                .truncationMode(.middle)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not selected")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Divider()
                    
                    // Dimensions
                    GroupBox(label: Label("Dimensions", systemImage: "aspectratio")) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Width")
                                    .font(.caption)
                                TextField("Width", value: $viewModel.targetWidth, formatter: NumberFormatter())
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Height")
                                    .font(.caption)
                                TextField("Height", value: $viewModel.targetHeight, formatter: NumberFormatter())
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    Divider()
                    
                    // Resize Mode
                    Picker("Resize Mode:", selection: $viewModel.resizeMode) {
                        ForEach(ResizeMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // Output Format
                    Picker("Format:", selection: $viewModel.outputFormat) {
                        ForEach(ImagePipeline.OutputFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // Quality / Lossless
                    // Show for WebP and JPEG. Hide for PNG (lossless by default).
                    if viewModel.outputFormat == .webp || viewModel.outputFormat == .jpg {
                        VStack(alignment: .leading) {
                            if viewModel.outputFormat == .webp {
                                Toggle("Lossless Encoding", isOn: $viewModel.isLossless)
                            }
                            
                            HStack {
                                Text("Quality: \(Int(viewModel.webpQuality))")
                                Slider(value: $viewModel.webpQuality, in: 0...100, step: 1)
                                    .disabled(viewModel.outputFormat == .webp && viewModel.isLossless)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
            
            // 3. Action
            Button(action: {
                if viewModel.isProcessing {
                    viewModel.cancelProcessing()
                } else {
                    viewModel.startConversion()
                }
            }) {
                Text(viewModel.isProcessing ? "Cancel" : "Convert Images")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isProcessing && (viewModel.inputImages.isEmpty || viewModel.outputFolder == nil))
            
        }
    }
    
    var logView: some View {
        List(viewModel.logs) { log in
            HStack(alignment: .top) {
                switch log.type {
                case .info:
                    Text(log.text)
                        .foregroundColor(.primary)
                case .success:
                    Text(log.text)
                        .foregroundColor(.green)
                case .error:
                    Text(log.text)
                        .foregroundColor(.red)
                }
            }
            .font(.caption) // Monospace might be nice for logs
            .fontDesign(.monospaced)
        }
    }
    
    var footerView: some View {
        HStack {
            if viewModel.isProcessing {
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 200)
                Text("\(viewModel.completedCount) / \(viewModel.totalImages)")
                    .font(.caption)
                    .monospacedDigit()
            } else {
                Text(viewModel.inputImages.isEmpty ? "Ready" : "Waiting to start")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Open Output Folder") {
                viewModel.openOutputFolder()
            }
            .disabled(viewModel.outputFolder == nil)
        }
    }
}
