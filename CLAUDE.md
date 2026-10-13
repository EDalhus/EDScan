# ED Scan

ED Scan is a new macOS scanning app for Nikon Coolscan film scanners by Eirik Dalhus ("ED" = Digital Export + Eirik Dalhus). Goal: a completely different, more user-friendly interface than OpenCoolscan, with more and better features.

## Related projects

- **CoolscanKit** — https://github.com/EDalhus/CoolscanKit (local: `~/orca/projects/CoolscanKit`). Swift package with the scanner core: USB hot-plug detection, SANE `coolscan3` preview/scan (`ScannerManager`, `NikonMAIDDriver`), `SimulatedScanner`, `ScanSettings`, `ImageProcessor`, `HistogramData`. Getting USB/preview/scanning to work took a lot of effort — reuse it, don't rewrite it.
- **OpenCoolscan** — https://github.com/EDalhus/OpenCoolscan. Nikon Scan 4–style app, **frozen**: do not change it. It pins CoolscanKit `exact: "1.0.0"`.

## Rules

- UI and app features go in this repo. Scanner/processing improvements go in CoolscanKit and are released as new semver tags (1.1.0, …); then bump ED Scan. Never retag or break 1.0.0 (OpenCoolscan depends on it).
- Communicate with the user in Norwegian.
- Build: `./build.sh` → `ED Scan.app`. Use the Simulated Scanner to test without hardware.
- Avoid project paths containing `:` — SwiftPM builds fail there.

## Current state

`Sources/EDScan/ContentView.swift` is a minimal placeholder (scanner picker, film type, Preview/Scan, image view, status) that proves the CoolscanKit integration. The real interface is still to be designed with the user.
