import SwiftUI
import CoolscanKit

private func keyText(_ v: Int) -> String { v == 0 ? "" : (v > 0 ? "+\(v)" : "\(v)") }

// MARK: - Frame grid

struct FrameCheckView: View {
    @EnvironmentObject var station: Station
    @EnvironmentObject var scanner: ScannerManager

    var body: some View {
        GeometryReader { g in
            let cellHeight = max(220, (g.size.height - 8) / 2)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3), spacing: 0) {
                        ForEach(station.frames, id: \.self) { f in
                            FrameCell(frame: f, height: cellHeight).id(f)
                        }
                    }
                    .padding(4)
                }
                .onChange(of: station.selectedFrame) { f in withAnimation { proxy.scrollTo(f) } }
            }
            .overlay {
                if station.frames.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "film").font(.system(size: 40))
                        Text(scanner.isBusy ? scanner.statusMessage : "No frames — press START on Order Entry to preview the film")
                            .font(FX.font(14))
                        if scanner.isBusy { ProgressView(value: scanner.scanProgress).frame(width: 260) }
                    }
                    .foregroundColor(Color(hex: 0x505050))
                }
            }
        }
        .background(FX.work)
    }
}

private struct FrameCell: View {
    @EnvironmentObject var station: Station
    @EnvironmentObject var scanner: ScannerManager
    let frame: Int
    let height: CGFloat

    var body: some View {
        let c = station.correction(frame)
        let selected = station.selectedFrame == frame
        VStack(spacing: 4) {
            Image(systemName: "arrowtriangle.up.fill").font(.system(size: 7)).foregroundColor(.black)
            ZStack {
                if let img = station.thumbs[frame] {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .border(Color.white, width: 2)
                }
                if c.printSet == 0 {
                    Image(systemName: "xmark").font(.system(size: 60, weight: .ultraLight)).foregroundColor(.red.opacity(0.8))
                }
                if scanner.currentScanFrame == frame && scanner.isBusy {
                    ProgressView(value: scanner.currentFrameProgress).frame(width: 120).padding(6).background(.black.opacity(0.5))
                }
            }
            .opacity(c.printSet == 0 ? 0.45 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    FieldBox(text: "\(frame + 1)", width: 60, light: false)
                    FieldBox(text: c.tone.code + (c.hypertone ? "H" : ""), width: 30, light: false)
                    Spacer()
                    FieldBox(text: station.order.imageSize.code + (c.rotation != 0 ? " \(c.rotation)°" : ""), width: 62, align: .trailing)
                }
                HStack(spacing: 3) {
                    ForEach([("C", c.c), ("M", c.m), ("Y", c.y), ("D", c.d)], id: \.0) { k in
                        Text(k.0).font(FX.font(12))
                        FieldBox(text: keyText(k.1), width: 26, align: .trailing)
                    }
                    Spacer(minLength: 2)
                    Text("P.SET").font(FX.font(11))
                    FieldBox(text: "\(c.printSet)", width: 28, align: .trailing)
                }
            }
            .padding(6)
            .background(FX.panel)
            .bevel(true, 1)
        }
        .padding(8)
        .frame(height: height)
        .background(selected ? FX.frameCellOn : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { station.selectedFrame = frame; station.screen = .enlarged }
        .onTapGesture { station.selectedFrame = frame }
        .contextMenu {
            Button("Image Correct…") { station.selectedFrame = frame; station.overlay = .imageCorrect }
            Button("Tone Adjustment…") { station.selectedFrame = frame; station.openToneAdjust() }
            Button("Rotate 90°") { station.selectedFrame = frame; station.rotateSelected() }
            Button(c.printSet > 0 ? "Skip frame (P.SET 0)" : "Include frame (P.SET 1)") { station.selectedFrame = frame; station.togglePrintSet() }
            Button("Reset corrections") { station.selectedFrame = frame; station.resetSelected() }
        }
    }
}

// MARK: - Enlarged frame

struct EnlargedFrameView: View {
    @EnvironmentObject var station: Station

    var body: some View {
        let f = station.selectedFrame
        let c = station.correction(f)
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("<Enlarged Frame>").font(FX.font(13))
                Text("Frame \(f + 1) of \(station.frames.count)").font(FX.font(12)).foregroundColor(Color(hex: 0x505050))
                HStack {
                    ClassicButton(title: "◀", width: 40, enabled: station.frames.first != f) { station.moveSelection(-1) }
                    ClassicButton(title: "▶", width: 40, enabled: station.frames.last != f) { station.moveSelection(1) }
                }
                Spacer()
            }
            .padding(.top, 30)
            .frame(width: 150)

