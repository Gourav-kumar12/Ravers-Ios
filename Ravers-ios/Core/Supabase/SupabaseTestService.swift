import Foundation
import Supabase

final class SupabaseTestService {

    /// Reads the `connection_test` table. Throws so the caller can show the real error.
    func testDatabaseConnection() async throws -> [ConnectionTest] {
        let supabase = try SupabaseManager.shared.makeClient()

        let rows: [ConnectionTest] = try await supabase
            .from("connection_test")
            .select()
            .execute()
            .value

        print("SUPABASE DATABASE CONNECTED ✅ rows:", rows.count)
        return rows
    }
}

struct ConnectionTest: Codable, Identifiable {
    let id: Int64
    let message: String
}
