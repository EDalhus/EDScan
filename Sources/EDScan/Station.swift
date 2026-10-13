import Foundation
import AppKit
import Combine
import CoolscanKit

/// The station: screen flow, the active order and its frames, and job execution.
///
/// Flow (as on a Frontier): Order Entry → START (preview job) → frame check →
/// START (scan job, timed) → files written to the output media in the background →
/// next order. Each preview and each scan is its own job with its own ID.
@MainActor
final class Station: ObservableObject {
    enum Screen: Equatable {
        case jobList, orderEntry, frameCheck, enlarged, customerImages
    }
    enum Overlay { case imageCorrect, toneAdjust, help }
    enum JobFilter: String, CaseIterable { case all = "All Device Job", scan = "Scan Jobs", preview = "Preview Jobs", attention = "Needs Attention" }

    let scanner: ScannerManager
    let settings: ScanSettings
    let store: JobStore

    @Published var screen: Screen = .jobList
    @Published var overlay: Overlay?
    @Published var orderTab = 0
    @Published var order: OrderEntry { didSet { if order != oldValue { order.save() } } }

    // Active order
    @Published private(set) var orderNumber: Int?
    @Published private(set) var frames: [Int] = []
    @Published private(set) var corrections: [Int: FrameCorrection] = [:]
    @Published private(set) var thumbs: [Int: NSImage] = [:]
    @Published var selectedFrame = 0 {
        didSet {
            // Tone Adjustment follows the selection: keep the frame being left, start fresh on the new one.
            if overlay == .toneAdjust, selectedFrame != oldValue, frames.contains(selectedFrame) {
                toneOriginal = (selectedFrame, correction(selectedFrame))
            }
        }
    }
    private var sources: [Int: CGImage] = [:]       // downscaled previews, uncorrected
    private var subNumber = 0
    /// Set when the scanner rejects ICE (holder/mode without infrared); later scans skip ICE until the scanner changes.
    private var iceUnavailable = false

    // Job list / customer view
    @Published var selectedJobID: String?
    @Published var browsingCustomerID: String?
    @Published var jobFilter: JobFilter = .all
    @Published var jobSearch = ""
    @Published var alert: String?
    @Published var notice: String?
    /// Selected frame's correction when Tone Adjustment opened (restored on Cancel).
    private var toneOriginal: (frame: Int, correction: FrameCorrection)?
    /// Leftover scanimage processes blocking the scanner, and what to run again once they are stopped.
    @Published var strayProcesses: [StrayScanimage.Item] = []
    private var strayRetry: (() async -> Void)?
    /// Job awaiting "Delete" confirmation.
    @Published var confirmDeleteJobID: String?

    private var cancellables = Set<AnyCancellable>()

    init(scanner: ScannerManager, settings: ScanSettings, store: JobStore) {
        self.scanner = scanner
        self.settings = settings
        self.store = store
        self.order = OrderEntry.load()

        scanner.$availableScanners
            .receive(on: RunLoop.main)
            .sink { [weak self] list in self?.autoConnect(list) }
            .store(in: &cancellables)
        // Re-publish scanner changes so views that only observe the station stay current.
        scanner.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        store.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
    }

    // MARK: - Scanner

    /// Connects to the remembered scanner, else the first real one, else the simulator.
    /// A real scanner plugged in later replaces the simulator unless it was chosen by hand.
    private func autoConnect(_ list: [ScannerDevice]) {
        guard !scanner.isBusy else { return }
        let real = list.filter { $0.model != .simulated }
        if let current = scanner.connectedScanner, list.contains(current) {
            let chosenSim = order.scannerName == ScannerModel.simulated.rawValue
            guard current.model == .simulated, !chosenSim, let first = real.first else { return }
            attach(first)
            return
        }
        if let pick = list.first(where: { $0.name == order.scannerName }) ?? real.first ?? list.first {
            attach(pick)
        }
    }

    /// Chosen by hand: remembered for next launch.
    func connect(_ device: ScannerDevice) {
        guard !scanner.isBusy else { return }
        attach(device)
        order.scannerName = device.name
    }

    private func attach(_ device: ScannerDevice) {
        scanner.connect(to: device)
        iceUnavailable = false
    }

    var scannerModel: ScannerModel? { scanner.connectedScanner?.model }

    // MARK: - Customer

    var currentCustomer: Customer? { store.customer(order.customerID) }

    func setCustomer(_ c: Customer?) { order.customerID = c?.id }

    func newCustomer(named name: String) {
        setCustomer(store.createCustomer(name: name))
    }