            ZStack {
                FX.darkStage
                if let img = station.thumbs[f] {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .border(Color.white, width: 2)
                        .padding(36)
                }
            }
            .padding(14)
            .background(Color(hex: 0x9A9A9A))
            .bevel(false, 2)
            .onTapGesture(count: 2) { station.screen = .frameCheck }

            VStack {
                Spacer()
                CMYDPanel(frame: f, correction: c)
            }
            .frame(width: 200)
        }
        .padding(.vertical, 6)
        .background(FX.work)
    }
}

private struct CMYDPanel: View {
    @EnvironmentObject var station: Station
    let frame: Int
    let correction: FrameCorrection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 2) {
                FieldBox(text: "\(frame + 1)", width: 62, light: false)
                FieldBox(text: correction.tone.code, width: 30, light: false)
            }
            HStack(spacing: 4) {
                Spacer()
                Text("Size").font(FX.font(12))
                FieldBox(text: station.order.imageSize.code, width: 46, align: .trailing)
                Text("P.SET").font(FX.font(12))
                FieldBox(text: "\(correction.printSet)", width: 30, align: .trailing)
            }
            HStack(spacing: 6) {
                key("C", \.c, Color(hex: 0x00B4E6))
                key("M", \.m, Color(hex: 0xE6007E))
                key("Y", \.y, Color(hex: 0xF5E600))
                key("D", \.d, .black)
            }
        }
        .padding(8)
        .background(FX.panel)
        .bevel(true, 2)
    }

    private func key(_ name: String, _ path: WritableKeyPath<FrameCorrection, Int>, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(keyText(correction[keyPath: path]))
                .font(FX.font(13))
                .frame(width: 40, height: 26)
                .background(Color.white)
                .overlay(alignment: .bottom) { Rectangle().fill(color).frame(height: 5) }
                .bevel(false, 1)
                .help(name)
            HStack(spacing: 0) {
                arrow("arrowtriangle.down.fill") { station.adjustKey(path, -1) }
                arrow("arrowtriangle.up.fill") { station.adjustKey(path, 1) }
            }
        }
    }

    private func arrow(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 8)).foregroundColor(.black)
                .frame(width: 20, height: 16).background(FX.card).bevel(true, 1)
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - Image Correct dialog

struct ImageCorrectPanel: View {
    @EnvironmentObject var station: Station

    var body: some View {
        let c = station.correction(station.selectedFrame)
        ClassicDialog(title: "Image Correct — Frame \(station.selectedFrame + 1)") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    CorrectTile(value: c.sharpness.title, caption: "Sharpness", symbol: "triangle.lefthalf.filled",
                                colors: [Color(hex: 0x9AB0C8), Color(hex: 0x506078)],
                                options: Sharpness.allCases.map(\.title)) { i in station.modifySelected { $0.sharpness = Sharpness.allCases[i] } }
                    CorrectTile(value: keyText(c.saturation).nilIfEmpty ?? "0", caption: "Saturation", symbol: "paintpalette.fill",
                                colors: [Color(hex: 0x3CA0F0), Color(hex: 0xE04040)],
                                options: (-3...3).map { keyText($0).nilIfEmpty ?? "0" }) { i in station.modifySelected { $0.saturation = i - 3 } }
                    CorrectTile(value: c.monotone.title, caption: "Monotone Correction", symbol: "person.2.fill",
                                colors: [Color(hex: 0x909090), Color(hex: 0x8A5A3A)],
                                options: Monotone.allCases.map(\.title)) { i in station.modifySelected { $0.monotone = Monotone.allCases[i] } }
                    CorrectTile(value: c.autoExposure ? "YES" : "NO", caption: "Exp Cond", symbol: "wand.and.stars",
                                colors: [Color(hex: 0xE87070), Color(hex: 0x40A060)],
                                options: ["NO", "YES"]) { i in station.modifySelected { $0.autoExposure = i == 1 } }
                }
                HStack(alignment: .top, spacing: 8) {
                    CorrectTile(value: c.tone.title + (c.hypertone ? " +H" : ""), caption: "Tone Adjustment", symbol: "person.3.fill",
                                colors: [Color(hex: 0x50C0F0), Color(hex: 0xE070A0)], options: nil) { _ in station.openToneAdjust() }
                    CorrectTile(value: "\(c.rotation)°", caption: "Rotate", symbol: "rotate.right.fill",
                                colors: [Color(hex: 0x60B080), Color(hex: 0x2A6A50)],
                                options: ["0°", "90°", "180°", "270°"]) { i in station.modifySelected { $0.rotation = i * 90 } }
                    CorrectTile(value: "\(c.printSet)", caption: "P.SET", symbol: "square.stack.fill",
                                colors: [Color(hex: 0xC0A040), Color(hex: 0x806010)],
                                options: ["0", "1"]) { i in station.modifySelected { $0.printSet = i } }
                    Spacer()
                }
                HStack {
                    ClassicButton(title: "Reset", width: 90) { station.resetSelected() }
                    ClassicButton(title: "Apply to All", width: 110) { station.applySelectedToAll() }
                    Spacer()
                    ClassicButton(title: "Close") { station.overlay = nil }
                }
            }
            .padding(14)
        }
        .frame(width: 520, height: 280)
    }
}

