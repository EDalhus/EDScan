import SwiftUI
import CoolscanKit

// MARK: - Header

struct HeaderBar: View {
    @EnvironmentObject var station: Station
    @EnvironmentObject var scanner: ScannerManager

    private var title: String {
        switch station.screen {
        case .orderEntry: return "Digital Image Export-Order Information"
        case .frameCheck, .enlarged: return "Digital Image Export"
        case .customerImages: return "Customer Images"
        case .jobList: return ""
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            if station.screen == .jobList || station.screen == .customerImages {
                HStack(spacing: 8) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 20, weight: .bold))
                    Text("ED SCAN")
                        .font(FX.font(24, .heavy))
                        .tracking(2)
                    if station.screen == .customerImages {
                        Text(title).font(FX.font(14)).padding(.leading, 12)
                    }
                }
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.35), radius: 0, x: 1, y: 1)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(FX.font(13)).foregroundColor(.black)
                    HStack(spacing: 6) {
                        HStack(spacing: 14) {
                            Image(systemName: "square.and.pencil").font(.system(size: 12))
                            Text(station.headerJobNumber).font(FX.font(13))
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .frame(width: 230, height: 20)
                        .background(Capsule().fill(FX.tealDark))
                        .foregroundColor(.white)
                        Text(station.currentCustomer?.label ?? "")
                            .font(FX.font(12))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .frame(width: 200, height: 20, alignment: .leading)
                            .background(Capsule().fill(FX.tealDark))
                            .foregroundColor(.white)
                        Text("Customer").font(FX.font(12)).foregroundColor(.black)
                    }
                }
            }
            Spacer()
            HeaderIconButton(symbol: "opticaldisc", tint: FX.tealDark, help: "Output folder (Process 2)") {
                let path = station.order.outputMedia == .disc ? station.store.root.appendingPathComponent("Disc Staging").path : station.order.outputFolder
                if !path.isEmpty {
                    try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                }
            }
            Spacer().frame(width: 24)
            HeaderIconButton(symbol: "paperplane.fill", help: "Run: preview a new film with the Order Entry settings") {
                station.newOrder(); Task { await station.start() }
            }
            HeaderIconButton(symbol: "arrow.left.arrow.right", help: "Switch between Main Menu and the order") {
                if station.screen == .jobList { station.screen = station.frames.isEmpty ? .orderEntry : .frameCheck }
                else { station.mainMenu() }
            }
            HeaderIconButton(symbol: "questionmark", help: "Keys and help") { station.overlay = station.overlay == .help ? nil : .help }
            Spacer().frame(width: 10)
            HeaderIconButton(symbol: "exclamationmark", tint: scanner.lastError == nil ? Color(hex: 0xB04040) : FX.alert,
                             help: scanner.lastError ?? "No errors") {
                station.alert = scanner.lastError ?? "No errors.\n\n" + scanner.log.suffix(8).map(\.message).joined(separator: "\n")
            }
        }
        .padding(.leading, 80)       // window buttons
        .padding(.trailing, 12)
        .frame(height: 46)
        .background(FX.headerGradient)
        .overlay(alignment: .bottom) { Rectangle().fill(FX.tealDeep).frame(height: 2) }
    }
}

// MARK: - Function keys

struct FKey {
    var label: String
    var enabled = true
    var action: () -> Void = {}
    static let empty = FKey(label: "", enabled: false)
}

struct FunctionBar: View {
    @EnvironmentObject var station: Station
    @EnvironmentObject var scanner: ScannerManager

