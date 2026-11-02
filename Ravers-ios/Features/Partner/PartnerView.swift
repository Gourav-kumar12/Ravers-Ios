import SwiftUI

struct PartnerView: View {
    var goToProfile: () -> Void = {}
    @Environment(MatchStore.self) private var store
    @Environment(ProfileViewModel.self) private var profile
    @State private var openChat: RaverProfile?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FIND YOUR CREW").font(.system(size: 28, weight: .black))
                            Text("Same music. New connections.").foregroundStyle(Color.rvTextMuted)
                        }
                        Spacer(minLength: 8)
                        NavigationLink {
                            MatchesInboxView()
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: "person.2.fill").font(.title3)
                                Text("\(store.matches.count) matches").font(.caption)
                            }
                            .padding(12).background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .accessibilityLabel("View matches, \(store.matches.count)")
                    }
                    if !profile.isLoading && (profile.ghostMode || profile.profile?.displayName.isEmpty != false) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Let your crew find you").font(.headline)
                            Text("Complete your profile and turn off Ghost mode so other members can swipe on you.")
                                .font(.footnote).foregroundStyle(Color.rvTextMuted)
                            Button("Update my profile", action: goToProfile).font(.subheadline.bold())
                        }
                    }
                    if let error = store.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(error).font(.footnote).foregroundStyle(Color.rvTextMuted)
                            Button("Retry live discovery") { Task { await store.load() } }
                        }
                    }
                    if let matched = store.lastMatch {
                        Button { openChat = matched; store.lastMatch = nil } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("You matched with \(matched.name)", systemImage: "sparkles").font(.headline)
                                Text("Chat unlocks 3 hours after matching. View your connection.").font(.footnote)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                            .background(Color.rvRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    } else if let notice = store.notice {
                        Text(notice).font(.footnote).foregroundStyle(Color.rvTextMuted)
                    }
                    if store.showingSamples {
                        Label("SAMPLE PROFILES", systemImage: "sparkles")
                            .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1)
                            .foregroundStyle(Color.rvRed)
                        Text("Try swiping with sample ravers. Real profiles appear here when other members are discoverable.")
                            .font(.footnote).foregroundStyle(Color.rvTextMuted)
                    }
                    if let raver = store.topCandidate {
                        SwipeRaverCard(raver: raver, isBusy: store.isBusy,
                                       onPass: { Task { await store.pass(raver) } },
                                       onLike: { Task { await store.like(raver) } })
                            .id(raver.id)
                    } else {
                        ContentUnavailableView("You're all caught up", systemImage: "waveform",
                                               description: Text("Check back for new ravers, or explore your matches."))
                        Button("Try sample profiles again") { store.resetSamplePasses() }
                    }
                    if store.isBusy { ProgressView().frame(maxWidth: .infinity).tint(.rvRed) }
                    Text("Real connections need two right swipes. Messages unlock 3 hours after a mutual match.")
                        .font(.footnote).foregroundStyle(Color.rvTextMuted)
                }
                .padding(18).frame(maxWidth: 480)
            }
            .background(Color.rvBackground).foregroundStyle(Color.rvText)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $openChat) { ChatView(raver: $0) }
            .refreshable { await store.load() }
            .task {
                while !Task.isCancelled {
                    await store.load()
                    do { try await Task.sleep(for: .seconds(8)) } catch { break }
                }
            }
        }
    }
}

private struct SwipeRaverCard: View {
    let raver: RaverProfile
    let isBusy: Bool
    let onPass: () -> Void
    let onLike: () -> Void
    @State private var dragX: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottomLeading) {
                RaverPortrait(raver: raver)
                LinearGradient(colors: [.clear, .black.opacity(0.95)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 10) {
                    if abs(dragX) > 30 {
                        Text(dragX > 0 ? "LIKE" : "PASS").font(.title.bold())
                            .foregroundStyle(dragX > 0 ? Color.green : Color.rvRed)
                    }
                    HStack {
                        Text(raver.name + (raver.age > 0 ? ", \(raver.age)" : ""))
                            .font(.system(size: 30, weight: .heavy))
                        if raver.isDemo { Text("SAMPLE").font(.caption.bold()).padding(6).background(.white.opacity(0.15), in: Capsule()) }
                    }
                    if let city = raver.city, !city.isEmpty { Label(city, systemImage: "mappin").font(.subheadline) }
                    Text(raver.genres.joined(separator: " · ")).font(.subheadline.bold()).foregroundStyle(Color.rvRed)
                    if !raver.artists.isEmpty { Text(raver.artists.joined(separator: " · ")).font(.footnote) }
                    if !raver.bio.isEmpty { Text(raver.bio).font(.subheadline).lineLimit(4) }
                }
                .padding(22)
            }
            .foregroundStyle(.white).frame(height: 420)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .offset(x: reduceMotion ? 0 : dragX)
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(dragX / 24)))
            .gesture(DragGesture(minimumDistance: 20)
                .onChanged { value in
                    if !isBusy, abs(value.translation.width) > abs(value.translation.height) { dragX = value.translation.width }
                }
                .onEnded { value in
                    if !isBusy, abs(value.translation.width) > abs(value.translation.height) {
                        if value.translation.width > 80 { onLike() }
                        else if value.translation.width < -80 { onPass() }
                    }
                    withAnimation(.easeOut(duration: 0.2)) { dragX = 0 }
                })
            HStack(spacing: 32) {
                action("Pass", icon: "xmark", color: .rvTextMuted, perform: onPass)
                Text("LEFT TO PASS\nRIGHT TO LIKE").font(.system(size: 10, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center).foregroundStyle(Color.rvTextMuted)
                action("Like", icon: "heart.fill", color: .rvRed, perform: onLike)
            }
            .disabled(isBusy)
        }
    }
    private func action(_ title: String, icon: String, color: Color, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Image(systemName: icon).font(.title2.bold()).foregroundStyle(color)
                .frame(width: 62, height: 62).background(Color.rvSurface, in: Circle())
                .overlay(Circle().stroke(color.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain).accessibilityLabel("\(title) \(raver.name)")
    }
}

#Preview { PartnerView().environment(MatchStore()).environment(ProfileViewModel()) }