/// Image Correct tile: click steps to the next value, right-click lists all values.
private struct CorrectTile: View {
    var value: String
    var caption: String
    var symbol: String
    var colors: [Color]
    var options: [String]?
    var onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 3) {
            Button {
                if let options {
                    let i = options.firstIndex(of: value) ?? -1
                    onSelect((i + 1) % options.count)
                } else {
                    onSelect(0)
                }
            } label: {
                VStack(spacing: 3) {
                    Text(value)
                        .font(FX.font(13))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 20)
                        .background(FX.cardTop)
                        .bevel(false, 1)
                    Pictogram(symbol: symbol, colors: colors, size: 30)
                }
                .padding(4)
                .frame(width: 112, height: 66)
                .background(FX.buttonGradient)
                .bevel(true, 2)
            }
            .buttonStyle(PressStyle())
            .contextMenu {
                if let options {
                    ForEach(options.indices, id: \.self) { i in Button(options[i]) { onSelect(i) } }
                }
            }
            Text(caption).font(FX.font(12))
        }
    }
}

// MARK: - Tone Adjustment

struct ToneAdjustPanel: View {
    @EnvironmentObject var station: Station
    @State private var previews: [ToneAdjustment: NSImage] = [:]

    var body: some View {
        let c = station.correction(station.selectedFrame)
        VStack(spacing: 0) {
            Text("Tone Adjustment — Frame \(station.selectedFrame + 1)")
                .font(FX.font(12, .bold))
                .foregroundColor(.white)
                .padding(.leading, 6)
                .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
                .background(Color(hex: 0x8C8C8C))
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(Array(ToneAdjustment.allCases.enumerated()), id: \.element) { i, t in
                            Button { station.modifySelected { $0.tone = t } } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        if let img = previews[t] { Image(nsImage: img).resizable().scaledToFit() }
                                    }
                                    .frame(width: 84, height: 62)
                                    .padding(5)
                                    .background(c.tone == t ? FX.selectYellow : FX.card)
                                    .bevel(true, 2)
                                    Text(t.title.replacingOccurrences(of: " ", with: "\n"))
                                        .font(FX.font(12))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.black)
                                        .fixedSize()
                                        .frame(width: 96, height: 30)
                                }
                            }
                            .buttonStyle(PressStyle())
                            .help("Key \(i + 1)")
                        }
                    }
                    HStack(spacing: 20) {
                        Text("Hypertone").font(FX.font(12))
                        radio("YES", c.hypertone) { station.modifySelected { $0.hypertone = true } }
                        radio("NO", !c.hypertone) { station.modifySelected { $0.hypertone = false } }
                    }
                    .padding(.horizontal, 10)
                    .frame(width: 330, height: 30, alignment: .leading)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(FX.dim))
                }
                .padding(6)
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    ClassicButton(title: "OK") { station.closeToneAdjust(.ok) }
                    ClassicButton(title: "Hold") { station.closeToneAdjust(.hold) }
                        .help("Apply and keep as the default for new frames")
                    ClassicButton(title: "Cancel") { station.closeToneAdjust(.cancel) }
                }
                .padding(14)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(Color(hex: 0xBDBDBD))
                .bevel(false, 1)
                .padding(6)
            }
        }
        .frame(height: 190)
        .background(FX.panel)
        .bevel(true, 2)
        .onAppear(perform: renderPreviews)
        .onChange(of: station.selectedFrame) { _ in renderPreviews() }
        .onChange(of: c.withTone(.standard)) { _ in renderPreviews() }   // anything but the tone itself
    }

    private func renderPreviews() {
        guard let src = station.source(station.selectedFrame) else { return }
        let base = station.correction(station.selectedFrame)
        var out: [ToneAdjustment: NSImage] = [:]
        for t in ToneAdjustment.allCases {
            var c = base
            c.tone = t
            out[t] = FrameRenderer.renderImage(src, c, maxPixel: 200)
        }
        previews = out
    }

    private func radio(_ title: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle").font(.system(size: 12))
                Text(title).font(FX.font(12))
            }
            .foregroundColor(.black)
        }
        .buttonStyle(.plain)
    }
}