    // MARK: - Order

    /// Header "00718 - 01": active order, or the number the next order will get.
    var headerJobNumber: String {
        let n = orderNumber ?? store.peekOrderNumber
        return String(format: "%05d - %02d", n, subNumber + 1)
    }

    func newOrder() {
        guard !scanner.isBusy else { return }
        resetOrder()
        overlay = nil
        screen = .orderEntry
    }

    private func resetOrder() {
        orderNumber = nil
        subNumber = 0
        frames = []
        corrections = [:]
        thumbs = [:]
        sources = [:]
        selectedFrame = 0
    }

    /// Order Finish: close the order and get ready for the next film.
    func orderFinish() {
        guard !scanner.isBusy else { return }
        resetOrder()
        overlay = nil
        screen = .orderEntry
    }

    func mainMenu() {
        overlay = nil
        screen = .jobList
    }

    private func applyOrderToSettings() {
        settings.filmType = order.filmKind.coolscan
        settings.resolution = order.imageSize.dpi(for: scannerModel)
        settings.digitalICE = iceUnavailable ? .off : order.ice
        settings.multiScan = order.multiScan
        settings.bitDepth = order.highBitDepth && order.fileFormat == .tiff ? .bit14 : .bit8
        settings.cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    private func makeJob(_ kind: JobKind) -> ScanJob {
        if orderNumber == nil { orderNumber = store.allocateOrderNumber() }
        subNumber += 1
        let customer = currentCustomer
        return ScanJob(
            id: JobStore.jobID(order: orderNumber!, sub: subNumber),
            orderNumber: orderNumber!,
            kind: kind,
            created: Date(),
            customerID: customer?.id,
            customerName: customer?.name,
            scanner: scanner.connectedScanner?.name ?? "—",
            filmKind: order.filmKind,
            imageSize: order.imageSize,
            dpi: order.imageSize.dpi(for: scannerModel),
            outputMedia: order.outputMedia,
            fileFormat: order.fileFormat,
            discCopies: order.discCopies
        )
    }

    private func canRun() -> Bool {
        guard scanner.connectedScanner != nil else {
            alert = "No scanner selected. Click the scanner icon in the status bar."
            return false
        }
        return !scanner.isBusy
    }

    /// A real scanner is held by any scanimage still running while we are idle; ask before starting.
    private func scannerIsFree(retry: @escaping () async -> Void) -> Bool {
        guard scannerModel != .simulated else { return true }
        let stray = StrayScanimage.find()
        guard !stray.isEmpty else { return true }
        strayRetry = retry
        strayProcesses = stray
        return false
    }

    func stopStrayAndRetry() {
        StrayScanimage.stop(strayProcesses)
        strayProcesses = []
        let retry = strayRetry
        strayRetry = nil
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)   // let the USB device be released
            await retry?()
        }
    }

    func dismissStray() {
        strayProcesses = []
        strayRetry = nil
    }

    // MARK: - Preview job (START on Order Entry)

    func start() async {
        guard canRun() else { return }
        if !frames.isEmpty {   // already previewed: START means scan
            await scanFrames()
            return
        }
        guard scannerIsFree(retry: { await self.start() }) else { return }
        applyOrderToSettings()
        var job = makeJob(.preview)
        job.status = .previewing
        job.started = Date()
        store.add(job)

        scanner.framePreviews = [:]
        scanner.lastError = nil
        let t0 = Date()
        if order.previewAllFrames {
            await scanner.autoPreviewAllFrames(settings: settings)
        } else {
            scanner.selectFrame(0)
            await scanner.preview(settings: settings)
        }
        // Auto-preview gives up silently when the first frame fails for any reason other than
        // "no frame option". One plain preview of frame 1 either works or reports the real error.
        if scanner.framePreviews.isEmpty, order.previewAllFrames, scanner.lastError == nil,
           scanner.statusMessage != "Cancelled" {
            scanner.selectFrame(0)
            await scanner.preview(settings: settings)
        }
        let elapsed = Date().timeIntervalSince(t0)
        let got = scanner.framePreviews.keys.sorted()

        guard !got.isEmpty else {
            store.update(job.id) {
                $0.status = self.scanner.lastError == nil ? .cancelled : .failed
                $0.statusDetail = self.scanner.lastError ?? self.scanner.statusMessage
                $0.finished = Date()
                $0.scanDuration = elapsed
            }
            return
        }

        frames = got
        for f in got {
            if let cg = scanner.framePreviews[f].flatMap(FrameRenderer.cgImage) {
                sources[f] = FrameRenderer.downscale(cg, maxPixel: 1400)
            }
            corrections[f] = order.defaultCorrection
            renderThumb(f)
        }
        selectedFrame = got[0]

        let saved = saveThumbnails(jobID: job.id, frames: got)
        store.update(job.id) {
            $0.status = .completed
            $0.finished = Date()
            $0.scanDuration = elapsed
            $0.requestedFrames = got.count
            $0.frames = saved
        }
        screen = .frameCheck

        if order.mode == .auto { await scanFrames() }
    }

    // MARK: - Scan job (START on frame check)

    func scanFrames() async {
        guard canRun() else { return }
        guard scannerIsFree(retry: { await self.scanFrames() }) else { return }
        let todo = frames.filter { correction($0).printSet > 0 }
        guard !todo.isEmpty else {
            alert = "All frames have P.SET 0 — nothing to scan."
            return
        }
        applyOrderToSettings()
        var job = makeJob(.scan)
        job.status = .scanning
        job.started = Date()
        job.requestedFrames = todo.count
        store.add(job)
        overlay = nil

        scanner.scannedFrames = [:]
        scanner.lastError = nil
        scanner.selectedFrames = Set(todo)
        scanner.selectedFrame = todo[0]

        let t0 = Date()
        await scanner.scan(settings: settings)
        var iceNote: String?
        // ICE rejected for this holder/mode: rescan the remaining frames without it instead of failing the job.
        if Self.isICEUnavailable(scanner.lastError), settings.digitalICE != .off {
            iceUnavailable = true
            settings.digitalICE = .off
            scanner.lastError = nil
            iceNote = "Digital ICE not available in this holder/mode — scanned without ICE"
            let remaining = todo.filter { scanner.scannedFrames[$0] == nil }
            if let first = remaining.first {
                scanner.selectedFrames = Set(remaining)
                scanner.selectedFrame = first
                await scanner.scan(settings: settings)
            }
        }
        let elapsed = Date().timeIntervalSince(t0)
        let done = todo.filter { scanner.scannedFrames[$0] != nil }
        if let iceNote { store.update(job.id) { $0.statusDetail = iceNote } }

        store.update(job.id) { $0.scanDuration = elapsed }
        if done.count < todo.count {
            let cancelled = scanner.lastError == nil
            store.update(job.id) {
                $0.status = cancelled ? .cancelled : .failed
                $0.statusDetail = "\(done.count)/\(todo.count) frames. " + (scanner.lastError ?? scanner.statusMessage)
                if done.isEmpty { $0.finished = Date() }
            }
            if done.isEmpty { return }
        } else {
            store.update(job.id) { $0.status = .converting }
        }

        // Hand the full-resolution frames to a background writer; the scanner is free again.
        let work = done.compactMap { f -> (Int, CGImage, FrameCorrection)? in
            guard let cg = scanner.scannedFrames[f].flatMap(FrameRenderer.cgImage) else { return nil }
            return (f, cg, correction(f))
        }
        // The scanner also keeps full-resolution copies as previews; ours are downscaled in `sources`.
        scanner.scannedFrames = [:]
        scanner.framePreviews = [:]
        let snapshot = store.job(job.id) ?? job
        let options = OutputOptions(baseFolder: outputBase(for: snapshot.outputMedia), quality: order.jpegQuality,
                                    indexSheet: order.indexSheet, deep: settings.bitDepth != .bit8)
        Task { await self.writeOutput(snapshot, work: work, options: options) }

        if order.finishAfterScan && done.count == todo.count {
            notice = "Job \(job.id) scanned in \(elapsed.clock) — ready for next film"
            orderFinish()
        }
    }

    static func isICEUnavailable(_ error: String?) -> Bool {
        error?.contains("Digital ICE (infrared) is not available") == true
    }

    // MARK: - Output

    /// Settings captured when the scan finishes, so later Order Entry changes don't affect a job being written.
    private struct OutputOptions {
        var baseFolder: String
        var quality: Double
        var indexSheet: Bool
        var deep: Bool
    }

    private func outputBase(for media: OutputMedia) -> String {
        switch media {
        case .disc: return store.root.appendingPathComponent("Disc Staging", isDirectory: true).path
        case .localDisk: return order.localFolder
        case .networkShare: return order.networkFolder
        }
    }

    private func destinationFolder(for job: ScanJob, base path: String) throws -> URL {
        let base: URL
        switch job.outputMedia {
        case .disc:
            base = URL(fileURLWithPath: path, isDirectory: true)
        case .localDisk, .networkShare:
            guard !path.isEmpty else {
                throw NSError(domain: "EDScan", code: 1, userInfo: [NSLocalizedDescriptionKey: "No \(job.outputMedia.title) folder set (Process 2)"])
            }
            base = URL(fileURLWithPath: path, isDirectory: true)
            if job.outputMedia == .networkShare, !FileManager.default.fileExists(atPath: base.path) {
                throw NSError(domain: "EDScan", code: 2, userInfo: [NSLocalizedDescriptionKey: "Network share not mounted: \(path)"])
            }
        }
        var folder = base
        if let id = job.customerID {
            let name = (job.customerName ?? "").replacingOccurrences(of: "/", with: "-")
            folder.appendPathComponent(name.isEmpty ? id : "\(id) \(name)", isDirectory: true)
        }
        folder.appendPathComponent(job.id, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func writeOutput(_ job: ScanJob, work: [(Int, CGImage, FrameCorrection)], options: OutputOptions) async {
        let folder: URL
        do { folder = try destinationFolder(for: job, base: options.baseFolder) } catch {
            store.update(job.id) { $0.status = .failed; $0.statusDetail = error.localizedDescription; $0.finished = Date() }
            return
        }
        let thumbFolder = store.jobFolder(job.id)
        let base = ExportMetadata(jobID: job.id, customerID: job.customerID, customerName: job.customerName,
                                  scanner: job.scanner, filmLabel: job.inputLabel, dpi: job.dpi, frameNumber: 0, date: job.created)

        let result: Result<([JobFrame], [(Int, CGImage)]), Error> = await Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.createDirectory(at: thumbFolder, withIntermediateDirectories: true)
                var out: [JobFrame] = []
                var small: [(Int, CGImage)] = []
                for (f, cg, c) in work {
                    guard let full = FrameRenderer.renderForExport(cg, c, deep: options.deep) else {
                        throw ImageExporter.ExportError.encode("frame \(f + 1)")
                    }
                    var meta = base
                    meta.frameNumber = f + 1
                    let name = "\(job.id)_\(String(format: "%02d", f + 1)).\(job.fileFormat.fileExtension)"
                    let url = folder.appendingPathComponent(name)
                    try ImageExporter.write(full, to: url, format: job.fileFormat, quality: options.quality, meta: meta)
                    let thumb = FrameRenderer.downscale(full, maxPixel: 600)
                    let thumbName = String(format: "thumb_%02d.jpg", f + 1)
                    try ImageExporter.writeJPEG(thumb, to: thumbFolder.appendingPathComponent(thumbName))
                    out.append(JobFrame(index: f, thumbnail: thumbName, file: url.path))
                    small.append((f, thumb))
                }
                if options.indexSheet, let sheet = IndexSheet.make(small, title: "\(job.id)  \(job.customerName ?? "")  \(job.customerID ?? "")") {
                    try ImageExporter.writeJPEG(sheet, to: folder.appendingPathComponent("\(job.id)_index.jpg"), quality: 0.85)
                }
                return .success((out, small))
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .failure(let error):
            store.update(job.id) { $0.status = .failed; $0.statusDetail = error.localizedDescription; $0.finished = Date() }
        case .success(let (frames, _)):
            store.update(job.id) {
                $0.frames = frames
                $0.outputFolder = folder.path
                if $0.status == .converting {
                    $0.status = job.outputMedia == .disc ? .waitingForDisc : .completed
                }
                if job.outputMedia != .disc { $0.finished = Date() }
            }
            if job.outputMedia == .disc, await DiscBurner.hasDrive() { await burn(job.id) }
            else if job.outputMedia == .disc {
                store.update(job.id) { $0.statusDetail = "No disc drive found — files staged in \(folder.path)" }
            }
        }
    }

    func burn(_ jobID: String) async {
        guard let job = store.job(jobID), let folder = job.outputFolder else { return }
        store.update(jobID) { $0.status = .burning; $0.statusDetail = "Disc \(job.discsBurned + 1)/\(job.discCopies)" }
        do {
            try await DiscBurner.burn(folder: URL(fileURLWithPath: folder))
            store.update(jobID) {
                $0.discsBurned += 1
                let done = $0.discsBurned >= $0.discCopies
                $0.status = done ? .completed : .waitingForDisc
                $0.statusDetail = done ? nil : "Insert blank disc \($0.discsBurned + 1)/\($0.discCopies)"
                if done { $0.finished = Date() }
            }
        } catch DiscBurner.BurnError.cancelled {
            store.update(jobID) { $0.status = .waitingForDisc; $0.statusDetail = "Burn cancelled" }
        } catch {
            store.update(jobID) { $0.status = .waitingForDisc; $0.statusDetail = "Burn failed: \(error.localizedDescription)" }
        }
    }

    func cancelBurn() { DiscBurner.cancel() }

    private func saveThumbnails(jobID: String, frames: [Int]) -> [JobFrame] {
        let folder = store.jobFolder(jobID)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return frames.compactMap { f in
            guard let src = sources[f], let cg = FrameRenderer.render(src, correction(f), maxPixel: 600) else { return nil }
            let name = String(format: "thumb_%02d.jpg", f + 1)
            guard (try? ImageExporter.writeJPEG(cg, to: folder.appendingPathComponent(name))) != nil else { return nil }
            return JobFrame(index: f, thumbnail: name, file: nil)
        }
    }

    // MARK: - Frame corrections

    func correction(_ f: Int) -> FrameCorrection { corrections[f] ?? order.defaultCorrection }

    func setCorrection(_ f: Int, _ c: FrameCorrection) {
        guard corrections[f] != c else { return }
        corrections[f] = c
        renderThumb(f)
    }

    func modifySelected(_ change: (inout FrameCorrection) -> Void) {
        guard frames.contains(selectedFrame) else { return }
        var c = correction(selectedFrame)
        change(&c)
        setCorrection(selectedFrame, c)
    }

    /// "All": copy the selected frame's corrections to every frame of the order.
    func applySelectedToAll() {
        let c = correction(selectedFrame)
        for f in frames { setCorrection(f, correction(f).adopting(c)) }
        notice = "Frame \(selectedFrame + 1) corrections applied to all frames"
    }

    func adjustKey(_ key: WritableKeyPath<FrameCorrection, Int>, _ delta: Int) {
        modifySelected { c in
            c[keyPath: key] = min(FrameCorrection.keyRange.upperBound, max(FrameCorrection.keyRange.lowerBound, c[keyPath: key] + delta))
        }
    }

    func rotateSelected() { modifySelected { $0.rotation = ($0.rotation + 90) % 360 } }

    func togglePrintSet() { modifySelected { $0.printSet = $0.printSet > 0 ? 0 : 1 } }

    func moveSelection(_ delta: Int) {
        guard let i = frames.firstIndex(of: selectedFrame) else { return }
        selectedFrame = frames[min(frames.count - 1, max(0, i + delta))]
    }

    func source(_ f: Int) -> CGImage? { sources[f] }

    func resetSelected() { modifySelected { $0 = FrameCorrection().withPrintSet($0.printSet).withRotation($0.rotation) } }

    // Tone Adjustment edits the frame live; Cancel restores, Hold also makes it the default.
    func openToneAdjust() {
        guard frames.contains(selectedFrame) else { return }
        toneOriginal = (selectedFrame, correction(selectedFrame))
        overlay = .toneAdjust
    }

    enum ToneClose { case ok, hold, cancel }

    func closeToneAdjust(_ how: ToneClose) {
        switch how {
        case .ok: break
        case .hold:
            let c = correction(toneOriginal?.frame ?? selectedFrame)
            order.defaultCorrection.tone = c.tone
            order.defaultCorrection.hypertone = c.hypertone
            notice = "\(c.tone.title)\(c.hypertone ? " + Hypertone" : "") held as default for new frames"
        case .cancel:
            if let o = toneOriginal { setCorrection(o.frame, o.correction) }
        }
        toneOriginal = nil
        overlay = nil
    }

    private func renderThumb(_ f: Int) {
        guard let src = sources[f] else { return }
        thumbs[f] = FrameRenderer.renderImage(src, correction(f))
    }

    // MARK: - Job list actions

    func revealOutput(_ job: ScanJob) {
        guard let folder = job.outputFolder else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: folder)])
    }

    /// Asks first; the job record and thumbnails go, files on the output media stay.
    func deleteJob(_ id: String) {
        guard let job = store.job(id), !job.status.isActive else { return }
        confirmDeleteJobID = id
    }

    func confirmDelete() {
        guard let id = confirmDeleteJobID, let job = store.job(id), !job.status.isActive else { confirmDeleteJobID = nil; return }
        confirmDeleteJobID = nil
        store.delete(id)
        if selectedJobID == id { selectedJobID = store.jobs.first?.id }
    }

    func showCustomer(_ id: String?) {
        browsingCustomerID = id ?? order.customerID ?? store.customers.first?.id
        overlay = nil
        screen = .customerImages
    }
}
