import Foundation
import AppKit

/// Job and customer register, persisted as JSON in ~/Library/Application Support/ED Scan.
@MainActor
final class JobStore: ObservableObject {
    @Published private(set) var jobs: [ScanJob] = []        // newest first
    @Published private(set) var customers: [Customer] = []

    let root: URL
    private var jobsURL: URL { root.appendingPathComponent("jobs.json") }
    private var customersURL: URL { root.appendingPathComponent("customers.json") }
    private let orderCounterKey = "EDScan.NextOrderNumber"

    init() {
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ED Scan", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        jobs = Self.readList(ScanJob.self, from: jobsURL)
        customers = Self.readList(Customer.self, from: customersURL)
        // A crash or quit mid-job leaves it "active" forever; mark those as interrupted.
        for i in jobs.indices where jobs[i].status.isActive {
            jobs[i].status = .failed
            jobs[i].statusDetail = "Interrupted"
        }
    }

    // MARK: Order numbers

    /// Next free order number. Numbers already in the job list are skipped, so a reset counter
    /// (or the wrap after 99999) can never produce a job ID that overwrites an existing job.
    var peekOrderNumber: Int {
        let used = Set(jobs.map(\.orderNumber))
        var n = min(max(UserDefaults.standard.integer(forKey: orderCounterKey), 1), 99_999)
        var tries = 0
        while used.contains(n), tries < 99_999 {
            n = n >= 99_999 ? 1 : n + 1
            tries += 1
        }
        return n
    }

    func allocateOrderNumber() -> Int {
        let n = peekOrderNumber
        UserDefaults.standard.set(n >= 99_999 ? 1 : n + 1, forKey: orderCounterKey)
        return n
    }

    static func jobID(order: Int, sub: Int) -> String {
        String(format: "%05d-%02d", order, sub)
    }

    // MARK: Jobs

    func job(_ id: String?) -> ScanJob? { jobs.first { $0.id == id } }

    func add(_ job: ScanJob) {
        jobs.insert(job, at: 0)
        saveJobs()
    }

    func update(_ id: String, _ change: (inout ScanJob) -> Void) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        change(&jobs[i])
        saveJobs()
    }

    func delete(_ id: String) {
        jobs.removeAll { $0.id == id }
        thumbCache.removeAllObjects()
        try? FileManager.default.removeItem(at: jobFolder(id))
        saveJobs()
    }

    func jobFolder(_ id: String) -> URL {
        root.appendingPathComponent("Jobs/\(id)", isDirectory: true)
    }

    func thumbnailURL(_ job: ScanJob, _ frame: JobFrame) -> URL {
        jobFolder(job.id).appendingPathComponent(frame.thumbnail)
    }

    private let thumbCache = NSCache<NSURL, NSImage>()

    /// Cached: the customer view re-renders on every scanner progress tick.
    func thumbnail(_ job: ScanJob, _ frame: JobFrame) -> NSImage? {
        let url = thumbnailURL(job, frame) as NSURL
        if let img = thumbCache.object(forKey: url) { return img }
        guard let img = NSImage(contentsOf: url as URL) else { return nil }
        thumbCache.setObject(img, forKey: url)
        return img
    }

    // MARK: Customers

    func customer(_ id: String?) -> Customer? { customers.first { $0.id == id } }

    /// New customer with a random, unique six-digit ID.
    func createCustomer(name: String) -> Customer {
        var id: String
        repeat { id = String(format: "C-%06d", Int.random(in: 100_000...999_999)) }
        while customers.contains { $0.id == id }
        let c = Customer(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), created: Date())
        customers.append(c)
        saveCustomers()
        return c
    }

    func jobs(for customerID: String) -> [ScanJob] {
        jobs.filter { $0.customerID == customerID }
    }

    // MARK: Persistence

    private func saveJobs() { Self.write(jobs, to: jobsURL) }
    private func saveCustomers() { Self.write(customers, to: customersURL) }

    /// Reads a JSON array, skipping entries that no longer decode. If the file can't be read at all it is
    /// copied aside first, so the next save can never silently wipe the job history.
    private static func readList<T: Decodable>(_ type: T.Type, from url: URL) -> [T] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        if let items = try? d.decode([Lenient<T>].self, from: data) {
            let good = items.compactMap(\.value)
            if good.count < items.count { backup(url) }
            return good
        }
        backup(url)
        return []
    }

    private static func backup(_ url: URL) {
        let stamp = Int(Date().timeIntervalSince1970)
        try? FileManager.default.copyItem(at: url, to: url.deletingPathExtension().appendingPathExtension("broken-\(stamp).json"))
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? e.encode(value) { try? data.write(to: url, options: .atomic) }
    }
}

/// Decodes to nil instead of failing the whole array.
private struct Lenient<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}
