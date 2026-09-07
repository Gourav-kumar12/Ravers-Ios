//
//  NearbyRaversView.swift
//  Raverse-ios


import SwiftUI

struct NearbyRaversView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MatchStore.self) private var store

    /// Match to chat with, set from the match banner or a card action.
    @State private var openChatWith: RaverProfile?
    @State private var showInbox = false

    var body: some View {
        ZStack {
            Color.rvBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                if let raver = store.topCandidate {
                    card(raver)
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                    actionButtons(raver)
                        .padding(.top, 20)
                    Text("A LIKE OPENS A CHAT · PASS TO KEEP TUNING")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.rvTextMuted)
                        .padding(.top, 16)
                    Spacer()
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: 440)

            if let match = store.lastMatch {
                matchBanner(match)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showInbox) {
            MatchesInboxView()
        }
        .navigationDestination(item: $openChatWith) { raver in
            ChatView(raver: raver)
        }
        .onAppear { store.loadIfNeeded() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
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

            VStack(spacing: 2) {
                Text("NEARBY RAVERS")
                    .font(.system(size: 16, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Color.rvText)
                Text("On your frequency · HSR Layout")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)
            }

            Spacer()

            Button { showInbox = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.rvText)
                        .frame(width: 40, height: 40)
                        .background(Color.rvSurface, in: Circle())
                        .overlay(Circle().stroke(Color.rvBorder, lineWidth: 1))

                    if store.matches.count > 0 {
                        Text("\(store.matches.count)")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.rvRed, in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    // MARK: - Raver card

    private func card(_ raver: RaverProfile) -> some View {
        ZStack(alignment: .bottom) {
            RaverPhoto(imageName: raver.imageName)

            // Legibility gradient behind the info block.
            LinearGradient(
                colors: [.clear, .black.opacity(0.35), .black.opacity(0.92)],
                startPoint: .center, endPoint: .bottom
            )

            info(raver)
                .padding(18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            distanceBadge(raver)
                .padding(14)
        }
    }

    private func distanceBadge(_ raver: RaverProfile) -> some View {
        Text(String(format: "%.1f km", raver.distanceKm))
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
    }

    private func info(_ raver: RaverProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(raver.name)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white)
                Text("\(raver.age)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            // Genre + artist chips wrap onto multiple lines.
            RaverWrap(spacing: 8) {
                ForEach(raver.genres, id: \.self) { tagChip($0, accent: true) }
                ForEach(raver.artists, id: \.self) { tagChip($0, accent: false) }
            }

            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 11, weight: .bold))
                Text(raver.anthem)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(Color.rvRed)

            Text(raver.bio)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tagChip(_ text: String, accent: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(accent ? Color.rvRed : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background((accent ? Color.rvRed.opacity(0.15) : Color.white.opacity(0.12)), in: Capsule())
            .overlay(Capsule().stroke(accent ? Color.rvRed.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Pass / Like

    private func actionButtons(_ raver: RaverProfile) -> some View {
        HStack(spacing: 34) {
            circleButton(icon: "xmark", tint: .white, fill: Color.rvSurface, size: 60) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    store.pass(raver)
                }
            }
            circleButton(icon: "arrow.right", tint: .white, fill: Color.rvRed, size: 72) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    store.like(raver)
                }
            }
        }
    }

    private func circleButton(icon: String, tint: Color, fill: Color, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(fill, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                .shadow(color: fill.opacity(0.5), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Match banner

    private func matchBanner(_ raver: RaverProfile) -> some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()

            VStack(spacing: 18) {
                Text("IT'S A SYNC")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(Color.rvRed)

                Text("You and \(raver.name) are on the same frequency.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.rvText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                RaverPhoto(imageName: raver.imageName)
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.rvRed, lineWidth: 3))

                VStack(spacing: 12) {
                    Button {
                        let match = raver
                        store.lastMatch = nil
                        openChatWith = match
                    } label: {
                        Text("SEND A MESSAGE")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.rvRed, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.lastMatch = nil
                    } label: {
                        Text("Keep swiping")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.rvTextMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
                .padding(.top, 4)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(Color.rvTextMuted)
            Text("No more ravers nearby")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Color.rvText)
            Text("You've tuned through everyone on your frequency for now. Check your matches or come back later.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.rvTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if !store.matches.isEmpty {
                Button { showInbox = true } label: {
                    Text("VIEW MATCHES")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .frame(height: 48)
                        .background(Color.rvRed, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            Spacer()
        }
    }
}

// MARK: - Raver photo (gradient fallback when no asset)

/// Shows the raver's photo if the named asset exists, otherwise a branded
/// gradient placeholder with an initial — so sample data renders cleanly until
/// real portraits are added.
struct RaverPhoto: View {
    let imageName: String

    var body: some View {
        if UIImage(named: imageName) != nil {
            Image(imageName)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [Color.rvRedDeep, .black],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.18))
            )
        }
    }
}

// MARK: - Wrapping layout for card chips

private struct RaverWrap: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        NearbyRaversView()
    }
    .environment({ let s = MatchStore(); s.loadIfNeeded(); return s }())
}
