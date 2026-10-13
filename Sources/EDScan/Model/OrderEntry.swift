import Foundation
import CoolscanKit

enum FilmKind: String, Codable, CaseIterable, Identifiable {
    case negative, positive, bwNegative, bwPositive
    var id: String { rawValue }

    var title: String {
        switch self {
        case .negative:   return "Negative"
        case .positive:   return "Positive / Slide"
        case .bwNegative: return "B&W Negative"
        case .bwPositive: return "B&W Positive"
        }
    }

    /// Short code as shown in "135(N)" and the status bar.
    var code: String {
        switch self {
        case .negative:   return "N"
        case .positive:   return "P"
        case .bwNegative: return "BN"
        case .bwPositive: return "BP"
        }
    }

    var coolscan: FilmType {
        switch self {
        case .negative:   return .colorNegative
        case .positive:   return .colorPositive
        case .bwNegative: return .bwNegative
        case .bwPositive: return .bwPositive
        }
    }
}

/// "Image scan size" — Frontier's 35L / 35S simple setting.
enum ImageSize: String, Codable, CaseIterable, Identifiable {
    case large, small
    var id: String { rawValue }

    var code: String { self == .large ? "35L" : "35S" }
    var title: String { self == .large ? "Large" : "Small" }

    func dpi(for model: ScannerModel?) -> Int {
        let maxDPI = model?.maxOpticalResolution ?? 4000
        return self == .large ? maxDPI : min(2000, maxDPI)
    }

    /// Pixel size of a full 36×24 mm frame.
    func pixels(for model: ScannerModel?) -> (Int, Int) {
        let ppmm = Double(dpi(for: model)) / 25.4
        return (Int(36 * ppmm), Int(24 * ppmm))
    }

    func summary(for model: ScannerModel?) -> String {
        let (w, h) = pixels(for: model)
        return "\(dpi(for: model)) dpi  \(w)×\(h)"
    }
}

enum OutputMedia: String, Codable, CaseIterable, Identifiable {
    case localDisk, networkShare, disc
    var id: String { rawValue }

    var title: String {
        switch self {
        case .localDisk:    return "Local Disk"
        case .networkShare: return "Network Share"
        case .disc:         return "CD/DVD"
        }
    }

    var code: String {
        switch self {
        case .localDisk:    return "HDD"
        case .networkShare: return "NET"
        case .disc:         return "CD"
        }
    }

    var symbol: String {
        switch self {
        case .localDisk:    return "internaldrive"
        case .networkShare: return "network"
        case .disc:         return "opticaldisc"
        }
    }
}

enum FileFormat: String, Codable, CaseIterable, Identifiable {
    case jpeg, tiff
    var id: String { rawValue }
    var title: String { self == .jpeg ? "JPG" : "TIFF" }
    var fileExtension: String { self == .jpeg ? "jpg" : "tif" }
}

/// Semi: stop at frame check after preview. Auto: scan straight after preview.
enum WorkMode: String, Codable, CaseIterable {
    case semi, auto
    var title: String { self == .semi ? "Semi" : "Auto" }
}

/// Everything set in Order Entry / Process 1 / Process 2. Persisted on every change,
/// so the station always comes back exactly as it was left.
struct OrderEntry: Codable, Equatable {
    var filmKind: FilmKind = .negative
    var imageSize: ImageSize = .large
    var outputMedia: OutputMedia = .localDisk
    var fileFormat: FileFormat = .jpeg
    var jpegQuality: Double = 0.92
    var discCopies: Int = 1
    var indexSheet = false
    var localFolder: String = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures/ED Scan").path
    var networkFolder: String = ""
    var customerID: String?

    // Process 1 (scanner)
    var digitalICE: String = DigitalICE.normal.rawValue
    var multiScan = false
    var highBitDepth = false
    var previewAllFrames = true

    // Workflow
    var mode: WorkMode = .semi
    var finishAfterScan = true
    var scannerName: String?

    /// Correction new frames start with ("Hold" in Tone Adjustment updates it).
    var defaultCorrection = FrameCorrection()

    var ice: DigitalICE { DigitalICE(rawValue: digitalICE) ?? .normal }

    var outputFolder: String {
        outputMedia == .networkShare ? networkFolder : localFolder
    }

    private static let key = "EDScan.OrderEntry"

    static func load() -> OrderEntry {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entry = try? JSONDecoder().decode(OrderEntry.self, from: data) else { return OrderEntry() }
        return entry
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

extension OrderEntry {
    // Tolerant decoding: settings added in later versions fall back to defaults instead of resetting everything.
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func load<T: Decodable>(_ key: CodingKeys, _ target: inout T) {
            if let v = try? c.decode(T.self, forKey: key) { target = v }
        }
        load(.filmKind, &filmKind); load(.imageSize, &imageSize); load(.outputMedia, &outputMedia)
        load(.fileFormat, &fileFormat); load(.jpegQuality, &jpegQuality); load(.discCopies, &discCopies)
        load(.indexSheet, &indexSheet); load(.localFolder, &localFolder); load(.networkFolder, &networkFolder)
        customerID = try? c.decodeIfPresent(String.self, forKey: .customerID)
        load(.digitalICE, &digitalICE); load(.multiScan, &multiScan); load(.highBitDepth, &highBitDepth)
        load(.previewAllFrames, &previewAllFrames); load(.mode, &mode); load(.finishAfterScan, &finishAfterScan)
        scannerName = try? c.decodeIfPresent(String.self, forKey: .scannerName)
        load(.defaultCorrection, &defaultCorrection)
    }
}
