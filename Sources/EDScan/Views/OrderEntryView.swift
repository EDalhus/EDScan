import SwiftUI
import CoolscanKit

struct OrderEntryView: View {
    @EnvironmentObject var station: Station

    var body: some View {
        HStack(spacing: 0) {
            ServiceMenu().frame(width: 210)
            VStack(spacing: 0) {
                Group {
                    switch station.orderTab {
                    case 1: Process1Panel()
                    case 2: Process2Panel()
                    default: OrderEntryPanel()
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FX.tealMid)
                tabs
            }
            .padding(.leading, 6)
            .background(FX.tealDark)
        }
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            ForEach(Array(["Order Entry", "Process 1", "Process 2"].enumerated()), id: \.offset) { i, t in
                Button { station.orderTab = i } label: {
                    Text(t)
                        .font(FX.font(13))
                        .foregroundColor(.black)
                        .frame(width: 140, height: 20)
                        .background(station.orderTab == i ? FX.teal : FX.panel)
                        .bevel(station.orderTab != i, 1)
                }
                .buttonStyle(PressStyle())
            }
            Spacer()
        }
        .padding(.leading, 30)
        .padding(.vertical, 3)
        .background(FX.tealMid)
    }
}

// MARK: - Left service menu

private struct ServiceMenu: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Service Menu")
                .font(FX.font(13))
                .foregroundColor(.white)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                .background(FX.tealDeep)
                .padding(.top, 12)
            tile("Printing with Film", "printer", selected: false)
            tile("Media\nfrom Film", "opticaldisc", selected: true)
            tile("Print/Media\nfrom Film", "printer.dotmatrix", selected: false)
            Spacer()
            HStack(spacing: 0) {
                ForEach(["Media", "Custom", "Film"], id: \.self) { t in
                    Text(t)
                        .font(FX.font(12))
                        .foregroundColor(t == "Film" ? .white : .black)
                        .frame(maxWidth: .infinity, minHeight: 20)
                        .background(t == "Film" ? FX.teal : FX.panel)
                        .bevel(t != "Film", 1)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 8)
        .background(FX.tealDark)
    }

    private func tile(_ title: String, _ symbol: String, selected: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "film").font(.system(size: 22)).foregroundColor(Color(hex: 0xB0552E))
                Image(systemName: symbol).font(.system(size: 18)).foregroundColor(selected ? Color(hex: 0x9A7A10) : .white)
                    .offset(x: 14, y: 8)
            }
            .frame(width: 60, height: 44)
            Text(title).font(FX.font(13)).foregroundColor(selected ? .black : .white.opacity(0.75))
            Spacer()
        }
        .padding(6)
        .frame(height: 60)
        .background(selected ? FX.selectYellow : FX.teal.opacity(0.55))
        .bevel(true, 2)
        .opacity(selected ? 1 : 0.65)
        .help(selected ? "Digitize film to media" : "Printing is not available on this station")
    }
}

// MARK: - Order Entry tab

private struct OrderEntryPanel: View {
    @EnvironmentObject var station: Station
    @State private var showFilm = false
    @State private var showService = false
    @State private var showCustomer = false

    var body: some View {
        let o = station.order
        let model = station.scannerModel
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 14) {
                SectionBar(title: "Input Information", boxed: true)
                Spacer().frame(height: 24)
                CardButton(value: o.filmKind.title, caption: "Film Type", action: { showFilm = true }) {
                    FilmStripIcon()
                }
                .popover(isPresented: $showFilm, arrowEdge: .trailing) {
                    ChoiceList(title: "Film Type", items: FilmKind.allCases.map { ($0.title, $0 == o.filmKind) }) { i in
                        station.order.filmKind = FilmKind.allCases[i]; showFilm = false
                    }
                }
                CardButton(value: station.currentCustomer?.name.nilIfEmpty ?? station.currentCustomer?.id ?? "No customer",
                           caption: station.currentCustomer?.id ?? "Customer", action: { showCustomer = true }) {
                    Pictogram(symbol: "person.2.fill", colors: [Color(hex: 0x5A9AD8), Color(hex: 0x24508A)])
                }
                .popover(isPresented: $showCustomer, arrowEdge: .trailing) {
                    CustomerPicker(done: { showCustomer = false })
                }
                Spacer()
            }
            .padding(6)
            .frame(width: 160)
            .frame(maxHeight: .infinity)
            .background(FX.panel)

