import Foundation
import CoreImage
import AppKit

/// Applies Frontier-style per-frame corrections (C/M/Y/D keys, tone, hypertone…) with Core Image.
/// Thread-safe: used on the main thread for thumbnails and off-main for full-resolution output.
enum FrameRenderer {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])
    /// One C/M/Y/D key step, in EV.
    static let keyStep = 0.06

    static func cgImage(_ image: NSImage) -> CGImage? {
        var rect = NSRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    /// Downscales to at most `maxPixel` on the long edge (no correction).
    static func downscale(_ cg: CGImage, maxPixel: CGFloat) -> CGImage {
        let long = CGFloat(max(cg.width, cg.height))
        guard long > maxPixel else { return cg }
        let s = maxPixel / long
        let ci = CIImage(cgImage: cg).transformed(by: CGAffineTransform(scaleX: s, y: s))
        return context.createCGImage(ci, from: pixelRect(ci.extent)) ?? cg
    }

    /// Whole pixels inside `extent` — rounding outwards would add a transparent/black edge.
    private static func pixelRect(_ extent: CGRect) -> CGRect {
        CGRect(x: extent.minX.rounded(.up), y: extent.minY.rounded(.up),
               width: max(1, (extent.maxX.rounded(.down) - extent.minX.rounded(.up))),
               height: max(1, (extent.maxY.rounded(.down) - extent.minY.rounded(.up))))
    }

    /// Full-resolution output: opaque RGB (no alpha channel in the file), 16 bit per channel when `deep`.
    static func renderForExport(_ cg: CGImage, _ c: FrameCorrection, deep: Bool) -> CGImage? {
        let img = apply(c, to: CIImage(cgImage: cg))
        let rect = pixelRect(img.extent)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let rendered = context.createCGImage(img, from: rect, format: deep ? .RGBA16 : .RGBA8, colorSpace: space) else { return nil }
        let bpc = deep ? 16 : 8
        let info = CGImageAlphaInfo.noneSkipLast.rawValue | (deep ? CGBitmapInfo.byteOrder16Little.rawValue : 0)
        guard let ctx = CGContext(data: nil, width: rendered.width, height: rendered.height, bitsPerComponent: bpc,
                                  bytesPerRow: 0, space: space, bitmapInfo: info) else { return nil }
        ctx.draw(rendered, in: CGRect(x: 0, y: 0, width: rendered.width, height: rendered.height))
        return ctx.makeImage()
    }

    static func render(_ cg: CGImage, _ c: FrameCorrection, maxPixel: CGFloat? = nil) -> CGImage? {
        var img = CIImage(cgImage: cg)
        if let maxPixel {
            let long = CGFloat(max(cg.width, cg.height))
            if long > maxPixel {
                let s = maxPixel / long
                img = img.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: s, kCIInputAspectRatioKey: 1])
            }
        }
        img = apply(c, to: img)
        return context.createCGImage(img, from: pixelRect(img.extent))
    }

    static func renderImage(_ cg: CGImage, _ c: FrameCorrection, maxPixel: CGFloat? = nil) -> NSImage? {
        guard let out = render(cg, c, maxPixel: maxPixel) else { return nil }
        return NSImage(cgImage: out, size: NSSize(width: out.width, height: out.height))
    }

    static func apply(_ c: FrameCorrection, to input: CIImage) -> CIImage {
        var img = input
        let extent = img.extent

        // Exp Cond: automatic exposure/colour (Core Image enhance).
        if c.autoExposure {
            for f in img.autoAdjustmentFilters(options: [.redEye: false]) {
                f.setValue(img, forKey: kCIInputImageKey)
                img = f.outputImage ?? img
            }
        }

        // C/M/Y/D keys: subtractive keys act on the complementary RGB channel.
        if c.c != 0 || c.m != 0 || c.y != 0 || c.d != 0 {
            func gain(_ key: Int) -> CGFloat { CGFloat(pow(2, -Double(key + c.d) * keyStep)) }
            img = img.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: gain(c.c), y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: gain(c.m), z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: gain(c.y), w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            ])
        }

        // Tone adjustment curve.
        if c.tone != .standard {
            let p = c.tone.curve
            img = img.applyingFilter("CIToneCurve", parameters: [
                "inputPoint0": CIVector(x: 0, y: p[0]),
                "inputPoint1": CIVector(x: 0.25, y: p[1]),
                "inputPoint2": CIVector(x: 0.5, y: p[2]),
                "inputPoint3": CIVector(x: 0.75, y: p[3]),
                "inputPoint4": CIVector(x: 1, y: p[4]),
            ])
        }

        // Hypertone: compress the dynamic range locally (open shadows, hold highlights).
        if c.hypertone {
            img = img.applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputShadowAmount": 0.45,
                "inputHighlightAmount": 0.7,
                "inputRadius": max(extent.width, extent.height) / 60,
            ])
        }

        if c.saturation != 0 {
            img = img.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1 + Double(c.saturation) * 0.15])
        }

        switch c.monotone {
        case .no: break
        case .bw: img = img.applyingFilter("CIPhotoEffectMono")
        case .sepia: img = img.applyingFilter("CIPhotoEffectMono").applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.75])
        }

        switch c.sharpness {
        case .normal: break
        case .hard: img = img.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: 0.6])
        case .soft: img = img.applyingFilter("CINoiseReduction", parameters: ["inputNoiseLevel": 0.03, kCIInputSharpnessKey: 0.0])
        }

        img = img.cropped(to: extent)

        switch ((c.rotation % 360) + 360) % 360 {
        case 90:  img = img.oriented(.right)
        case 180: img = img.oriented(.down)
        case 270: img = img.oriented(.left)
        default:  break
        }
        return img.transformed(by: CGAffineTransform(translationX: -img.extent.minX, y: -img.extent.minY))
    }
}
