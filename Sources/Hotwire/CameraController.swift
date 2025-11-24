import Foundation
import SwiftUI
import Combine

@MainActor
class CameraController: ObservableObject {
    // Connection State
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var statusMessage: String = "Ready"
    @Published var daemonKillerActive: Bool = false

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
    private var daemonKillerTimer: Timer?
    private var connectionMonitorTimer: Timer?
    private let gphoto2Path = "/opt/homebrew/bin/gphoto2"
    private var isFetchingFrame: Bool = false
    private var liveViewRetryCount: Int = 0
    private let maxLiveViewRetries: Int = 5
    private var isCheckingConnection: Bool = false

    // MARK: - Initialization
    
    init() {
        // Default capture folder on Desktop
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        self.captureFolder = desktop.appendingPathComponent("Hotwire Captures")
    }

    func initialize() {
        statusMessage = "Initializing HOTWIRE..."
        
        // Start the Daemon Killer first - this is critical
        startDaemonKiller()
        
        // Start connection monitor
        startConnectionMonitor()
        
        setupCaptureFolder()
        checkGphoto2Installation()
        
        // Give daemon killer a moment to clear the USB
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await scanForCamera()
            loadExistingCaptures()
        }
    }
    
    // MARK: - Connection Monitor
    
    /// Monitors camera connection and updates status when unplugged
    private func startConnectionMonitor() {
        // Check connection every 3 seconds
        connectionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkConnectionStatus()
            }
        }
    }
    
    private func stopConnectionMonitor() {
        connectionMonitorTimer?.invalidate()
        connectionMonitorTimer = nil
    }
    
    /// Quick check if camera is still connected
    private func checkConnectionStatus() async {
        // Don't check if we're already checking or doing other operations
        guard !isCheckingConnection, !isCapturing, !isFetchingFrame else { return }
        
        isCheckingConnection = true
        
        let output = await getCommandOutput(gphoto2Path, arguments: ["--auto-detect"])
        let nowConnected = output.contains("Canon")
        
        let wasConnected = isConnected
        
        if wasConnected && !nowConnected {
            // Camera was disconnected
            isConnected = false
            connectionStatus = "Disconnected"
            statusMessage = "⚠️ Camera disconnected"
            
            // Stop live view if it was running
            if isLiveViewActive {
                stopLiveView()
            }
        } else if !wasConnected && nowConnected {
            // Camera was reconnected
            isConnected = true
            connectionStatus = "Connected"
            statusMessage = "✓ Camera reconnected"
            
            // Fetch settings
            await fetchCurrentSettings()
        }
        
        isCheckingConnection = false
    }
    
    /// Get command output as string
    private func getCommandOutput(_ command: String, arguments: [String]) async -> String {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = FileHandle.nullDevice
            
            do {
                try process.run()
                process.waitUntilExit()
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
    
    // MARK: - Daemon Killer (Phase 1 Critical Feature)
    
    /// Starts a background process that continuously kills macOS camera daemons
    /// This prevents PTPCamera and ptpcamerad from stealing the USB connection
    private func startDaemonKiller() {
        daemonKillerActive = true
        statusMessage = "🔪 Daemon Killer active"
        
        // Kill immediately on startup
        Task {
            await killAllCameraDaemons()
        }
        
        // Then keep killing every 2 seconds
        daemonKillerTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.killAllCameraDaemons()
            }
        }
    }
    
    func stopDaemonKiller() {
        daemonKillerTimer?.invalidate()
        daemonKillerTimer = nil
        daemonKillerActive = false
    }
    
    /// Kills all known macOS daemons that interfere with USB camera access
    private func killAllCameraDaemons() async {
        // These are the culprits that steal USB camera connections on macOS:
        // 1. ptpcamerad - The main PTP camera daemon (most aggressive)
        // 2. PTPCamera - Legacy daemon
        // 3. photolibraryd - Can sometimes grab the device
        
        let daemons = ["ptpcamerad", "PTPCamera"]
        
        for daemon in daemons {
            _ = await runCommandQuiet("/usr/bin/killall", arguments: ["-9", daemon])
        }
    }
    
    /// Run a command without updating status (for background daemon killing)
    private func runCommandQuiet(_ command: String, arguments: [String]) async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            
            do {
                try process.run()
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus == 0)
            } catch {
                continuation.resume(returning: false)
            }
        }
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
            // Daemon killer should already be running, but ensure daemons are dead
            await killAllCameraDaemons()
            try? await Task.sleep(nanoseconds: 300_000_000)

            // Detect camera
            let result = await runCommand(gphoto2Path, arguments: ["--auto-detect"])

            if result.success && result.output.contains("Canon") {
                isConnected = true
                connectionStatus = "Connected"
                statusMessage = "✓ Canon 6D Mark II connected"

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
        await killAllCameraDaemons()
        
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

        // Start timer to fetch live view frames
        // With daemon killer running, we can try faster frame rate
        liveViewTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
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
        
        // Use unique filename to avoid overwrite prompts
        let previewPath = "/tmp/hotwire_lv_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"

        // Use atomic kill-and-capture: kill daemons then immediately run gphoto2
        // The 'yes |' auto-answers any prompts, preventing hangs
        let result = await runShellCommand("""
            killall -9 ptpcamerad PTPCamera 2>/dev/null; \
            killall -9 ptpcamerad PTPCamera 2>/dev/null; \
            killall -9 ptpcamerad PTPCamera 2>/dev/null; \
            yes | \(gphoto2Path) --capture-preview --filename="\(previewPath)" 2>&1
            """)

        if result.success || result.output.contains("Saving file") {
            if let image = NSImage(contentsOfFile: previewPath) {
                liveViewImage = image
                if liveViewRetryCount > 0 {
                    statusMessage = "Live view restored"
                } else {
                    statusMessage = "🔴 Live"
                }
                liveViewRetryCount = 0
            }
            // Clean up temp file
            try? FileManager.default.removeItem(atPath: previewPath)
        } else {
            liveViewRetryCount += 1
            
            if liveViewRetryCount >= maxLiveViewRetries {
                stopLiveView()
                statusMessage = "Live view failed. Try unplugging and reconnecting camera."
            } else {
                statusMessage = "Live view connecting (\(liveViewRetryCount)/\(maxLiveViewRetries))..."
            }
        }

        isFetchingFrame = false
    }
    
    /// Run a shell command (for atomic kill-and-execute operations)
    private func runShellCommand(_ command: String) async -> (success: Bool, output: String, error: String) {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]

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

                // Check for successful capture (file saved message or no error)
                let success = process.terminationStatus == 0 || output.contains("Saving file")

                continuation.resume(returning: (success, output, error))
            } catch {
                continuation.resume(returning: (false, "", error.localizedDescription))
            }
        }
    }

    // MARK: - Image Capture

    func captureImage() {
        guard !isCapturing else { return }

        isCapturing = true
        statusMessage = "Capturing image..."

        Task {
            // Kill camera daemons before accessing camera
            await killAllCameraDaemons()
            
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
            await killAllCameraDaemons()
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
            await killAllCameraDaemons()
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
            await killAllCameraDaemons()
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
