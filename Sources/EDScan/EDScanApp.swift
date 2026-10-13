import SwiftUI
import CoolscanKit

@main
struct EDScanApp: App {
    @StateObject private var scanner = ScannerManager()
    @StateObject private var settings = ScanSettings()

    var body: some Scene {
        WindowGroup("ED Scan") {
            ContentView()
                .environmentObject(scanner)
                .environmentObject(settings)
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}
