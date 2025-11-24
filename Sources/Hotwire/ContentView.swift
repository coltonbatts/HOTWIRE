import SwiftUI

struct ContentView: View {
    @StateObject private var cameraController = CameraController()

    var body: some View {
        HSplitView {
            // Left Sidebar - Controls
            ControlsSidebar(controller: cameraController)
                .frame(minWidth: 220, idealWidth: 250, maxWidth: 300)
            
            // Main Content Area
            VStack(spacing: 0) {
                // Main Preview Area
                MainPreviewArea(controller: cameraController)
                
                // Bottom Filmstrip
                FilmstripView(controller: cameraController)
                    .frame(height: 120)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            cameraController.initialize()
        }
    }
}

// MARK: - Controls Sidebar

struct ControlsSidebar: View {
    @ObservedObject var controller: CameraController
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with connection status
            VStack(spacing: 8) {
                Text("HOTWIRE")
                    .font(.system(size: 18, weight: .black, design: .default))
                    .tracking(2)
                
                Text("Canon 6D Mark II")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(controller.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(controller.connectionStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Refresh connection button
                    Button(action: {
                        controller.scanForCamera()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .help("Refresh camera connection")
                    
                    // Daemon Killer indicator
                    if controller.daemonKillerActive {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                            Text("DK")
                                .font(.caption2.bold())
                        }
                        .foregroundColor(.orange)
                        .help("Daemon Killer Active - USB is protected")
                    }
                }
                
                if !controller.isConnected {
                    Button("Scan for Camera") {
                        controller.scanForCamera()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                // Health Status Indicator
                HealthStatusView(controller: controller)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Capture Controls
                    GroupBox {
                        VStack(spacing: 12) {
                            // Capture Button
                            Button(action: {
                                controller.captureImage()
                            }) {
                                HStack {
                                    if controller.isCapturing {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "camera.fill")
                                    }
                                    Text(controller.isCapturing ? "Capturing..." : "Capture")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(!controller.isConnected || controller.isCapturing)
                            
                            // Live View Toggle
                            Button(action: {
                                controller.toggleLiveView()
                            }) {
                                HStack {
                                    Image(systemName: controller.isLiveViewActive ? "video.slash.fill" : "video.fill")
                                    Text(controller.isLiveViewActive ? "Stop Live View" : "Start Live View")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!controller.isConnected)
                        }
                    } label: {
                        Label("Capture", systemImage: "camera")
                    }
                    
                    // Camera Settings
                    GroupBox {
                        VStack(spacing: 12) {
                            // ISO
                            HStack {
                                Text("ISO")
                                    .frame(width: 60, alignment: .leading)
                                Picker("", selection: $controller.selectedISO) {
                                    ForEach(controller.availableISOs, id: \.self) { iso in
                                        Text(iso).tag(iso)
                                    }
                                }
                                .labelsHidden()
                                .onChange(of: controller.selectedISO) { _, _ in
                                    controller.updateISO()
                                }
                            }
                            
                            // Aperture
                            HStack {
                                Text("Aperture")
                                    .frame(width: 60, alignment: .leading)
                                Picker("", selection: $controller.selectedAperture) {
                                    ForEach(controller.availableApertures, id: \.self) { aperture in
                                        Text(aperture).tag(aperture)
                                    }
                                }
                                .labelsHidden()
                                .onChange(of: controller.selectedAperture) { _, _ in
                                    controller.updateAperture()
                                }
                            }
                            
                            // Shutter Speed
                            HStack {
                                Text("Shutter")
                                    .frame(width: 60, alignment: .leading)
                                Picker("", selection: $controller.selectedShutter) {
                                    ForEach(controller.availableShutterSpeeds, id: \.self) { shutter in
                                        Text(shutter).tag(shutter)
                                    }
                                }
                                .labelsHidden()
                                .onChange(of: controller.selectedShutter) { _, _ in
                                    controller.updateShutterSpeed()
                                }
                            }
                        }
                    } label: {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                    .disabled(!controller.isConnected)
                    
                    // Capture Folder
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(controller.captureFolder.lastPathComponent)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            HStack {
                                Button("Change...") {
                                    controller.selectCaptureFolder()
                                }
                                .controlSize(.small)
                                
                                Button(action: {
                                    NSWorkspace.shared.open(controller.captureFolder)
                                }) {
                                    Image(systemName: "folder")
                                }
                                .controlSize(.small)
                                .help("Open in Finder")
                            }
                        }
                    } label: {
                        Label("Save Location", systemImage: "folder")
                    }
                    
                    Spacer()
                }
                .padding()
            }
            
            Divider()
            
            // Status Bar
            HStack {
                Text(controller.statusMessage)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Spacer()
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

// MARK: - Main Preview Area

struct MainPreviewArea: View {
    @ObservedObject var controller: CameraController
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(NSColor.windowBackgroundColor)
                
                if controller.isLiveViewActive {
                    // Live View
                    if let liveImage = controller.liveViewImage {
                        Image(nsImage: liveImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Starting Live View...")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Live View indicator
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("LIVE")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                            .padding()
                        }
                        Spacer()
                    }
                } else if let selectedImage = controller.selectedImage {
                    // Show selected image from gallery
                    Image(nsImage: selectedImage.fullImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Image info overlay
                    VStack {
                        Spacer()
                        HStack {
                            Text(selectedImage.filename)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Button(action: {
                                    controller.revealInFinder(selectedImage)
                                }) {
                                    Image(systemName: "folder")
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                                .help("Reveal in Finder")
                                
                                Button(action: {
                                    controller.deleteImage(selectedImage)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                                .help("Delete")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                        }
                        .padding()
                    }
                } else if let lastImage = controller.lastCapturedImage {
                    // Show last captured image
                    Image(nsImage: lastImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Images Yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Capture an image or start Live View")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Filmstrip View

struct FilmstripView: View {
    @ObservedObject var controller: CameraController
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            if controller.capturedImages.isEmpty {
                HStack {
                    Spacer()
                    VStack {
                        Text("Captured images will appear here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 4) {
                        ForEach(controller.capturedImages) { image in
                            FilmstripThumbnail(
                                image: image,
                                isSelected: controller.selectedImage?.id == image.id,
                                onSelect: {
                                    controller.selectedImage = image
                                    controller.lastCapturedImage = image.fullImage
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }
}

struct FilmstripThumbnail: View {
    let image: CapturedImage
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Image(nsImage: image.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 60)
                    .clipped()
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    )
                
                Text(formatTime(image.captureDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Health Status View

struct HealthStatusView: View {
    @ObservedObject var controller: CameraController
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 6) {
            // Compact header - always visible (just toggles expand, no refresh)
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.2)) { 
                    isExpanded.toggle() 
                } 
            }) {
                HStack(spacing: 6) {
                    // Overall status indicator
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    
                    Text("System Health")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if controller.healthStatus.isChecking {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            // Expanded details
            if isExpanded {
                VStack(spacing: 4) {
                    HealthCheckRow(
                        label: "gphoto2",
                        isOK: controller.healthStatus.gphoto2Installed,
                        detail: controller.healthStatus.gphoto2Installed ? "Installed" : "Not found"
                    )
                    
                    HealthCheckRow(
                        label: "Daemons",
                        isOK: controller.healthStatus.daemonsKilled,
                        detail: controller.healthStatus.daemonsKilled ? "Cleared" : "Active ⚠️"
                    )
                    
                    HealthCheckRow(
                        label: "Camera",
                        isOK: controller.healthStatus.cameraDetected,
                        detail: controller.healthStatus.cameraDetected ? controller.healthStatus.cameraModel : "Not detected"
                    )
                    
                    HealthCheckRow(
                        label: "Storage",
                        isOK: controller.healthStatus.captureFolderWritable,
                        detail: controller.healthStatus.captureFolderWritable ? "Writable" : "Not writable"
                    )
                    
                    // Refresh button
                    Button(action: {
                        controller.refreshHealthChecks()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(controller.healthStatus.isChecking)
                    .padding(.top, 4)
                    
                    // Quick help if issues
                    if !controller.healthStatus.allGood {
                        VStack(alignment: .leading, spacing: 2) {
                            if !controller.healthStatus.gphoto2Installed {
                                Text("Run: brew install gphoto2")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                            if !controller.healthStatus.cameraDetected {
                                Text("Check USB & disable camera WiFi")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var statusColor: Color {
        if controller.healthStatus.isChecking {
            return .gray
        }
        return controller.healthStatus.allGood ? .green : .orange
    }
}

struct HealthCheckRow: View {
    let label: String
    let isOK: Bool
    let detail: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isOK ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundColor(isOK ? .green : .orange)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
            
            Spacer()
            
            Text(detail)
                .font(.caption2)
                .foregroundColor(isOK ? .secondary : .orange)
                .lineLimit(1)
        }
    }
}

#Preview {
    ContentView()
}
