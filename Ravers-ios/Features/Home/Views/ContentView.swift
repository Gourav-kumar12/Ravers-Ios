import SwiftUI

struct ContentView: View {
    @State private var isTesting = false
    @State private var connectionMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Raverse")
                .font(.largeTitle)

            Button {
                testConnection()
            } label: {
                if isTesting {
                    ProgressView("Checking Supabase…")
                } else {
                    Text("Test Supabase")
                }
            }
            .disabled(isTesting)

            if let connectionMessage {
                Text(connectionMessage)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(resultColor)
                    .accessibilityIdentifier("supabaseConnectionResult")
            }
        }
        .padding()
    }

    private func testConnection() {
        isTesting = true
        connectionMessage = "Checking Supabase…"

        Task {
            defer { isTesting = false }
            do {
                let rows = try await SupabaseTestService().testDatabaseConnection()
                let detail = rows.first.map { ": \($0.message)" } ?? ""
                connectionMessage = "Connected to Supabase\(detail)"
            } catch {
                connectionMessage = "Connection failed: \(error.localizedDescription)"
            }
        }
    }

    private var resultColor: Color {
        guard let connectionMessage else { return .primary }
        if connectionMessage.hasPrefix("Connected") { return .blue }
        if connectionMessage.hasPrefix("Connection failed") { return .red }
        return .secondary
    }
}

#Preview {
    ContentView()
}