    var body: some View {
        let keys = station.functionKeys()
        HStack(spacing: 10) {
            VStack(spacing: 0) {
                row(1, Array(keys[0..<3]), offset: 0)
                row(2, Array(keys[3..<6]), offset: 3)
            }
            .frame(width: 405)
            .bevel(false, 1)
            Spacer(minLength: 10)
            pills
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .frame(height: 40)
        .background(FX.work)
    }

    private func row(_ n: Int, _ keys: [FKey], offset: Int) -> some View {
        HStack(spacing: 0) {
            Text("\(n)").font(FX.font(11)).frame(width: 16, height: 17).background(FX.fieldLight).bevel(false, 1)
            ForEach(0..<3, id: \.self) { i in
                Button(action: keys[i].action) {
                    HStack(spacing: 8) {
                        Text("F\(offset + i + 1)").font(FX.font(11))
                        Text(keys[i].label).font(FX.font(12))
                        Spacer(minLength: 0)
                    }
                    .foregroundColor(keys[i].enabled ? .black : FX.dim)
                    .padding(.leading, 4)
                    .frame(maxWidth: .infinity, minHeight: 17, maxHeight: 17)
                    .background(FX.panel)
                    .bevel(true, 1)
                }
                .buttonStyle(PressStyle())
                .disabled(!keys[i].enabled)
            }
        }
    }

    @ViewBuilder private var pills: some View {
        let busy = scanner.isBusy
        switch station.screen {
        case .orderEntry:
            HStack(spacing: 2) {
                PillButton(title: "Order Finish", enabled: !busy) { station.orderFinish() }.frame(width: 120)
                Spacer().frame(width: 100)
                PillButton(title: "START", kind: .green, enabled: !busy) { Task { await station.start() } }.frame(width: 220)
            }
        case .frameCheck, .enlarged:
            HStack(spacing: 2) {
                PillButton(title: "Order Finish", enabled: !busy) { station.orderFinish() }.frame(width: 120)
                PillButton(title: "All", kind: .green, enabled: !station.frames.isEmpty) { station.applySelectedToAll() }.frame(width: 110)
                PillButton(title: "START", kind: .green, enabled: !busy && !station.frames.isEmpty) { Task { await station.scanFrames() } }.frame(width: 110)
            }
        case .jobList:
            HStack(spacing: 2) {
                PillButton(title: "New Order", enabled: !busy) { station.newOrder() }.frame(width: 140)
                PillButton(title: "Run", kind: .green, enabled: !busy) { station.newOrder(); Task { await station.start() } }.frame(width: 140)
            }
        case .customerImages:
            HStack(spacing: 2) {
                PillButton(title: "Main Menu") { station.mainMenu() }.frame(width: 140)
                PillButton(title: "New Order", kind: .green, enabled: !busy) { station.newOrder() }.frame(width: 140)
            }
        }
    }
}

// MARK: - Status bar

struct StatusBar: View {
    @EnvironmentObject var station: Station
    @EnvironmentObject var scanner: ScannerManager
    @State private var pickScanner = false

    var body: some View {
        let o = station.order
        HStack(spacing: 6) {
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(scanner.lastError == nil ? Color(hex: 0xBBBBBB) : .yellow)
                Button { station.overlay = .help } label: {
                    Image(systemName: "info.square.fill").foregroundColor(FX.tealLight)
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 14))
            .frame(width: 34)
            .frame(maxHeight: .infinity)
            .background(Color.black.opacity(0.25))

            Button { pickScanner.toggle() } label: {
                VStack(spacing: 2) {
                    Image(systemName: "desktopcomputer").font(.system(size: 20))
                    Text(scanner.connectedScanner?.name ?? "No scanner")
                        .font(FX.font(9)).lineLimit(1)
                }
                .foregroundColor(.white)
                .frame(width: 100)
            }
            .buttonStyle(PressStyle())
            .help("Choose scanner")
            .popover(isPresented: $pickScanner) { ScannerPicker(done: { pickScanner = false }) }

            progress.frame(maxWidth: .infinity)

            StatusBox(width: 84) {
                HStack(spacing: 4) {
                    Image(systemName: "photo").foregroundColor(FX.tealLight)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(o.imageSize.code)
                        Text(String(o.imageSize.dpi(for: station.scannerModel)) + " dpi")
                    }
                }
            }
            StatusBox(width: 84) {
                HStack(spacing: 4) {
                    Image(systemName: o.outputMedia.symbol).foregroundColor(Color(hex: 0xE8D27A))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(o.fileFormat.title)
                        Text(o.outputMedia == .disc ? "CD x\(o.discCopies)" : o.outputMedia.code)
                    }
                }
            }
            StatusBox(width: 30) { Text(o.filmKind.code).font(FX.font(14)) }
            StatusBox(width: 84) {
                HStack(spacing: 4) {
                    Image(systemName: "film").foregroundColor(Color(hex: 0xE06040))
                    Text(station.frames.isEmpty ? "135 Auto" : "135 x\(station.frames.count)")
                }
            }
            Button { station.order.mode = o.mode == .semi ? .auto : .semi } label: {
                VStack(spacing: 2) {
                    Text(o.mode.title).font(FX.font(12)).frame(maxWidth: .infinity).background(Color(hex: 0x555555))
                    Text(String(format: "%02d", station.frames.count)).font(FX.font(12))
                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(FX.statusBox).bevel(false, 1)
                }
                .foregroundColor(.white)
                .frame(width: 52, height: 40)
            }
            .buttonStyle(PressStyle())
            .help("Semi: stop at frame check after preview. Auto: scan straight after preview.")