            VStack(alignment: .leading, spacing: 10) {
                SectionBar(title: "Image Size Information")
                GroupBox {
                    SegmentRow(options: ImageSize.allCases.map(\.code), selected: ImageSize.allCases.firstIndex(of: o.imageSize)!) {
                        station.order.imageSize = ImageSize.allCases[$0]
                    }
                } label: {
                    Text("Image Size Simple Setting").font(FX.font(12))
                }
                .padding(.horizontal, 6)
                HStack(alignment: .top) {
                    CardButton(value: "\(o.imageSize.code)   \(o.imageSize.summary(for: model))", caption: "Image Size", width: 190,
                               action: { station.order.imageSize = o.imageSize == .large ? .small : .large }) {
                        Pictogram(symbol: "person.3.fill", colors: [Color(hex: 0x4FA0E0), Color(hex: 0x2B6E3A)])
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "Large: full optical resolution (\(ImageSize.large.dpi(for: model)) dpi)")
                        Text(verbatim: "Small: \(ImageSize.small.dpi(for: model)) dpi — web and screen")
                        Text("Scanner: \(station.scanner.connectedScanner?.name ?? "none")")
                    }
                    .font(FX.font(11))
                    .foregroundColor(Color(hex: 0x404040))
                    .padding(.top, 8)
                }
                .padding(.horizontal, 6)
                Spacer()
                SectionBar(title: "Digitize Information")
                HStack(alignment: .top, spacing: 14) {
                    CardButton(value: "\(o.outputMedia.title) \(o.fileFormat.title)", caption: "Service", width: 150, action: { showService = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: o.outputMedia.symbol).font(.system(size: 26)).foregroundColor(Color(hex: 0xA08A20))
                            if o.outputMedia == .disc {
                                Text("x").font(FX.font(12))
                                FieldBox(text: "\(o.discCopies)", width: 30, align: .trailing)
                            }
                        }
                    }
                    .popover(isPresented: $showService, arrowEdge: .top) { ServicePicker() }
                    CardButton(value: o.indexSheet ? "Index ON" : "Index OFF", caption: "Index for Media", width: 130,
                               highlighted: o.indexSheet, action: { station.order.indexSheet.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.grid.3x3.fill").font(.system(size: 24)).foregroundColor(Color(hex: 0x8A8A8A))
                            Text("x").font(FX.font(12))
                            FieldBox(text: o.indexSheet ? "1" : "0", width: 30, align: .trailing)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(FX.panel)
        }
    }
}

// MARK: - Process 1 (scanner)

private struct Process1Panel: View {
    @EnvironmentObject var station: Station

    var body: some View {
        let o = station.order
        let ice = DigitalICE.allCases
        VStack(alignment: .leading, spacing: 12) {
            SectionBar(title: "Scanner Settings")
            OptionRow(title: "Digital ICE", options: ice.map(\.rawValue), selected: ice.firstIndex(of: o.ice) ?? 1,
                      enabled: station.scannerModel?.supportsDigitalICE ?? true) { station.order.digitalICE = ice[$0].rawValue }
            OptionRow(title: "Multi-sample scan", options: ["OFF", "ON"], selected: o.multiScan ? 1 : 0) { station.order.multiScan = $0 == 1 }
            OptionRow(title: "Bit depth (TIFF)", options: ["8 bit", "16 bit"], selected: o.highBitDepth ? 1 : 0,
                      enabled: o.fileFormat == .tiff) { station.order.highBitDepth = $0 == 1 }
            OptionRow(title: "Preview", options: ["All frames", "Single frame"], selected: o.previewAllFrames ? 0 : 1) { station.order.previewAllFrames = $0 == 0 }
            SectionBar(title: "Workflow")
            OptionRow(title: "Mode", options: ["Semi", "Auto"], selected: o.mode == .semi ? 0 : 1) { station.order.mode = $0 == 0 ? .semi : .auto }
            Text("Semi stops at frame check after the preview. Auto scans every frame straight away with the held tone settings.")
                .font(FX.font(11)).foregroundColor(Color(hex: 0x404040)).padding(.leading, 190)
            OptionRow(title: "After scan", options: ["Next order", "Stay on frames"], selected: o.finishAfterScan ? 0 : 1) { station.order.finishAfterScan = $0 == 0 }
            OptionRow(title: "Default tone", options: [o.defaultCorrection.tone.title + (o.defaultCorrection.hypertone ? " + Hypertone" : ""), "Reset"],
                      selected: 0) { if $0 == 1 { station.order.defaultCorrection = FrameCorrection() } }
            Spacer()
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FX.panel)
    }
}

