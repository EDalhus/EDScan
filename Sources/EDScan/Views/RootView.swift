import SwiftUI
import CoolscanKit

struct RootView: View {
    @EnvironmentObject var station: Station
    @EnvironmentObject var scanner: ScannerManager

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar()
            ZStack(alignment: .bottom) {
                Group {
                    switch station.screen {
                    case .jobList: JobListView()
                    case .orderEntry: OrderEntryView()
                    case .frameCheck: FrameCheckView()
                    case .enlarged: EnlargedFrameView()
                    case .customerImages: CustomerImagesView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // On its own view: two .alert modifiers on one view don't both present reliably.
                .alert("Delete job \(station.confirmDeleteJobID ?? "")?",
                       isPresented: Binding(get: { station.confirmDeleteJobID != nil }, set: { if !$0 { station.confirmDeleteJobID = nil } })) {
                    Button("Delete", role: .destructive) { station.confirmDelete() }
                    Button("Cancel", role: .cancel) { station.confirmDeleteJobID = nil }
                } message: {
                    Text("The job and its thumbnails are removed from the list. Image files already saved are kept.")
                }

                switch station.overlay {
                case .imageCorrect:
                    ImageCorrectPanel().frame(maxHeight: .infinity, alignment: .center)
                case .toneAdjust:
                    ToneAdjustPanel().padding(.horizontal, 6)
                case .help:
                    HelpPanel().frame(maxHeight: .infinity, alignment: .center)
                case nil:
                    EmptyView()
                }
            }
            FunctionBar()
                .alert("Scanner is busy", isPresented: Binding(get: { !station.strayProcesses.isEmpty },
                                                               set: { if !$0 { station.dismissStray() } })) {
                    Button("Stop and Retry") { station.stopStrayAndRetry() }
                    Button("Cancel", role: .cancel) { station.dismissStray() }
                } message: {
                    Text("An earlier scanner command never finished and is still holding the scanner:\n\n"
                         + station.strayProcesses.map(\.summary).joined(separator: "\n")
                         + "\n\nIf stopping it does not help, switch the scanner off and on.")
                }
            StatusBar()
        }
        .background(FX.work)
        .ignoresSafeArea()
        .modifier(KeyMonitor { station.handleKey($0) })
        .alert("ED Scan", isPresented: Binding(get: { station.alert != nil }, set: { if !$0 { station.alert = nil } })) {
            Button("OK") { station.alert = nil }
        } message: {
            Text(station.alert ?? "")
        }
        .onChange(of: scanner.lastError) { err in
            // Surface scanner errors once, Frontier-style, via the red "!" and an alert.
            // ICE rejection is handled by rescanning without ICE, so it is not an error for the user.
            if let err, station.alert == nil, !Station.isICEUnavailable(err) { station.alert = err }
        }
    }
}
