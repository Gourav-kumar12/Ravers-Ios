import SwiftUI

struct ChatView: View {
    let raver: RaverProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(MatchStore.self) private var store
    @State private var draft = ""
    @State private var requestID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            if raver.isDemo {
                Text(store.samplesSavedToAccount ? "Sample connection. Messages are saved to your account." : "Sample connection. Messages stay on this device.")
                    .font(.footnote).foregroundStyle(Color.rvTextMuted).padding(12)
            }
            if let date = store.chatUnlockDate(for: raver) {
                ChatUnlockLabel(date: date).font(.footnote.bold()).foregroundStyle(Color.rvRed).padding(12)
            } else {
                Text("This match is no longer available.").foregroundStyle(Color.rvTextMuted).padding()
            }
            if let error = store.errorMessage {
                Text(error).font(.footnote).foregroundStyle(Color.rvTextMuted).padding(.horizontal)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if store.thread(for: raver).isEmpty {
                            Text("A new connection starts here. Chat opens 3 hours after matching.")
                                .font(.subheadline).foregroundStyle(Color.rvTextMuted).padding(24)
                        }
                        ForEach(store.thread(for: raver)) { message in
                            SocialMessageBubble(text: message.text, isMine: message.isMine,
                                                sender: message.isMine ? "You" : raver.name, sentAt: message.sentAt)
                                .id(message.id)
                        }
                    }.padding(16)
                }
                .onChange(of: store.thread(for: raver).last?.id, initial: true) { _, id in
                    if let id { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                SocialChatComposer(draft: $draft, enabled: store.canChat(with: raver, at: context.date),
                                   isSending: store.isSending) { Task { await send() } }
            }
        }
        .frame(maxWidth: 480).frame(maxWidth: .infinity).background(Color.rvBackground)
        .navigationTitle(raver.name).navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Unmatch", systemImage: "person.fill.xmark", role: .destructive) {
                        Task { if await store.unmatch(raver) { dismiss() } }
                    }.disabled(store.isBusy)
                } label: { Image(systemName: "ellipsis") }
            }
        }
        .onChange(of: draft) { _, _ in if !store.isSending { requestID = UUID() } }
        .task {
            while !Task.isCancelled {
                await store.load()
                await store.loadMessages(for: raver)
                do { try await Task.sleep(for: .seconds(4)) } catch { break }
            }
        }
    }
    private func send() async {
        if await store.send(draft, to: raver, id: requestID) {
            draft = ""
            requestID = UUID()
        }
    }
}

struct SocialMessageBubble: View {
    let text: String
    let isMine: Bool
    let sender: String
    let sentAt: Date
    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 36) }
            VStack(alignment: .leading, spacing: 5) {
                if !isMine { Text(sender).font(.caption.bold()).foregroundStyle(Color.rvRed) }
                Text(text).font(.body).textSelection(.enabled)
                Text(sentAt, style: .time).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(13).foregroundStyle(Color.rvText)
            .background(isMine ? Color.rvRedDeep : Color.rvSurface, in: RoundedRectangle(cornerRadius: 16))
            if !isMine { Spacer(minLength: 36) }
        }
    }
}

struct SocialChatComposer: View {
    @Binding var draft: String
    let enabled: Bool
    let isSending: Bool
    let onSend: () -> Void
    private var canSend: Bool {
        enabled && !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.count <= 2000
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if draft.count > 2000 { Text("Messages can contain up to 2,000 characters.").font(.caption).foregroundStyle(Color.rvRed) }
            HStack(spacing: 12) {
                TextField(enabled ? "Write a message…" : "Chat is locked", text: $draft, axis: .vertical)
                    .lineLimit(1...4).padding(13).foregroundStyle(Color.rvText)
                    .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 18))
                    .disabled(!enabled || isSending).accessibilityLabel("Message")
                Button(action: onSend) {
                    if isSending { ProgressView().tint(.white).frame(width: 46, height: 46) }
                    else { Image(systemName: "arrow.up").font(.headline).frame(width: 46, height: 46) }
                }
                .foregroundStyle(.white).background(canSend ? Color.rvRed : Color.rvSurface, in: Circle())
                .disabled(!canSend).accessibilityLabel("Send message")
            }
        }
        .padding(14).background(Color.rvBackground)
    }
}

#Preview { NavigationStack { ChatView(raver: MatchStore.sampleRavers[0]) }.environment(MatchStore()) }
