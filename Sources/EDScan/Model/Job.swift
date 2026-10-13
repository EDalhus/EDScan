import Foundation

enum JobKind: String, Codable {
    case preview, scan
    var title: String { self == .preview ? "Preview" : "Digitize" }
    var orderTypeName: String { self == .preview ? "Film Preview" : "Digital Image Export" }
}

enum JobStatus: String, Codable {
    case waiting, previewing, scanning, converting, waitingForDisc, burning, completed, failed, cancelled

    var title: String {
        switch self {
        case .waiting:        return "Waiting"
        case .previewing:     return "Previewing"
        case .scanning:       return "Scanning"
        case .converting:     return "Converting"
        case .waitingForDisc: return "Insert Disc"
        case .burning:        return "Burning"
        case .completed:      return "Completed"
        case .failed:         return "Error"
        case .cancelled:      return "Cancelled"
        }
    }

    var isActive: Bool { [.previewing, .scanning, .converting, .burning].contains(self) }
}

struct JobFrame: Codable, Hashable {
    var index: Int
    /// File name inside the job's thumbnail folder.
    var thumbnail: String
    /// Full-resolution output file (scan jobs only).
    var file: String?
}

struct ScanJob: Codable, Identifiable, Hashable {
    var id: String                 // "00718-01"
    var orderNumber: Int
    var kind: JobKind
    var created: Date
    var customerID: String?
    var customerName: String?
    var scanner: String
    var filmKind: FilmKind
    var filmFormat = "135"
    var imageSize: ImageSize
    var dpi: Int
    var outputMedia: OutputMedia
    var fileFormat: FileFormat
    var discCopies = 1
    var discsBurned = 0
    var outputFolder: String?
    var status: JobStatus = .waiting
    var statusDetail: String?
    var started: Date?
    var finished: Date?
    /// Time the scanner spent on the actual full-resolution scan (or the preview pass for preview jobs).
    var scanDuration: TimeInterval?
    var requestedFrames = 0
    var frames: [JobFrame] = []

    var inputLabel: String { "\(filmFormat)(\(filmKind.code))" }

    var outputLabel: String {
        switch outputMedia {
        case .disc: return "\(fileFormat.title) → CD x\(discCopies)"
        default:    return "\(fileFormat.title) → \(outputMedia.title)"
        }
    }
}

struct Customer: Codable, Identifiable, Hashable {
    var id: String          // "C-482913"
    var name: String
    var created: Date

    var label: String { name.isEmpty ? id : "\(name)  (\(id))" }
}

extension TimeInterval {
    /// "1:07" / "12:03:44"
    var clock: String {
        let s = Int(self.rounded())
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}

extension ScanJob {
    // Fields added in later versions fall back to their defaults instead of dropping the job.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        orderNumber = try c.decode(Int.self, forKey: .orderNumber)
        kind = try c.decode(JobKind.self, forKey: .kind)
        created = try c.decode(Date.self, forKey: .created)
        customerID = try c.decodeIfPresent(String.self, forKey: .customerID)
        customerName = try c.decodeIfPresent(String.self, forKey: .customerName)
        scanner = (try? c.decode(String.self, forKey: .scanner)) ?? "—"
        filmKind = (try? c.decode(FilmKind.self, forKey: .filmKind)) ?? .negative
        filmFormat = (try? c.decode(String.self, forKey: .filmFormat)) ?? "135"
        imageSize = (try? c.decode(ImageSize.self, forKey: .imageSize)) ?? .large
        dpi = (try? c.decode(Int.self, forKey: .dpi)) ?? 0
        outputMedia = (try? c.decode(OutputMedia.self, forKey: .outputMedia)) ?? .localDisk
        fileFormat = (try? c.decode(FileFormat.self, forKey: .fileFormat)) ?? .jpeg
        discCopies = (try? c.decode(Int.self, forKey: .discCopies)) ?? 1
        discsBurned = (try? c.decode(Int.self, forKey: .discsBurned)) ?? 0
        outputFolder = try? c.decodeIfPresent(String.self, forKey: .outputFolder)
        status = (try? c.decode(JobStatus.self, forKey: .status)) ?? .failed
        statusDetail = try? c.decodeIfPresent(String.self, forKey: .statusDetail)
        started = try? c.decodeIfPresent(Date.self, forKey: .started)
        finished = try? c.decodeIfPresent(Date.self, forKey: .finished)
        scanDuration = try? c.decodeIfPresent(TimeInterval.self, forKey: .scanDuration)
        requestedFrames = (try? c.decode(Int.self, forKey: .requestedFrames)) ?? 0
        frames = (try? c.decode([JobFrame].self, forKey: .frames)) ?? []
    }
}
