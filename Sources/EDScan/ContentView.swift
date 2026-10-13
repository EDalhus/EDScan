import SwiftUI
import CoolscanKit

/// Starting point for the ED Scan interface: proves the CoolscanKit
/// integration (pick scanner, preview, view result). Replace freely.
struct ContentView: View {
    @EnvironmentObject var scanner: ScannerManager
    @EnvironmentObject var settings: ScanSettings

    var body: some View {
        NavigationSplitView {
            List {
                Section("Scanner") {
                    Picker("Scanner", selection: Binding(
                        get: { scanner.connectedScanner },
                        set: { if let d = $0 { scanner.connect(to: d) } }
                    )) {
                        Text("None").tag(ScannerDevice?.none)
                        ForEach(scanner.availableScanners) { d in
                            Text(d.name).tag(ScannerDevice?.some(d))
                        }
                    }
                    .labelsHidden()
                }
                Section("Film") {
                    Picker("Film type", selection: $settings.filmType) {
                        ForEach(FilmType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                if let raw = scanner.framePreviews[scanner.selectedFrame] {
                    Image(nsImage: ImageProcessor.apply(settings: settings, to: raw, frame: scanner.selectedFrame))
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    ContentUnavailableLabel()
                }
            }
            .toolbar {
                ToolbarItemGroup {
                    if scanner.isBusy {
                        ProgressView(value: scanner.scanProgress).frame(width: 120)
                        Button("Cancel") { scanner.cancelCurrentOperation() }
                    }
                    Button("Preview") { Task { await scanner.preview(settings: settings) } }
                        .disabled(scanner.connectedScanner == nil || scanner.isBusy)
                    Button("Scan") { Task { await scanner.scan(settings: settings) } }
                        .buttonStyle(.borderedProminent)
                        .disabled(scanner.connectedScanner == nil || scanner.isBusy)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text(scanner.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.bar)
            }
        }
        .alert("Scanner error", isPresented: Binding(
            get: { scanner.lastError != nil },
            set: { if !$0 { scanner.lastError = nil } }
        )) {
            Button("OK") { scanner.lastError = nil }
        } message: {
            Text(scanner.lastError ?? "")
        }
    }
}

private struct ContentUnavailableLabel: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "film")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Choose a scanner and press Preview")
                .foregroundStyle(.secondary)
        }
    }
}
