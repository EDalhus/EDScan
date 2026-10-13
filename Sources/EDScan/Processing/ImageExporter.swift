import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

/// What is written into every exported file so images can always be traced to job and customer.
struct ExportMetadata {
    var jobID: String
    var customerID: String?
    var customerName: String?
    var scanner: String
    var filmLabel: String
    var dpi: Int
    var frameNumber: Int
    var date: Date
}

enum ImageExporter {
    enum ExportError: LocalizedError {
        case encode(String)
        var errorDescription: String? {
            switch self { case .encode(let f): return "Could not write \(f)" }
        }
    }

    static func write(_ image: CGImage, to url: URL, format: FileFormat, quality: Double, meta: ExportMetadata) throws {
        let type = format == .jpeg ? UTType.jpeg : UTType.tiff
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw ExportError.encode(url.lastPathComponent)
        }
        CGImageDestinationAddImage(dest, image, properties(meta, format: format, quality: quality) as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ExportError.encode(url.lastPathComponent) }
    }

    static func writeJPEG(_ image: CGImage, to url: URL, quality: Double = 0.8) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ExportError.encode(url.lastPathComponent)
        }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ExportError.encode(url.lastPathComponent) }
    }

    private static func properties(_ m: ExportMetadata, format: FileFormat, quality: Double) -> [CFString: Any] {
        let exifDate = DateFormatter()
        exifDate.dateFormat = "yyyy:MM:dd HH:mm:ss"
        exifDate.locale = Locale(identifier: "en_US_POSIX")
        let stamp = exifDate.string(from: m.date)

        let customer = [m.customerName, m.customerID].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        var description = "Job \(m.jobID) frame \(m.frameNumber) · \(m.filmLabel)"
        if !customer.isEmpty { description = "Customer \(customer) · " + description }

        var keywords = ["ED Scan", m.jobID]
        if let id = m.customerID { keywords.append(id) }
        if let name = m.customerName, !name.isEmpty { keywords.append(name) }

        var props: [CFString: Any] = [
            kCGImagePropertyDPIWidth: m.dpi,
            kCGImagePropertyDPIHeight: m.dpi,
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFSoftware: "ED Scan",
                kCGImagePropertyTIFFMake: "Nikon",
                kCGImagePropertyTIFFModel: m.scanner,
                kCGImagePropertyTIFFImageDescription: description,
                kCGImagePropertyTIFFDateTime: stamp,
            ],
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeDigitized: stamp,
                kCGImagePropertyExifUserComment: description,
            ],
            kCGImagePropertyIPTCDictionary: [
                kCGImagePropertyIPTCObjectName: "\(m.jobID)-\(String(format: "%02d", m.frameNumber))",
                kCGImagePropertyIPTCOriginalTransmissionReference: m.jobID,
                kCGImagePropertyIPTCKeywords: keywords,
                kCGImagePropertyIPTCCaptionAbstract: description,
                kCGImagePropertyIPTCOriginatingProgram: "ED Scan",
                kCGImagePropertyIPTCSpecialInstructions: m.customerID.map { "Customer ID \($0)" } ?? "",
            ],
        ]
        if format == .jpeg { props[kCGImageDestinationLossyCompressionQuality] = quality }
        if format == .tiff {
            props[kCGImagePropertyTIFFDictionary] = (props[kCGImagePropertyTIFFDictionary] as! [CFString: Any])
                .merging([kCGImagePropertyTIFFCompression: 5]) { $1 }   // LZW
        }
        return props
    }
}

/// Contact sheet ("Index for Media"): all frames of a job on one page with frame numbers.
/// Drawn into a plain CGContext so it is safe on the background writer thread.
enum IndexSheet {
    static func make(_ images: [(Int, CGImage)], title: String) -> CGImage? {
        let cols = 6, cellW = 300, cellH = 230, margin = 40, header = 70
        let rows = max(1, (images.count + cols - 1) / cols)
        let width = margin * 2 + cols * cellW, height = margin * 2 + header + rows * cellH
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Top-left layout coordinates → CGContext's bottom-left origin.
        func flip(_ y: CGFloat, _ h: CGFloat) -> CGFloat { CGFloat(height) - y - h }

        let gc = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gc
        defer { NSGraphicsContext.restoreGraphicsState() }

        let titleFont = NSFont(name: "Arial Bold", size: 28) ?? .boldSystemFont(ofSize: 28)
        title.draw(at: NSPoint(x: CGFloat(margin), y: flip(CGFloat(margin), 32)), withAttributes: [.font: titleFont])
        let numFont = NSFont(name: "Arial", size: 18) ?? .systemFont(ofSize: 18)

        for (i, (frame, cg)) in images.enumerated() {
            let x = CGFloat(margin + (i % cols) * cellW), y = CGFloat(margin + header + (i / cols) * cellH)
            let box = CGRect(x: x + 10, y: y, width: CGFloat(cellW - 20), height: CGFloat(cellH - 40))
            let scale = min(box.width / CGFloat(cg.width), box.height / CGFloat(cg.height))
            let w = CGFloat(cg.width) * scale, h = CGFloat(cg.height) * scale
            let top = box.midY - h / 2
            ctx.draw(cg, in: CGRect(x: box.midX - w / 2, y: flip(top, h), width: w, height: h))
            "\(frame + 1)".draw(at: NSPoint(x: box.minX, y: flip(box.maxY + 6, 20)), withAttributes: [.font: numFont])
        }
        return ctx.makeImage()
    }
}

/// Burns a folder to CD/DVD with the system `drutil` tool.
enum DiscBurner {
    static func hasDrive() async -> Bool {
        let out = (try? await run(["list"])) ?? ""
        return out.split(separator: "\n").count > 1
    }

    enum BurnError: Error { case cancelled }

    private static let lock = NSLock()
    private static var burning: Process?

    /// Waits for blank media if none is inserted; `cancel()` stops it.
    static func burn(folder: URL) async throws {
        _ = try await run(["burn", "-noverify", "-eject", folder.path], track: true)
    }

    static func cancel() {
        lock.withLock { burning?.terminate() }
    }

    private static func setBurning(_ p: Process?) {
        lock.withLock { burning = p }
    }

    private static func run(_ args: [String], track: Bool = false) async throws -> String {
        try await Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/drutil")
            p.arguments = args
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            try p.run()
            if track { setBurning(p) }
            defer { if track { setBurning(nil) } }
            // Drain the pipe until drutil exits so a chatty burn can't block on a full buffer.
            let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            p.waitUntilExit()
            if p.terminationReason == .uncaughtSignal { throw BurnError.cancelled }
            guard p.terminationStatus == 0 else {
                throw NSError(domain: "drutil", code: Int(p.terminationStatus),
                              userInfo: [NSLocalizedDescriptionKey: text.trimmingCharacters(in: .whitespacesAndNewlines)])
            }
            return text
        }.value
    }
}
