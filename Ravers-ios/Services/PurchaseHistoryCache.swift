import Foundation

struct PurchaseHistory: Codable {
    let userID: UUID
    var orders: [Order]
    var tickets: [Ticket]
}

@MainActor
protocol PurchaseHistoryCaching {
    func load(for userID: UUID) throws -> PurchaseHistory?
    func save(_ history: PurchaseHistory) throws
}

/// A display cache of server-confirmed history. It never creates purchases or
/// grants access; Supabase remains authoritative for payment and ticket status.
@MainActor
final class FilePurchaseHistoryCache: PurchaseHistoryCaching {
    private let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory,
                                                               in: .userDomainMask)[0]
            .appendingPathComponent("Raverse/PurchaseHistory", isDirectory: true)
    }

    func load(for userID: UUID) throws -> PurchaseHistory? {
        let url = file(for: userID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let history = try JSONDecoder().decode(PurchaseHistory.self, from: Data(contentsOf: url))
        guard history.userID == userID else { return nil }
        return history
    }

    func save(_ history: PurchaseHistory) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        var protectedDirectory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try protectedDirectory.setResourceValues(values)
        let data = try JSONEncoder().encode(history)
        #if os(iOS)
        try data.write(to: file(for: history.userID), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: file(for: history.userID), options: .atomic)
        #endif
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file(for: history.userID).path)
    }

    private func file(for userID: UUID) -> URL {
        directory.appendingPathComponent(userID.uuidString.lowercased()).appendingPathExtension("json")
    }
}
