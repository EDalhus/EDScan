import SwiftUI

/// All images from all jobs of one customer, newest job first.
struct CustomerImagesView: View {
    @EnvironmentObject var station: Station
    @State private var search = ""
    @State private var includePreviews = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 230)
            content
        }
    }

    private var sidebar: some View {
        let customers = station.store.customers
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.id.localizedCaseInsensitiveContains(search) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return VStack(spacing: 6) {
            Text("Customers")
                .font(FX.font(13)).foregroundColor(.white)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                .background(FX.tealDeep)
                .padding(.top, 10)
            TextField("Search", text: $search)
                .textFieldStyle(.plain).font(FX.font(13))
                .padding(.horizontal, 6).frame(height: 24)
                .background(FX.fieldLight).bevel(false, 1)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(customers) { c in
                        let n = station.store.jobs(for: c.id).reduce(0) { $0 + ($1.kind == .scan ? $1.frames.count : 0) }
                        Button { station.browsingCustomerID = c.id } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name.nilIfEmpty ?? "—").font(FX.font(13))
                                Text("\(c.id) · \(n) image(s)").font(FX.font(11))
                            }
                            .foregroundColor(c.id == station.browsingCustomerID ? .black : .white)
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(c.id == station.browsingCustomerID ? FX.selectYellow : FX.teal.opacity(0.6))
                            .bevel(true, 1)
                        }
                        .buttonStyle(PressStyle())
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(FX.tealDark)
    }

    @ViewBuilder private var content: some View {
        if let id = station.browsingCustomerID, let customer = station.store.customer(id) {
            let jobs = station.store.jobs(for: id).filter { includePreviews || $0.kind == .scan }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text(customer.name.nilIfEmpty ?? "—").font(FX.font(22, .bold))
                    Text(customer.id).font(FX.font(16)).foregroundColor(Color(hex: 0x404040))
                    Spacer()
                    Toggle("Show preview jobs", isOn: $includePreviews).font(FX.font(12)).toggleStyle(.checkbox)
                    ClassicButton(title: "Use for next jobs", width: 150, enabled: station.order.customerID != id) {
                        station.order.customerID = id
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                SectionBar(title: "\(jobs.count) job(s) · \(jobs.reduce(0) { $0 + $1.frames.count }) image(s)")
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14, pinnedViews: [.sectionHeaders]) {
                        ForEach(jobs) { job in
                            Section {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                                    ForEach(job.frames, id: \.index) { frame in
                                        CustomerThumb(job: job, frame: frame)
                                    }
                                }
                                .padding(.horizontal, 12)
                            } header: {
                                HStack(spacing: 14) {
                                    Text(job.id).font(FX.font(15, .bold))
                                    Text(job.created.formatted(date: .abbreviated, time: .shortened))
                                    Text("\(job.kind.title) · \(job.inputLabel) · \(job.imageSize.code) · \(job.kind == .scan ? job.outputLabel : "")")
                                    Spacer()
                                    if job.outputFolder != nil {
                                        ClassicButton(title: "Open Folder", width: 110) { station.revealOutput(job) }
                                    }
                                }
                                .font(FX.font(12))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(FX.panel)
                            }
                        }
                        if jobs.isEmpty {
                            Text("No scanned images for this customer yet.").font(FX.font(14)).padding(20)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FX.work)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "person.2").font(.system(size: 40))
                Text(station.store.customers.isEmpty
                     ? "No customers yet. Set a customer in Order Entry — it is attached to every job you run."
                     : "Choose a customer")
                    .font(FX.font(14))
            }
            .foregroundColor(Color(hex: 0x505050))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FX.work)
        }
    }
}

private struct CustomerThumb: View {
    @EnvironmentObject var station: Station
    let job: ScanJob
    let frame: JobFrame

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Color(hex: 0x9A9A9A)
                if let img = station.store.thumbnail(job, frame) {
                    Image(nsImage: img).resizable().scaledToFit().border(Color.white, width: 2).padding(4)
                }
            }
            .frame(height: 120)
            .bevel(false, 1)
            Text("\(job.id) · \(frame.index + 1)").font(FX.font(11))
        }
        .help(frame.file ?? "Preview only")
        .onTapGesture(count: 2) {
            if let file = frame.file { NSWorkspace.shared.open(URL(fileURLWithPath: file)) }
        }
        .contextMenu {
            if let file = frame.file {
                Button("Open") { NSWorkspace.shared.open(URL(fileURLWithPath: file)) }
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file)]) }
            }
        }
    }
}
