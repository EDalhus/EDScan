import SwiftUI

/// Look & feel modelled on the Fujifilm Frontier "Digital Image Export" station:
/// teal chrome, Windows-classic grey panels with bevelled edges, Arial type.
enum FX {
    static let tealLight   = Color(hex: 0x7FCFCF)
    static let teal        = Color(hex: 0x3AA3A5)
    static let tealMid     = Color(hex: 0x2E8A8E)
    static let tealDark    = Color(hex: 0x226C71)
    static let tealDeep    = Color(hex: 0x17535A)
    static let tealSelect  = Color(hex: 0x2FA3A6)

    static let work        = Color(hex: 0xC4C4C4)   // screen background
    static let panel       = Color(hex: 0xD2D2D2)   // inner panels
    static let card        = Color(hex: 0xDCDCDC)
    static let cardTop     = Color(hex: 0xE9E9E9)
    static let field       = Color(hex: 0xB8B8B8)
    static let fieldLight  = Color(hex: 0xF4F4F4)
    static let frameCell   = Color(hex: 0xC9C9C9)
    static let frameCellOn = Color(hex: 0x8D8D8D)
    static let darkStage   = Color(hex: 0x7E7E7E)

    static let selectYellow = Color(hex: 0xFFFF9E)
    static let greenTop    = Color(hex: 0x4FE0A2)
    static let green       = Color(hex: 0x1FA86C)
    static let selGreen    = Color(hex: 0x45C24A)

    static let statusTop   = Color(hex: 0x5B5B5B)
    static let statusBottom = Color(hex: 0x323232)
    static let statusBox   = Color(hex: 0x2A2A2A)

    static let classicFace = Color(hex: 0xD4D0C8)
    static let classicTitleA = Color(hex: 0x0A246A)
    static let classicTitleB = Color(hex: 0xA6CAF0)

    static let dim         = Color(hex: 0x8C8C8C)
    static let shadow      = Color(hex: 0x5C5C5C)
    static let alert       = Color(hex: 0xE02020)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Arial", size: size).weight(weight)
    }

    static let headerGradient = LinearGradient(
        colors: [Color(hex: 0x9ADADA), Color(hex: 0x3FA7A9), Color(hex: 0x2B8C90)],
        startPoint: .top, endPoint: .bottom)
    static let buttonGradient = LinearGradient(
        colors: [Color(hex: 0xF2F2F2), Color(hex: 0xCFCFCF)], startPoint: .top, endPoint: .bottom)
    static let statusGradient = LinearGradient(
        colors: [statusTop, statusBottom], startPoint: .top, endPoint: .bottom)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - Bevel

/// Windows-classic 3D edge: light top/left, dark bottom/right (or inverted when sunken).
struct Bevel: View {
    var raised = true
    var width: CGFloat = 2

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height, i = width / 2
            Path { p in
                p.move(to: CGPoint(x: i, y: h - i)); p.addLine(to: CGPoint(x: i, y: i)); p.addLine(to: CGPoint(x: w - i, y: i))
            }
            .stroke(raised ? Color.white : FX.shadow, lineWidth: width)
            Path { p in
                p.move(to: CGPoint(x: w - i, y: i)); p.addLine(to: CGPoint(x: w - i, y: h - i)); p.addLine(to: CGPoint(x: i, y: h - i))
            }
            .stroke(raised ? FX.shadow : Color.white, lineWidth: width)
        }
        .allowsHitTesting(false)
    }
}

extension View {
    func bevel(_ raised: Bool = true, _ width: CGFloat = 2) -> some View {
        overlay(Bevel(raised: raised, width: width))
    }
}

/// Pressed state darkens and sinks the control slightly.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? -0.08 : 0)
            .offset(y: configuration.isPressed ? 1 : 0)
            .contentShape(Rectangle())
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath()
        }
    }
}

// MARK: - Building blocks

/// Field inset (sunken box) with text, like the frame number / C M Y D boxes.
struct FieldBox: View {
    var text: String
    var width: CGFloat? = nil
    var light = true
    var align: Alignment = .leading
    var size: CGFloat = 12