// MARK: - Process 2 (output)

private struct Process2Panel: View {
    @EnvironmentObject var station: Station
    private let qualities: [(String, Double)] = [("Standard", 0.8), ("High", 0.92), ("Maximum", 1.0)]

    var body: some View {
        let o = station.order
        VStack(alignment: .leading, spacing: 12) {
            SectionBar(title: "Output Settings")
            OptionRow(title: "Output media", options: OutputMedia.allCases.map(\.title),
                      selected: OutputMedia.allCases.firstIndex(of: o.outputMedia)!) { station.order.outputMedia = OutputMedia.allCases[$0] }
            OptionRow(title: "File format", options: FileFormat.allCases.map(\.title),
                      selected: FileFormat.allCases.firstIndex(of: o.fileFormat)!) { station.order.fileFormat = FileFormat.allCases[$0] }
            OptionRow(title: "JPG quality", options: qualities.map(\.0),
                      selected: qualities.firstIndex { abs($0.1 - o.jpegQuality) < 0.01 } ?? 1,
                      enabled: o.fileFormat == .jpeg) { station.order.jpegQuality = qualities[$0].1 }
            OptionRow(title: "Disc copies", options: ["1", "2", "3"], selected: max(0, min(2, o.discCopies - 1))) { station.order.discCopies = $0 + 1 }
            OptionRow(title: "Index sheet", options: ["OFF", "ON"], selected: o.indexSheet ? 1 : 0) { station.order.indexSheet = $0 == 1 }
            SectionBar(title: "Folders")
            FolderRow(title: "Local disk", path: $station.order.localFolder)
            FolderRow(title: "Network share", path: $station.order.networkFolder)
            Text("Files are saved as <folder>/<Customer ID Name>/<Job ID>/<Job ID>_<frame>. Job, customer and film are written to IPTC/EXIF metadata.")
                .font(FX.font(11)).foregroundColor(Color(hex: 0x404040))
            Spacer()
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FX.panel)
    }
}

// MARK: - Shared controls

/// Frontier segmented setting (35L / 35S): selected segment framed in green.
struct SegmentRow: View {
    var options: [String]
    var selected: Int
    var enabled = true
    var width: CGFloat = 86
    var onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { i in
                Button { onSelect(i) } label: {
                    Text(options[i])
                        .font(FX.font(13))
                        .foregroundColor(enabled ? .black : FX.dim)
                        .frame(width: width, height: 22)
                        .background(i == selected ? Color(hex: 0xA8A8A8) : FX.cardTop)
                        .overlay(Rectangle().stroke(i == selected && enabled ? FX.selGreen : FX.shadow, lineWidth: i == selected ? 3 : 1))
                }
                .buttonStyle(PressStyle())
                .disabled(!enabled)
            }
        }
    }
}

struct OptionRow: View {
    var title: String
    var options: [String]
    var selected: Int
    var enabled = true
    var onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(title).font(FX.font(13)).foregroundColor(enabled ? .black : FX.dim).frame(width: 180, alignment: .leading)
            SegmentRow(options: options, selected: selected, enabled: enabled, width: 120, onSelect: onSelect)
        }
        .padding(.leading, 6)
    }
}

private struct FolderRow: View {
    var title: String
    @Binding var path: String

