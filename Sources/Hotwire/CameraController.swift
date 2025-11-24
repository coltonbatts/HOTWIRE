import Foundation
import SwiftUI
import Combine

@MainActor
class CameraController: ObservableObject {
    // Connection State
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var statusMessage: String = "Ready"

    // Live View
    @Published var isLiveViewActive: Bool = false
    @Published var liveViewImage: NSImage? = nil

    // Capture State
    @Published var isCapturing: Bool = false
    @Published var lastCapturedImage: NSImage? = nil
    @Published var lastCapturedPath: String? = nil
    
    // Captured Images Gallery
    @Published var capturedImages: [CapturedImage] = []
    @Published var selectedImage: CapturedImage? = nil
    
    // Tethered Capture Folder
    @Published var captureFolder: URL
    
    // Camera Settings
    @Published var selectedISO: String = "Auto"
    @Published var selectedAperture: String = "f/5.6"
    @Published var selectedShutter: String = "1/125"

    @Published var availableISOs: [String] = ["Auto", "100", "125", "160", "200", "250", "320", "400", "500", "640", "800", "1000", "1250", "1600", "2000", "2500", "3200", "4000", "5000", "6400", "8000", "10000", "12800", "16000", "20000", "25600", "32000", "40000"]
    @Published var availableApertures: [String] = ["f/1.4", "f/1.8", "f/2", "f/2.8", "f/3.5", "f/4", "f/4.5", "f/5", "f/5.6", "f/6.3", "f/7.1", "f/8", "f/9", "f/10", "f/11", "f/13", "f/14", "f/16", "f/18", "f/20", "f/22"]
    @Published var availableShutterSpeeds: [String] = ["30", "25", "20", "15", "13", "10", "8", "6", "5", "4", "3.2", "2.5", "2", "1.6", "1.3", "1", "0.8", "0.6", "0.5", "0.4", "0.3", "1/4", "1/5", "1/6", "1/8", "1/10", "1/13", "1/15", "1/20", "1/25", "1/30", "1/40", "1/50", "1/60", "1/80", "1/100", "1/125", "1/160", "1/200", "1/250", "1/320", "1/400", "1/500", "1/640", "1/800", "1/1000", "1/1250", "1/1600", "1/2000", "1/2500", "1/3200", "1/4000", "1/5000", "1/6400", "1/8000"]

    private var liveViewTimer: Timer?
    private let gphoto2Path = "/opt/homebrew/bin/gphoto2"
    private var isFetchingFrame: Bool = false
    private var liveViewRetryCount: Int = 0
    private let maxLiveViewRetries: Int = 3

    // MARK: - Initialization
    
    init() {
        // Default capture folder on Desktop
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        self.captureFolder = desktop.appendingPathComponent("Canon Tethered Captures")
    }

    func initialize() {
        statusMessage = "Initializing..."
        setupCaptureFolder()
        checkGphoto2Installation()
        scanForCamera()
        loadExistingCaptures()
    }
    
    private func setupCaptureFolder() {
        do {
            try FileManager.default.createDirectory(at: captureFolder, withIntermediateDirectories: true)
            statusMessage = "Capture folder ready: \(captureFolder.path)"
        } catch {
            statusMessage = "Failed to create capture folder: \(error.localizedDescription)"
        }
    }
    
    func selectCaptureFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select folder for tethered captures"
        panel.prompt = "Select"
        
