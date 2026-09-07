//
//  ChatView.swift
//  Raverse-ios
//

import SwiftUI

struct ChatView: View {
    let raver: RaverProfile

    @Environment(\.dismiss) private var dismiss
    @Environment(MatchStore.self) private var store

    @State private var draft = ""

    var body: some View {
        ZStack {
            Color.rvBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                messagesList
                composer
            }
            .frame(maxWidth: 440)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.rvText)
                    .frame(width: 40, height: 40)
                    .background(Color.rvSurface, in: Circle())
                    .overlay(Circle().stroke(Color.rvBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            RaverPhoto(imageName: raver.imageName)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.rvBorder, lineWidth: 1))

            VStack(alignment: .leading, spacing: 1) {
                Text(raver.name)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color.rvText)
                Text("Matched · \(raver.anthem)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                Button(role: .destructive) {
                    store.unmatch(raver)
                    dismiss()
                } label: {
                    Label("Unmatch", systemImage: "person.fill.xmark")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.rvText)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.rvBorder).frame(height: 1)
        }
    }

    // MARK: - Messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(store.thread(for: raver)) { message in
                        bubble(message).id(message.id)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .onChange(of: store.thread(for: raver).count) { _, _ in
                if let last = store.thread(for: raver).last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func bubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.isMine { Spacer(minLength: 40) }

            Text(message.text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(message.isMine ? .white : Color.rvText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.isMine ? AnyShapeStyle(Color.rvRed) : AnyShapeStyle(Color.rvSurface),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(message.isMine ? Color.clear : Color.rvBorder, lineWidth: 1)
                )

            if !message.isMine { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: message.isMine ? .trailing : .leading)
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(spacing: 12) {
            TextField("", text: $draft, prompt: Text("Message \(raver.name)…").foregroundStyle(Color.rvTextMuted))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.rvText)
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(Color.rvSurface, in: Capsule())
                .overlay(Capsule().stroke(Color.rvBorder, lineWidth: 1))
                .onSubmit(send)

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(canSend ? Color.rvRed : Color.rvRed.opacity(0.4), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.rvBorder).frame(height: 1)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard canSend else { return }
        store.send(draft, to: raver)
        draft = ""
    }
}

#Preview {
    NavigationStack {
        ChatView(raver: MatchStore.sampleRavers[0])
    }
    .environment({
        let s = MatchStore()
        s.loadIfNeeded()
        s.like(MatchStore.sampleRavers[0])
        s.lastMatch = nil
        return s
    }())
}
