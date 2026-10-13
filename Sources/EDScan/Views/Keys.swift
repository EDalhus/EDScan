import SwiftUI
import AppKit

/// F1–F6 assignments per screen, shared by the function key bar and the keyboard.
extension Station {
    func functionKeys() -> [FKey] {
        let busy = scanner.isBusy
        let haveFrames = !frames.isEmpty
        switch screen {
        case .orderEntry:
            return [
                FKey(label: "Order Entry") { self.orderTab = 0 },
                FKey(label: "Process 1") { self.orderTab = 1 },
                FKey(label: "Process 2") { self.orderTab = 2 },
                FKey(label: "Size \(order.imageSize == .large ? "S" : "L")") { self.order.imageSize = self.order.imageSize == .large ? .small : .large },
                FKey(label: "Customer", action: { self.showCustomer(nil) }),
                FKey(label: "->Frames", enabled: haveFrames) { self.screen = .frameCheck },
            ]
        case .frameCheck, .enlarged:
            return [
                FKey(label: "Correct", enabled: haveFrames) { self.overlay = self.overlay == .imageCorrect ? nil : .imageCorrect },
                FKey(label: "Rotate", enabled: haveFrames) { self.rotateSelected() },
                FKey(label: "Mag.", enabled: haveFrames) { self.overlay = nil; self.screen = self.screen == .enlarged ? .frameCheck : .enlarged },
                FKey(label: "P.SET 0/1", enabled: haveFrames) { self.togglePrintSet() },
                FKey(label: "Tone Adjust.", enabled: haveFrames) { self.openToneAdjust() },
                FKey(label: "->Order Info.", enabled: !busy) { self.overlay = nil; self.screen = .orderEntry },
            ]
        case .jobList:
            let job = store.job(selectedJobID)
            return [
                FKey(label: "New Order", enabled: !busy) { self.newOrder() },
                FKey(label: "Order Entry", enabled: !busy) { self.screen = .orderEntry },
                FKey(label: "Customer", action: { self.showCustomer(job?.customerID) }),
                FKey(label: "Open Folder", enabled: job?.outputFolder != nil) { if let job { self.revealOutput(job) } },
                FKey(label: "Burn Disc", enabled: job?.status == .waitingForDisc) { if let job { Task { await self.burn(job.id) } } },
                FKey(label: "Delete", enabled: job.map { !$0.status.isActive } ?? false) { if let job { self.deleteJob(job.id) } },
            ]
        case .customerImages:
            return [
                FKey(label: "Main Menu") { self.mainMenu() },
                FKey(label: "Order Entry", enabled: !busy) { self.screen = .orderEntry },
                FKey(label: "Use Customer", enabled: browsingCustomerID != nil) {
                    self.order.customerID = self.browsingCustomerID
                    self.notice = "Customer set for the next jobs"
                },
                .empty, .empty, .empty,
            ]
        }
    }

    /// Returns true when the key was consumed.
    func handleKey(_ e: NSEvent) -> Bool {
        // Only the station window itself: never steal keys from alerts, sheets, popovers or open panels.
        guard let window = e.window, window.isMainWindow, window.attachedSheet == nil,
              NSApp.modalWindow == nil, alert == nil, confirmDeleteJobID == nil,
              strayProcesses.isEmpty else { return false }
        let fKeys: [UInt16: Int] = [122: 0, 120: 1, 99: 2, 118: 3, 96: 4, 97: 5]
        if let i = fKeys[e.keyCode] {
            let k = functionKeys()[i]
            if k.enabled { k.action() }
            return true
        }
        // Leave typing alone.
        if let tv = NSApp.keyWindow?.firstResponder as? NSTextView, tv.isEditable { return false }
        if e.modifierFlags.contains(.command) { return false }

        let isReturn = e.keyCode == 36 || e.keyCode == 76
        if e.keyCode == 53 {   // Esc
            if overlay == .toneAdjust { closeToneAdjust(.cancel) }
            else if overlay != nil { overlay = nil }
            else if screen == .enlarged { screen = .frameCheck }
            else { return false }
            return true
        }

        if overlay == .toneAdjust {
            let tones = ToneAdjustment.allCases
            if let ch = e.charactersIgnoringModifiers, let n = Int(ch), (1...tones.count).contains(n) {
                modifySelected { $0.tone = tones[n - 1] }
                return true
            }
            if e.charactersIgnoringModifiers == "h" { modifySelected { $0.hypertone.toggle() }; return true }
            if isReturn { closeToneAdjust(.ok); return true }
        }

        switch screen {
        case .orderEntry:
            if isReturn { Task { await start() }; return true }
        case .frameCheck, .enlarged:
            if isReturn { Task { await scanFrames() }; return true }
            switch e.keyCode {
            case 123: moveSelection(-1); return true
            case 124: moveSelection(1); return true
            case 126: moveSelection(-3); return true
            case 125: moveSelection(3); return true
            case 49: togglePrintSet(); return true            // space
            default: break
            }
            switch e.charactersIgnoringModifiers?.lowercased() {
            case "q": adjustKey(\.c, 1)
            case "a": adjustKey(\.c, -1)
            case "w": adjustKey(\.m, 1)
            case "s": adjustKey(\.m, -1)
            case "e": adjustKey(\.y, 1)
            case "d": adjustKey(\.y, -1)
            case "r": adjustKey(\.d, 1)
            case "f": adjustKey(\.d, -1)
            case "t": openToneAdjust()
            case "0": resetSelected()
            default: return false
            }
            return true
        default: break
        }
        return false
    }
}

/// Installs a local key monitor for the lifetime of the view.
struct KeyMonitor: ViewModifier {
    let handler: (NSEvent) -> Bool
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in handler(e) ? nil : e }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
            }
    }
}

struct HelpPanel: View {
    @EnvironmentObject var station: Station

    private let rows: [(String, String)] = [
        ("F1 – F6", "Function keys shown in the bar (fn + F-key on Mac keyboards)"),
        ("Return", "START (Order Entry: preview · Frame check: full scan)"),
        ("← → ↑ ↓", "Select frame"),
        ("Q / A", "C + / −   (more / less cyan)"),
        ("W / S", "M + / −"),
        ("E / D", "Y + / −"),
        ("R / F", "D + / −   (darker / lighter)"),
        ("Space", "P.SET 0/1 (skip frame in scan)"),
        ("T", "Tone Adjustment (1–7 choose, H hypertone, Return OK)"),
        ("0", "Reset corrections of the frame"),
        ("Esc", "Close panel / back"),
    ]

    var body: some View {
        ClassicDialog(title: "Keys") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(rows, id: \.0) { r in
                    HStack(alignment: .top) {
                        Text(r.0).font(FX.font(13, .bold)).frame(width: 90, alignment: .leading)
                        Text(r.1).font(FX.font(13))
                    }
                }
                HStack { Spacer(); ClassicButton(title: "Close") { station.overlay = nil } }
            }
            .padding(14)
        }
        .frame(width: 560, height: 360)
    }
}
