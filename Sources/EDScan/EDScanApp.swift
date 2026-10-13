import SwiftUI
import CoolscanKit

@main
struct EDScanApp: App {
    @StateObject private var scanner: ScannerManager
    @StateObject private var settings: ScanSettings
    @StateObject private var store: JobStore
    @StateObject private var station: Station

    init() {
        let scanner = ScannerManager()
        let settings = ScanSettings()
        let store = JobStore()
        _scanner = StateObject(wrappedValue: scanner)
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: store)
        _station = StateObject(wrappedValue: Station(scanner: scanner, settings: settings, store: store))
    }

    var body: some Scene {
        WindowGroup("ED Scan") {
            RootView()
                .environmentObject(scanner)
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(station)
                .frame(minWidth: 1100, minHeight: 720)
                .preferredColorScheme(.light)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Order") { station.newOrder() }.keyboardShortcut("n")
            }
        }
    }
}
