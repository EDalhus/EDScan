# ED Scan

ED Scan is a new macOS scanning app for Nikon Coolscan film scanners by Eirik Dalhus ("ED" = Digital Export + Eirik Dalhus). Goal: a completely different, more user-friendly interface than OpenCoolscan, with more and better features.

## Related projects

- **CoolscanKit** — https://github.com/EDalhus/CoolscanKit (local: `~/orca/projects/CoolscanKit`). Swift package with the scanner core: USB hot-plug detection, SANE `coolscan3` preview/scan (`ScannerManager`, `NikonMAIDDriver`), `SimulatedScanner`, `ScanSettings`, `ImageProcessor`, `HistogramData`. Getting USB/preview/scanning to work took a lot of effort — reuse it, don't rewrite it.
- **OpenCoolscan** — https://github.com/EDalhus/OpenCoolscan. Nikon Scan 4–style app, **frozen**: do not change it. It pins CoolscanKit `exact: "1.0.0"`.

## Rules

- UI and app features go in this repo. Scanner/processing improvements go in CoolscanKit and are released as new semver tags (1.1.0, …); then bump ED Scan. Never retag or break 1.0.0 (OpenCoolscan depends on it).
- Communicate with the user in Norwegian.
- Build: `./build.sh` → `ED Scan.app` (universal, ad-hoc signed); `./build.sh --release` also makes the release zip. Use the Simulated Scanner to test without hardware.
- Releases: bump `CFBundleShortVersionString` in `Support/Info.plist`, tag `vX.Y.Z[-beta.N]`, attach the zip as a GitHub release.
- Avoid project paths containing `:` — SwiftPM builds fail there.

## Current state

Frontier-style UI (Fujifilm "Digital Image Export"), modelled 1:1 on its layout and colours:

- `Station.swift` — screen flow + job execution. Order Entry → START (preview job) → frame check → START (scan job, timed) → files written in the background → next order. Each preview/scan is its own job (`00718-01`, `-02`, …).
- `Model/` — `OrderEntry` (persisted on every change), `ScanJob`/`Customer` + `JobStore` (JSON in ~/Library/Application Support/ED Scan), `FrameCorrection` (C/M/Y/D, tone, hypertone…).
- `Processing/` — `FrameRenderer` (per-frame Core Image corrections), `ImageExporter` (IPTC/EXIF with job + customer), `IndexSheet`, `DiscBurner` (`drutil`).
- `Views/` + `Frontier/Frontier.swift` (palette, bevels, card/pill buttons). F1–F6 per screen in `Views/Keys.swift`.

Per-frame correction lives in the app for now; move it to CoolscanKit (1.1.0) if OpenCoolscan-style apps should share it.
