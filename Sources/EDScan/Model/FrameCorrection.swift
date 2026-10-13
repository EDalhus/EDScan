import Foundation

/// Frontier "Tone Adjustment" presets.
enum ToneAdjustment: String, Codable, CaseIterable, Identifiable {
    case standard, allSoft, allHard, shadowSoft, shadowHard, highlightSoft, highlightHard
    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:      return "Standard"
        case .allSoft:       return "All Soft"
        case .allHard:       return "All Hard"
        case .shadowSoft:    return "Shadow Soft"
        case .shadowHard:    return "Shadow Hard"
        case .highlightSoft: return "Highlight Soft"
        case .highlightHard: return "Highlight Hard"
        }
    }

    var code: String {
        switch self {
        case .standard:      return ""
        case .allSoft:       return "AS"
        case .allHard:       return "AH"
        case .shadowSoft:    return "SS"
        case .shadowHard:    return "SH"
        case .highlightSoft: return "HS"
        case .highlightHard: return "HH"
        }
    }

    /// Tone curve points at input 0, .25, .5, .75, 1.
    var curve: [Double] {
        switch self {
        case .standard:      return [0, 0.25, 0.5, 0.75, 1]
        case .allSoft:       return [0.05, 0.29, 0.5, 0.71, 0.96]
        case .allHard:       return [0, 0.19, 0.5, 0.81, 1]
        case .shadowSoft:    return [0.04, 0.31, 0.53, 0.76, 1]
        case .shadowHard:    return [0, 0.18, 0.46, 0.74, 1]
        case .highlightSoft: return [0, 0.24, 0.48, 0.70, 0.95]
        case .highlightHard: return [0, 0.26, 0.53, 0.81, 1]
        }
    }
}

enum Sharpness: String, Codable, CaseIterable {
    case soft, normal, hard
    var title: String { rawValue.capitalized }
}

enum Monotone: String, Codable, CaseIterable {
    case no, bw, sepia
    var title: String {
        switch self {
        case .no: return "NO"
        case .bw: return "B&W"
        case .sepia: return "Sepia"
        }
    }
}

/// Per-frame corrections made on the frame check screen.
struct FrameCorrection: Codable, Equatable, Hashable {
    /// Frontier colour/density keys, −9…+9. C+ removes red, M+ removes green, Y+ removes blue, D+ darkens.
    var c = 0
    var m = 0
    var y = 0
    var d = 0
    var tone: ToneAdjustment = .standard
    var hypertone = false
    var saturation = 0          // −3…+3
    var sharpness: Sharpness = .normal
    var monotone: Monotone = .no
    var autoExposure = false    // "Exp Cond"
    var rotation = 0            // clockwise degrees
    /// Print-set quantity; 0 skips the frame in the full-resolution scan.
    var printSet = 1

    static let keyRange = -9...9

    func withPrintSet(_ n: Int) -> FrameCorrection { var c = self; c.printSet = n; return c }
    func withRotation(_ r: Int) -> FrameCorrection { var c = self; c.rotation = r; return c }
    func withTone(_ t: ToneAdjustment) -> FrameCorrection { var c = self; c.tone = t; return c }

    /// Copies the image adjustments of `other`, keeping this frame's own P.SET.
    func adopting(_ other: FrameCorrection) -> FrameCorrection {
        var c = other
        c.printSet = printSet
        return c
    }
}

extension FrameCorrection {
    init(from decoder: Decoder) throws {
        self.init()
        let k = try decoder.container(keyedBy: CodingKeys.self)
        func load<T: Decodable>(_ key: CodingKeys, _ target: inout T) {
            if let v = try? k.decode(T.self, forKey: key) { target = v }
        }
        load(.c, &c); load(.m, &m); load(.y, &y); load(.d, &d)
        load(.tone, &tone); load(.hypertone, &hypertone); load(.saturation, &saturation)
        load(.sharpness, &sharpness); load(.monotone, &monotone); load(.autoExposure, &autoExposure)
        load(.rotation, &rotation); load(.printSet, &printSet)
    }
}
