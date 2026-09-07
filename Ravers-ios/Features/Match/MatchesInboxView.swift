//
//  MatchesInboxView.swift
//  Raverse-ios
//


import SwiftUI

struct MatchesInboxView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MatchStore.self) private var store

    @State private var openChatWith: RaverProfile?

    var body: some View {
        ZStack {
            Color.rvBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                if store.matches.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(store.matches) { raver in
                                Button { openChatWith = raver } label: {
                                    row(raver)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                        .padding(.bottom, 28)
                    }
                }
            }
            .frame(maxWidth: 440)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $openChatWith) { raver in
            ChatView(raver: raver)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.rvText)
                    .frame(width: 40, height: 40)
                    .background(Color.rvSurface, in: Circle())
                    .overlay(Circle().stroke(Color.rvBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("MATCHES")
                .font(.system(size: 16, weight: .heavy))
                .tracking(1)
                .foregroundStyle(Color.rvText)

            Spacer()

            Text("\(store.matches.count)")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.rvRed)
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    // MARK: - Match row

    private func row(_ raver: RaverProfile) -> some View {
        HStack(spacing: 14) {
            RaverPhoto(imageName: raver.imageName)
                .frame(width: 58, height: 58)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.rvBorder, lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text("\(raver.name), \(raver.age)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.rvText)
                Text(lastLine(raver))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                Button(role: .destructive) {
                    store.unmatch(raver)
                } label: {
                    Label("Unmatch", systemImage: "person.fill.xmark")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.rvTextMuted)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(12)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rvBorder, lineWidth: 1)
        )
    }

    /// The most recent message, or the anthem if the thread is fresh.
    private func lastLine(_ raver: RaverProfile) -> String {
        if let last = store.thread(for: raver).last {
            return (last.isMine ? "You: " : "") + last.text
        }
        return raver.anthem
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(Color.rvTextMuted)
            Text("No matches yet")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Color.rvText)
            Text("Like a raver in discovery to start a chat here.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.rvTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        MatchesInboxView()
    }
    .environment({
        let s = MatchStore()
        s.loadIfNeeded()
        if let first = s.candidates.first { s.like(first); s.lastMatch = nil }
        return s
    }())
}