    var body: some View {
        Text(text)
            .font(FX.font(size))
            .foregroundColor(.black)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .frame(width: width, height: 18, alignment: align)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: align)
            .background(light ? FX.fieldLight : FX.field)
            .bevel(false, 1)
    }
}

/// Classic grey push button (Close, OK, Hold, Cancel, Refresh…).
struct ClassicButton: View {
    var title: String
    var width: CGFloat = 96
    var enabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FX.font(13))
                .foregroundColor(enabled ? .black : FX.dim)
                .frame(width: width, height: 28)
                .background(FX.classicFace)
                .bevel(true, 2)
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
    }
}

/// Large Frontier card button: value strip on top, pictogram, ▸ marker, caption underneath.
struct CardButton<Icon: View>: View {
    var value: String
    var caption: String
    var width: CGFloat = 138
    var enabled = true
    var highlighted = false
    var action: () -> Void
    @ViewBuilder var icon: () -> Icon

    var body: some View {
        VStack(spacing: 4) {
            Button(action: action) {
                VStack(spacing: 4) {
                    Text(value)
                        .font(FX.font(13))
                        .foregroundColor(enabled ? .black : FX.dim)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(highlighted ? FX.selectYellow : FX.cardTop)
                        .bevel(false, 1)
                    icon()
                        .frame(height: 38)
                        .opacity(enabled ? 1 : 0.35)
                    Spacer(minLength: 0)
                }
                .padding(6)
                .frame(width: width, height: 80)
                .background(FX.buttonGradient)
                .bevel(true, 2)
                .overlay(alignment: .bottomTrailing) {
                    Triangle().fill(enabled ? Color.black : FX.dim).frame(width: 5, height: 8).padding(5)
                }
            }
            .buttonStyle(PressStyle())
            .disabled(!enabled)
            Text(caption)
                .font(FX.font(12))
                .foregroundColor(enabled ? .black : FX.dim)
        }
    }
}

/// Teal section heading bar ("Printing Information", "Digitize Information").
struct SectionBar: View {
    var title: String
    var boxed = false

    var body: some View {
        Text(title)
            .font(FX.font(13))
            .foregroundColor(boxed ? FX.tealDeep : .black)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
            .background(boxed ? FX.fieldLight : FX.teal)
            .overlay(Rectangle().stroke(boxed ? FX.teal : Color.clear, lineWidth: 2))
    }
}

/// Capsule button used for START / Order Finish / All.
struct PillButton: View {
    enum Kind { case green, grey }
    var title: String
    var kind: Kind = .grey
    var enabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FX.font(14))
                .foregroundColor(enabled ? .black : FX.dim)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Capsule().fill(LinearGradient(
                        colors: kind == .green && enabled
                            ? [FX.greenTop, FX.green]
                            : [Color(hex: 0xEDEDED), Color(hex: 0xB9B9B9)],
                        startPoint: .top, endPoint: .bottom))
                )
                .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
    }
}

/// Windows-classic dialog frame with gradient title bar (Image Correct).
struct ClassicDialog<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(FX.font(13, .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                .background(LinearGradient(colors: [FX.classicTitleA, FX.classicTitleB], startPoint: .leading, endPoint: .trailing))
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(FX.classicFace)
        .bevel(true, 2)
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }
}

/// Round teal icon button of the header bar.
struct HeaderIconButton: View {
    var symbol: String
    var tint: Color = FX.tealMid
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .top, endPoint: .bottom)))
                .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1.5))
        }
        .buttonStyle(PressStyle())
        .help(help)
    }
}

/// Pictogram tile: a coloured square with an SF Symbol, standing in for Frontier's bitmaps.
struct Pictogram: View {
    var symbol: String
    var colors: [Color]
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: size * 1.3, height: size)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .bevel(true, 1)
    }
}

struct FilmStripIcon: View {
    var body: some View { Pictogram(symbol: "film", colors: [Color(hex: 0xD04A2A), Color(hex: 0x7A1C10)]) }
}