            squareButton("eject.fill", help: "Eject film", enabled: !scanner.isBusy && scanner.connectedScanner != nil) { scanner.eject(); station.orderFinish() }
            squareButton("person.crop.square.filled.and.at.rectangle", help: "Customer images") { station.showCustomer(nil) }

            Button { station.mainMenu() } label: {
                VStack(spacing: 1) {
                    Text("MAIN\nMENU").font(FX.font(8, .bold)).multilineTextAlignment(.center)
                    Image(systemName: "arrow.uturn.backward").font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(width: 40, height: 48)
                .background(LinearGradient(colors: [FX.teal, FX.tealDark], startPoint: .top, endPoint: .bottom))
                .bevel(true, 1)
            }
            .buttonStyle(PressStyle())
            .opacity(station.screen == .jobList ? 0.5 : 1)
        }
        .padding(.trailing, 8)
        .frame(height: 60)
        .background(FX.statusGradient)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(station.notice ?? scanner.statusMessage)
                .font(FX.font(11))
                .foregroundColor(.white)
                .lineLimit(2)
            if scanner.isBusy {
                HStack(spacing: 6) {
                    ProgressView(value: scanner.scanProgress).tint(FX.tealLight)
                    Button { scanner.cancelCurrentOperation() } label: {
                        Image(systemName: "stop.fill").foregroundColor(.white).frame(width: 22, height: 18)
                            .background(FX.statusBox).bevel(true, 1)
                    }
                    .buttonStyle(PressStyle())
                    .help("Stop")
                }
            }
        }
        .padding(.horizontal, 6)
        .onChange(of: scanner.statusMessage) { _ in station.notice = nil }
    }

    private func squareButton(_ symbol: String, help: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundColor(enabled ? .white : .gray)
                .frame(width: 36, height: 40)
                .background(Color(hex: 0x4A4A4A))
                .bevel(true, 1)
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
        .help(help)
    }
}

struct StatusBox<Content: View>: View {
    var width: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .font(FX.font(11))
            .foregroundColor(.white)
            .frame(width: width, height: 40)
            .background(FX.statusBox)
            .bevel(false, 1)
            .padding(3)
            .background(Color(hex: 0x4A4A4A))
    }
}

struct ScannerPicker: View {
    @EnvironmentObject var station: Station
    @EnvironmentObject var scanner: ScannerManager
    var done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionBar(title: "Scanner")
            ForEach(scanner.availableScanners) { d in
                Button { station.connect(d); done() } label: {
                    HStack {
                        Image(systemName: d.model == .simulated ? "cpu" : "scanner")
                        Text(d.name).font(FX.font(13))
                        Spacer()
                        if scanner.connectedScanner == d { Image(systemName: "checkmark") }
                    }
                    .foregroundColor(.black)
                    .padding(8)
                    .frame(width: 260)
                    .background(scanner.connectedScanner == d ? FX.selectYellow : FX.card)
                    .bevel(true, 1)
                }
                .buttonStyle(PressStyle())
                .disabled(scanner.isBusy)
            }
        }
        .padding(10)
        .background(FX.work)
    }
}