    var body: some View {
        HStack(spacing: 10) {
            Text(title).font(FX.font(13)).frame(width: 180, alignment: .leading)
            FieldBox(text: path.isEmpty ? "— not set —" : path)
            ClassicButton(title: "Choose…", width: 90) {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.canCreateDirectories = true
                if !path.isEmpty { panel.directoryURL = URL(fileURLWithPath: path) }
                if panel.runModal() == .OK, let url = panel.url { path = url.path }
            }
        }
        .padding(.leading, 6)
    }
}

/// Vertical list of large choice buttons inside a popover.
struct ChoiceList: View {
    var title: String
    var items: [(String, Bool)]
    var onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 6) {
            SectionBar(title: title)
            ForEach(items.indices, id: \.self) { i in
                Button { onSelect(i) } label: {
                    Text(items[i].0)
                        .font(FX.font(14))
                        .foregroundColor(.black)
                        .frame(width: 200, height: 34)
                        .background(items[i].1 ? FX.selectYellow : FX.card)
                        .bevel(true, 2)
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(10)
        .background(FX.work)
    }
}

private struct ServicePicker: View {
    @EnvironmentObject var station: Station

    var body: some View {
        let o = station.order
        VStack(alignment: .leading, spacing: 10) {
            SectionBar(title: "Digitize Service")
            SegmentRow(options: OutputMedia.allCases.map(\.title), selected: OutputMedia.allCases.firstIndex(of: o.outputMedia)!, width: 110) {
                station.order.outputMedia = OutputMedia.allCases[$0]
            }
            SegmentRow(options: FileFormat.allCases.map(\.title), selected: FileFormat.allCases.firstIndex(of: o.fileFormat)!, width: 110) {
                station.order.fileFormat = FileFormat.allCases[$0]
            }
            if o.outputMedia == .disc {
                HStack {
                    Text("Copies").font(FX.font(13))
                    SegmentRow(options: ["1", "2", "3"], selected: max(0, min(2, o.discCopies - 1)), width: 40) { station.order.discCopies = $0 + 1 }
                }
            } else {
                Text(o.outputFolder.isEmpty ? "Set the folder under Process 2" : o.outputFolder)
                    .font(FX.font(11)).foregroundColor(Color(hex: 0x404040)).frame(width: 330, alignment: .leading)
            }
        }
        .padding(10)
        .background(FX.work)
    }
}

struct CustomerPicker: View {
    @EnvironmentObject var station: Station
    var done: () -> Void
    @State private var text = ""

    var body: some View {
        let matches = station.store.customers
            .filter { text.isEmpty || $0.name.localizedCaseInsensitiveContains(text) || $0.id.localizedCaseInsensitiveContains(text) }
            .sorted { $0.created > $1.created }
        VStack(alignment: .leading, spacing: 8) {
            SectionBar(title: "Customer")
            TextField("Name or customer ID", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(FX.font(14))
                .onSubmit { createIfNew(matches) }
            HStack {
                ClassicButton(title: "New customer", width: 130, enabled: !text.trimmingCharacters(in: .whitespaces).isEmpty) {
                    station.newCustomer(named: text); done()
                }
                ClassicButton(title: "No customer", width: 110) { station.setCustomer(nil); done() }
            }
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(matches) { c in
                        Button { station.setCustomer(c); done() } label: {
                            HStack {
                                Text(c.name).font(FX.font(13))
                                Spacer()
                                Text(c.id).font(FX.font(12)).foregroundColor(Color(hex: 0x505050))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .frame(height: 26)
                            .background(c.id == station.order.customerID ? FX.selectYellow : FX.card)
                            .bevel(true, 1)
                        }
                        .buttonStyle(PressStyle())
                    }
                }
            }
            .frame(height: 220)
            Text("The customer is written to every job and file until you change it.")
                .font(FX.font(11)).foregroundColor(Color(hex: 0x404040))
        }
        .padding(10)
        .frame(width: 340)
        .background(FX.work)
    }

    /// Return in the field: pick an exact match, otherwise create a new customer.
    private func createIfNew(_ matches: [Customer]) {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        if let exact = matches.first(where: { $0.name.caseInsensitiveCompare(t) == .orderedSame || $0.id.caseInsensitiveCompare(t) == .orderedSame }) {
            station.setCustomer(exact)
        } else {
            station.newCustomer(named: t)
        }
        done()
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
