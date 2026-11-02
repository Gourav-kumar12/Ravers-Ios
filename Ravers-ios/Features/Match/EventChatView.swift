import SwiftUI

struct EventChatView: View {
    let event: Event
    @State private var store: EventChatStore
    @State private var draft = ""
    @State private var requestID = UUID()

    init(event: Event) {
        self.event = event
        _store = State(initialValue: EventChatStore(eventID: event.id))
    }
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(event.name).font(.headline)
                if let room = store.room {
                    Label("\(room.memberCount) ticket holders", systemImage: "ticket.fill")
                        .font(.caption).foregroundStyle(Color.rvRed)
                } else { Text("Only ticket holders for this event can join.").font(.caption).foregroundStyle(Color.rvTextMuted) }
            }.padding(14)
            if let error = store.errorMessage {
                Text(error).font(.footnote).foregroundStyle(Color.rvTextMuted).padding(.horizontal)
                Button("Retry group access") { Task { await store.load() } }.padding(8)
            }
            if store.isLoading && store.room == nil { ProgressView().tint(.rvRed).padding() }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if store.room != nil && store.messages.isEmpty {
                            ContentUnavailableView("Start the conversation", systemImage: "bubble.left.and.bubble.right",
                                description: Text("Meet the people heading to \(event.name)."))
                        }
                        ForEach(store.messages) { message in
                            SocialMessageBubble(text: message.text, isMine: message.isMine,
                                                sender: message.senderName, sentAt: message.sentAt).id(message.id)
                        }
                    }.padding(16)
                }
                .refreshable { await store.load() }
                .onChange(of: store.messages.last?.id, initial: true) { _, id in
                    if let id { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
            SocialChatComposer(draft: $draft, enabled: store.room != nil, isSending: store.isSending) {
                Task {
                    if await store.send(draft, id: requestID) { draft = ""; requestID = UUID() }
                }
            }
        }
        .frame(maxWidth: 480).frame(maxWidth: .infinity).background(Color.rvBackground)
        .navigationTitle("Event group").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onChange(of: draft) { _, _ in if !store.isSending { requestID = UUID() } }
        .task {
            while !Task.isCancelled {
                await store.load()
                do { try await Task.sleep(for: .seconds(4)) } catch { break }
            }
        }
    }
}