        if panel.runModal() == .OK, let url = panel.url {
            captureFolder = url
            statusMessage = "Capture folder: \(url.path)"
            loadExistingCaptures()
        }
    }
    
    private func loadExistingCaptures() {
        capturedImages.removeAll()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: captureFolder, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            
            let imageFiles = files.filter { url in
                let ext = url.pathExtension.lowercased()
                return ["jpg", "jpeg", "cr2", "cr3", "raw", "tiff", "tif", "png"].contains(ext)
            }.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2 // Most recent first
            }
            
            for fileURL in imageFiles.prefix(50) { // Load last 50 images
                if let image = NSImage(contentsOf: fileURL) {
                    let captured = CapturedImage(
                        id: UUID(),
                        url: fileURL,
                        thumbnail: createThumbnail(from: image, size: 100),
                        fullImage: image,
                        filename: fileURL.lastPathComponent,
                        captureDate: (try? fileURL.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()
                    )
                    capturedImages.append(captured)
                }
            }
            
            // Select the most recent image
            if let first = capturedImages.first {
                selectedImage = first
                lastCapturedImage = first.fullImage
            }
            
        } catch {
            statusMessage = "Failed to load existing captures: \(error.localizedDescription)"
        }
    }
    
    private func createThumbnail(from image: NSImage, size: CGFloat) -> NSImage {
        let thumbnail = NSImage(size: NSSize(width: size, height: size))
        thumbnail.lockFocus()
        
        let aspectRatio = image.size.width / image.size.height
        var drawRect: NSRect
        
        if aspectRatio > 1 {
            let height = size / aspectRatio
            drawRect = NSRect(x: 0, y: (size - height) / 2, width: size, height: height)
        } else {
            let width = size * aspectRatio
            drawRect = NSRect(x: (size - width) / 2, y: 0, width: width, height: size)
        }
        
        image.draw(in: drawRect, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
        thumbnail.unlockFocus()
        
        return thumbnail
    }

    // MARK: - Camera Detection

    private func checkGphoto2Installation() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: gphoto2Path) {
            statusMessage = "⚠️ gphoto2 not installed. Run: brew install gphoto2"
            return
        }
        statusMessage = "gphoto2 found"
    }

    func scanForCamera() {
        statusMessage = "Scanning for camera..."

        Task {
            // First, kill camera daemons
            await killPTPCamera()

            // Detect camera
            let result = await runCommand(gphoto2Path, arguments: ["--auto-detect"])

            if result.success && result.output.contains("Canon") {
                isConnected = true
                connectionStatus = "Connected"
                statusMessage = "Canon 6D Mark II detected"

                // Get current camera settings
                await fetchCurrentSettings()
            } else {
                isConnected = false
                connectionStatus = "Not Found"
                statusMessage = "Camera not detected. Check WiFi is disabled and USB is connected."
            }
        }
    }
    
    private func fetchCurrentSettings() async {
        await ensureDeviceAccess()
        
        // Get current ISO
        let isoResult = await runCommand(gphoto2Path, arguments: ["--get-config", "iso"])
        if isoResult.success, let current = parseCurrentValue(from: isoResult.output) {
            selectedISO = current
        }
        
        // Get current aperture
        let apertureResult = await runCommand(gphoto2Path, arguments: ["--get-config", "aperture"])
        if apertureResult.success, let current = parseCurrentValue(from: apertureResult.output) {
            selectedAperture = "f/\(current)"
        }
        
        // Get current shutter speed
        let shutterResult = await runCommand(gphoto2Path, arguments: ["--get-config", "shutterspeed"])
        if shutterResult.success, let current = parseCurrentValue(from: shutterResult.output) {
            selectedShutter = current
        }
        
        statusMessage = "Camera ready - Settings loaded"
    }
    
    private func parseCurrentValue(from output: String) -> String? {
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.starts(with: "Current:") {
                return line.replacingOccurrences(of: "Current:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private func killPTPCamera() async {
        // Kill both ptpcamerad and PTPCamera - both can claim the USB device
        _ = await runCommand("/usr/bin/killall", arguments: ["-9", "ptpcamerad"])
        _ = await runCommand("/usr/bin/killall", arguments: ["-9", "PTPCamera"])
        try? await Task.sleep(nanoseconds: 300_000_000) // Wait 300ms
    }
    
    /// Kill camera daemons before any camera operation
    private func ensureDeviceAccess() async {
        // Must kill ptpcamerad - this is the main culprit on modern macOS
        _ = await runCommand("/usr/bin/killall", arguments: ["-9", "ptpcamerad"])
        _ = await runCommand("/usr/bin/killall", arguments: ["-9", "PTPCamera"])
        try? await Task.sleep(nanoseconds: 300_000_000) // Wait 300ms
    }

    private func getCameraSummary() async {
        let result = await runCommand(gphoto2Path, arguments: ["--summary"])
        if result.success {
            statusMessage = "Camera ready"
        }
    }

    // MARK: - Live View

    func toggleLiveView() {
        if isLiveViewActive {
            stopLiveView()
        } else {
            startLiveView()
        }
    }

    private func startLiveView() {
        statusMessage = "Starting live view..."
        isLiveViewActive = true
        liveViewRetryCount = 0

        // Start timer to fetch live view frames (every 0.8s for stability)
        liveViewTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchLiveViewFrame()
            }
        }
        
        // Fetch first frame immediately
        Task {
            await fetchLiveViewFrame()
        }
    }

    private func stopLiveView() {
        liveViewTimer?.invalidate()
        liveViewTimer = nil
        isLiveViewActive = false
        liveViewImage = nil
        liveViewRetryCount = 0
        statusMessage = "Live view stopped"
    }

    private func fetchLiveViewFrame() async {
        // Prevent concurrent fetches
        guard !isFetchingFrame, isLiveViewActive else { return }

        isFetchingFrame = true
        
        // Kill camera daemons before accessing camera
        await ensureDeviceAccess()

        let previewPath = "/tmp/canon_preview_\(UUID().uuidString).jpg"

        let result = await runCommand(gphoto2Path, arguments: [
            "--capture-preview",
            "--filename=\(previewPath)"
        ])

        if result.success {
            if let image = NSImage(contentsOfFile: previewPath) {
                liveViewImage = image
                statusMessage = "Live view active"
                liveViewRetryCount = 0 // Reset retry count on success
            }
            // Clean up temp file
            try? FileManager.default.removeItem(atPath: previewPath)
        } else {
            liveViewRetryCount += 1
            
            if liveViewRetryCount >= maxLiveViewRetries {
                stopLiveView()
                statusMessage = "Live view failed after \(maxLiveViewRetries) attempts. Try again."
            } else {
                statusMessage = "Live view retry \(liveViewRetryCount)/\(maxLiveViewRetries)..."
            }
        }

        isFetchingFrame = false
    }

    // MARK: - Image Capture

    func captureImage() {
        guard !isCapturing else { return }

        isCapturing = true
        statusMessage = "Capturing image..."

        Task {
            // Kill camera daemons before accessing camera
            await ensureDeviceAccess()
            
            // Create filename with timestamp
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = dateFormatter.string(from: Date())
            let filename = "IMG_\(timestamp).jpg"
            let fullPath = captureFolder.appendingPathComponent(filename)
            
            let result = await runCommand(gphoto2Path, arguments: [
                "--capture-image-and-download",
                "--filename=\(fullPath.path)"
            ])

            if result.success {
                statusMessage = "✓ Captured: \(filename)"
                lastCapturedPath = fullPath.path
                
                // Load and display the captured image
                if let image = NSImage(contentsOf: fullPath) {
                    lastCapturedImage = image
                    
                    // Add to gallery
                    let captured = CapturedImage(
                        id: UUID(),
                        url: fullPath,
                        thumbnail: createThumbnail(from: image, size: 100),
                        fullImage: image,
                        filename: filename,
                        captureDate: Date()
                    )
                    capturedImages.insert(captured, at: 0)
                    selectedImage = captured
                }
            } else {
                statusMessage = "Capture failed: \(result.error)"
            }

            isCapturing = false
        }
    }
    
    func revealInFinder(_ image: CapturedImage) {
        NSWorkspace.shared.selectFile(image.url.path, inFileViewerRootedAtPath: captureFolder.path)
    }
    
    func deleteImage(_ image: CapturedImage) {
        do {
            try FileManager.default.removeItem(at: image.url)
            capturedImages.removeAll { $0.id == image.id }
            if selectedImage?.id == image.id {
                selectedImage = capturedImages.first
                lastCapturedImage = selectedImage?.fullImage
            }
            statusMessage = "Deleted: \(image.filename)"
        } catch {
            statusMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }

    // MARK: - Settings

    func updateISO() {
        Task {
            await ensureDeviceAccess()
            let result = await runCommand(gphoto2Path, arguments: [
                "--set-config",
                "iso=\(selectedISO)"
            ])

            if result.success {
                statusMessage = "ISO set to \(selectedISO)"
            } else {
                statusMessage = "Failed to set ISO: \(result.error)"
            }
        }
    }

    func updateAperture() {
        Task {
            await ensureDeviceAccess()
            // Remove "f/" prefix for gphoto2
            let apertureValue = selectedAperture.replacingOccurrences(of: "f/", with: "")
            let result = await runCommand(gphoto2Path, arguments: [
                "--set-config",
                "aperture=\(apertureValue)"
            ])

            if result.success {
                statusMessage = "Aperture set to \(selectedAperture)"
            } else {
                statusMessage = "Failed to set aperture: \(result.error)"
            }
        }
    }

    func updateShutterSpeed() {
        Task {
            await ensureDeviceAccess()
            let result = await runCommand(gphoto2Path, arguments: [
                "--set-config",
                "shutterspeed=\(selectedShutter)"
            ])

            if result.success {
                statusMessage = "Shutter speed set to \(selectedShutter)"
            } else {
                statusMessage = "Failed to set shutter speed: \(result.error)"
            }
        }
    }

    // MARK: - Command Execution

    private func runCommand(_ command: String, arguments: [String]) async -> (success: Bool, output: String, error: String) {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""

                let success = process.terminationStatus == 0

                continuation.resume(returning: (success, output, error))
            } catch {
                continuation.resume(returning: (false, "", error.localizedDescription))
            }
        }
    }
}

// MARK: - Captured Image Model

struct CapturedImage: Identifiable {
    let id: UUID
    let url: URL
    let thumbnail: NSImage
    let fullImage: NSImage
    let filename: String
    let captureDate: Date
}
