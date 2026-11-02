import SwiftUI

struct MatchesInboxView: View {
    @Environment(MatchStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if store.matches.isEmpty {
                    ContentUnavailableView("Your next connection is out there", systemImage: "person.2",
                        description: Text("Swipe right in discovery. When you both like each other, your match appears here."))
                }
                if let error = store.errorMessage { Text(error).font(.footnote).foregroundStyle(Color.rvTextMuted) }
                ForEach(store.matches) { raver in
                    NavigationLink { ChatView(raver: raver) } label: {
                        HStack(spacing: 14) {
                            RaverPortrait(raver: raver).frame(width: 58, height: 58).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 6) {
                                Text(raver.name + (raver.isDemo ? " · Sample" : "")).font(.headline)
                                if let date = store.chatUnlockDate(for: raver) {
                                    ChatUnlockLabel(date: date).font(.caption).foregroundStyle(Color.rvRed)
                                }
                                if let last = store.thread(for: raver).last {
                                    Text((last.isMine ? "You: " : "") + last.text).font(.caption)
                                        .foregroundStyle(Color.rvTextMuted).lineLimit(1)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .foregroundStyle(Color.rvText).padding(14)
                        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18).frame(maxWidth: 480)
        }
        .background(Color.rvBackground).navigationTitle("Your matches")
        .toolbar(.visible, for: .navigationBar).navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.load() }
        .task { await store.load() }
    }
}

#Preview { NavigationStack { MatchesInboxView() }.environment(MatchStore()) }
