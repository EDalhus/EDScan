import SwiftUI

struct JobListView: View {
    @EnvironmentObject var station: Station

    private var visibleJobs: [ScanJob] {
        let q = station.jobSearch.trimmingCharacters(in: .whitespaces)
        return station.store.jobs.filter { j in
            switch station.jobFilter {
            case .all: break
            case .scan: if j.kind != .scan { return false }
            case .preview: if j.kind != .preview { return false }
            case .attention: if ![.failed, .waitingForDisc].contains(j.status) { return false }
            }
            guard !q.isEmpty else { return true }
            return j.id.localizedCaseInsensitiveContains(q)
                || (j.customerID ?? "").localizedCaseInsensitiveContains(q)
                || (j.customerName ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            toolbar
            HStack(alignment: .top, spacing: 10) {
                table
                VStack(spacing: 8) {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text(ctx.date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 26)
                            .background(Color.black)
                    }
                    JobDetailPanel(job: station.store.job(station.selectedJobID))
                }
                .frame(width: 280)
            }
            .padding(.horizontal, 10)
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(FX.work)
        .onAppear {
            if station.store.job(station.selectedJobID) == nil { station.selectedJobID = station.store.jobs.first?.id }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(Station.JobFilter.allCases, id: \.self) { f in Button(f.rawValue) { station.jobFilter = f } }
            } label: {
                Text(station.jobFilter.rawValue).font(FX.font(14))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 180, height: 26)
            .padding(.horizontal, 6)
            .background(FX.panel)
            .bevel(true, 1)

            Spacer()
            Text("\(visibleJobs.count) job(s)").font(FX.font(13)).foregroundColor(Color(hex: 0x505050))
            Text("Job ID Search").font(FX.font(14, .bold))
            TextField("Job ID, customer ID or name", text: $station.jobSearch)
                .textFieldStyle(.plain)
                .font(FX.font(14))
                .padding(.horizontal, 6)
                .frame(width: 260, height: 26)
                .background(FX.fieldLight)
                .bevel(false, 1)
        }
        .padding(.horizontal, 10)
    }

    private var table: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                head("", 24)
                head("Job ID", 140)
                head("Order Type Name", nil)
                head("Input", 64)
                head("Output", 64)
                head("Customer", 140)
                head("Process", 80)
                head("Status", 104)
                head("Time", 60)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(visibleJobs) { job in
                            JobRow(job: job, selected: job.id == station.selectedJobID)
                                .id(job.id)
                                .onTapGesture(count: 2) { if job.customerID != nil { station.showCustomer(job.customerID) } }
                                .onTapGesture { station.selectedJobID = job.id }
                        }
                    }
                    .padding(.vertical, 3)
                }
                .onChange(of: station.selectedJobID) { id in if let id { proxy.scrollTo(id) } }
            }
            .background(Color(hex: 0xBCBCBC))
        }
        .bevel(false, 1)
    }

    private func head(_ title: String, _ width: CGFloat?) -> some View {
        Text(title)
            .font(FX.font(14, .bold))
            .lineLimit(1)
            .frame(width: width, height: 26)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .background(FX.buttonGradient)
            .bevel(true, 1)
    }
}

private struct JobRow: View {
    let job: ScanJob
    let selected: Bool

    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .frame(width: 24)
            Text(job.id).font(FX.font(22, .bold)).frame(width: 140)
            Text(job.kind.orderTypeName).font(FX.font(14)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)
            Text(job.inputLabel)
                .font(FX.font(10, .bold)).foregroundColor(.white)
                .frame(width: 44, height: 22)
                .background(Color(hex: 0xA42A20)).bevel(true, 1)
                .frame(width: 64)
            Image(systemName: job.outputMedia.symbol)
                .font(.system(size: 20))
                .foregroundColor(job.kind == .preview ? FX.dim : Color(hex: 0x7A6A30))
                .frame(width: 64)
            Text(job.customerName?.nilIfEmpty ?? job.customerID ?? "--").font(FX.font(13)).lineLimit(1).frame(width: 140)
            Text(job.kind.title).font(FX.font(14)).frame(width: 80)
            Text(job.status.title).font(FX.font(14)).frame(width: 104)
            Text(job.scanDuration?.clock ?? "--").font(FX.font(13)).frame(width: 60)
        }
        .foregroundColor(.black)
        .frame(height: 38)
        .background(
            selected
                ? AnyShapeStyle(FX.tealSelect)
                : AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xEEEEEE), Color(hex: 0xC8C8C8)], startPoint: .top, endPoint: .bottom))
        )
        .bevel(true, 1)
        .contentShape(Rectangle())
        .padding(.horizontal, 3)
    }

    private var statusColor: Color {
        switch job.status {
        case .completed: return Color(hex: 0x30B060)
        case .failed: return FX.alert
        case .waitingForDisc: return .orange
        case .cancelled: return FX.dim
        default: return Color(hex: 0x2A7AD0)
        }
    }
}

private struct JobDetailPanel: View {
    @EnvironmentObject var station: Station
    let job: ScanJob?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Job ID:").font(FX.font(13)).foregroundColor(.white.opacity(0.85)).padding(.leading, 8).padding(.top, 6)
            Text(job?.id ?? "")
                .font(FX.font(28, .bold))
                .padding(.leading, 12)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .background(Color(hex: 0xBDB7AE))
                .bevel(false, 1)
                .padding(6)
            if let job {
                row("calendar", "Receipt Date", job.created.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().hour().minute()))
                row("desktopcomputer", "Workplace", job.scanner)
                row("film", "Input Film", "\(job.inputLabel)  \(job.imageSize.code) \(job.dpi) dpi")
                row(job.outputMedia.symbol, "Output Media", job.kind == .preview ? "— (preview)" : job.outputLabel)
                row("person.fill", "Customer", job.customerID.map { "\(job.customerName ?? "") \($0)" } ?? "--")
                row("timer", job.kind == .scan ? "Scan Time" : "Preview Time", job.scanDuration.map { "\($0.clock)  (\(job.frames.count)/\(max(job.requestedFrames, job.frames.count)) frames)" } ?? "--")
                row("info.circle", "Status", job.status.title + (job.statusDetail.map { " — \($0)" } ?? ""))
                Spacer(minLength: 6)
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        ClassicButton(title: "Customer", width: 128, enabled: job.customerID != nil) { station.showCustomer(job.customerID) }
                        ClassicButton(title: "Open Folder", width: 128, enabled: job.outputFolder != nil) { station.revealOutput(job) }
                    }
                    HStack(spacing: 6) {
                        if job.status == .burning {
                            ClassicButton(title: "Cancel Burn", width: 128) { station.cancelBurn() }
                        } else {
                            ClassicButton(title: "Burn Disc", width: 128, enabled: job.status == .waitingForDisc) { Task { await station.burn(job.id) } }
                        }
                        ClassicButton(title: "Delete", width: 128, enabled: !job.status.isActive) { station.deleteJob(job.id) }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
            } else {
                Spacer()
            }
        }
        .frame(maxHeight: .infinity)
        .background(LinearGradient(colors: [FX.tealLight, FX.teal], startPoint: .top, endPoint: .bottom))
        .padding(4)
        .background(FX.tealDark)
    }

    private func row(_ symbol: String, _ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).font(.system(size: 18)).foregroundColor(FX.tealDeep).frame(width: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(FX.font(13, .bold)).foregroundColor(Color(hex: 0x10383C))
                Text(value).font(FX.font(12)).foregroundColor(.black).lineLimit(3)
                    .padding(.horizontal, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.5)).frame(height: 1) }
    }
}
