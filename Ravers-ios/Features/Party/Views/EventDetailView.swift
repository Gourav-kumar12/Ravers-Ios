//
//  EventDetailView.swift
//  Raverse-ios
//
//  Event detail (Screen 5). Hero, date/time, venue + distance, an active-pass
//  card, the LINEUP, a "THE ROOM" blurb with attendees, and a chat preview.
//

import SwiftUI

struct EventDetailView: View {
    let event: Event

    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var vault
    @State private var isSaved = false
    /// Set when the user books a pass on this screen (also unlocks Partner).
    @State private var justBooked = false

    /// True if the user already holds a pass for this event, or just booked one.
    private var hasPass: Bool { event.heldPass != nil || justBooked }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                hero

                VStack(alignment: .leading, spacing: 22) {
                    dateTimeRow
                    title
                    locationRow
                    if let pass = event.heldPass { passActiveCard(pass) }
                    if !event.lineup.isEmpty { lineupSection }
                    if let about = event.about { aboutSection(about) }
                    if let chat = event.chatPreview { chatCard(chat) }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: 440)
        }
        .background(Color.rvBackground)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { passBar }
    }

    // MARK: - Get pass CTA

    private var passBar: some View {
        Button {
            guard !hasPass else { return }
            withAnimation(.easeInOut(duration: 0.2)) { justBooked = true }
            vault.bookTicket()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: hasPass ? "checkmark.circle.fill" : "ticket.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(hasPass ? "PASS SECURED" : "GET PASS · FROM ₹\(event.fromPrice)")
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(hasPass ? Color.rvSurface : Color.rvRed,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(hasPass ? Color.rvBorder : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(hasPass)
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .top) {
            heroImage
                .frame(height: 240)
                .clipped()

            // Fade the bottom of the image into the page background.
            LinearGradient(
                colors: [.black.opacity(0.55), .clear, .clear, Color.rvBackground],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 340)

            HStack {
                circleButton(system: "chevron.left") { dismiss() }
                Spacer()
                circleButton(system: isSaved ? "bookmark.fill" : "bookmark",
                             tint: isSaved ? .rvRed : .rvText) { isSaved.toggle() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
        }
    }

    @ViewBuilder
    private var heroImage: some View {
        if UIImage(named: event.imageName) != nil {
            Image(event.imageName).resizable().scaledToFill()
        } else {
            LinearGradient(colors: [Color.rvRedDeep, .black],
                           startPoint: .topTrailing, endPoint: .bottomLeading)
                .overlay(
                    RadialGradient(colors: [Color.rvRed.opacity(0.55), .clear],
                                   center: .init(x: 0.6, y: 0.35),
                                   startRadius: 8, endRadius: 260)
                )
        }
    }

    private func circleButton(system: String, tint: Color = .rvText,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.45), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date / time

    private var dateTimeRow: some View {
        HStack {
            Text(dateBadge)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.rvText)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.06), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))

            Spacer()

            if let start = event.startTimeText, let end = event.endTimeText {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(start) TO \(end)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                }
                .foregroundStyle(Color.rvTextMuted)
            }
        }
    }

    private var title: some View {
        Text(event.name)
            .font(.system(size: 32, weight: .black))
            .foregroundStyle(Color.rvText)
    }

    private var locationRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.rvRed)
            Text(locationText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.rvTextMuted)
        }
    }

    // MARK: - Active pass card

    private func passActiveCard(_ pass: HeldPass) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "qrcode")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.rvRed, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("PASS ACTIVE")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(Color.rvText)
                Text("\(pass.tierName) · \(pass.entries) entry · \(pass.code)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.rvTextMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button { } label: {
                Text("SHOW\nQR")
                    .font(.system(size: 11, weight: .bold))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Color.rvText)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.rvRed.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rvRed.opacity(0.55), lineWidth: 1)
        )
    }

    // MARK: - Lineup

    private var lineupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("LINEUP")

            VStack(spacing: 0) {
                ForEach(Array(event.lineup.enumerated()), id: \.element.id) { index, slot in
                    HStack(spacing: 18) {
                        Text(slot.time)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.rvTextMuted)
                            .frame(width: 44, alignment: .leading)
                        Text(slot.artist)
                            .font(.system(size: 14, weight: slot.isHeadline ? .heavy : .regular))
                            .foregroundStyle(Color.rvText)
                        Spacer()
                    }
                    .padding(.vertical, 14)

                    if index < event.lineup.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - About / attendees

    private func aboutSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(event.aboutTitle)

            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.rvTextMuted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if let going = event.goingCount {
                HStack(spacing: 10) {
                    avatarStack
                    HStack(spacing: 5) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("\(going) going")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color.rvTextMuted)
                }
            }
        }
    }

    private var avatarStack: some View {
        HStack(spacing: -10) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(LinearGradient(colors: [Color.rvRed, Color.rvRedDeep],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.85))
                    )
                    .overlay(Circle().stroke(Color.rvBackground, lineWidth: 2))
                    .zIndex(Double(3 - i))
            }
        }
    }

    // MARK: - Chat preview

    private func chatCard(_ chat: ChatPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.rvRed)
                    Text("FREQUENCY CHAT")
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(0.5)
                        .foregroundStyle(Color.rvText)
                }
                Spacer()
                Text(chat.isOpen ? "OPEN" : "CLOSED")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.rvTextMuted)
            }

            HStack(spacing: 10) {
                Circle()
                    .fill(LinearGradient(colors: [Color.rvRed, Color.rvRedDeep],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.85))
                    )
                Text("\(chat.lastSender): ") .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.rvText)
                 Text(chat.lastMessage)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.rvTextMuted)
            }
            .lineLimit(1)
        }
        .padding(16)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .heavy))
            .tracking(0.5)
            .foregroundStyle(Color.rvText)
    }

    private var dateBadge: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM"
        return f.string(from: event.date).uppercased()
    }

    private var locationText: String {
        if let km = event.distanceKm {
            return "\(event.venue) · \(String(format: "%.1f", km)) km away"
        }
        return "\(event.venue), \(event.city)"
    }
}

#Preview {
    NavigationStack {
        EventDetailView(
            event: Event(
                id: "x", name: "VOID FREQUENCY",
                venue: "Warehouse 7, Peenya Industrial Area", city: "Bengaluru",
                distanceKm: 14.2, date: .now, genres: ["Techno", "Industrial"],
                fromPrice: 799, imageName: "party-1",
                passes: [],
                startTimeText: "21:00", endTimeText: "04:00",
                lineup: [
                    LineupSlot(time: "21:00", artist: "NULLPOINT"),
                    LineupSlot(time: "23:00", artist: "Tremor Kaur"),
                    LineupSlot(time: "01:00", artist: "ARKA"),
                    LineupSlot(time: "03:00", artist: "ARKA b2b NULLPOINT", isHeadline: true)
                ],
                about: "Raw industrial techno inside a working warehouse. One room, one system, zero phones on the floor. Strict door, pass and ID only.",
                goingCount: 412,
                heldPass: HeldPass(tierName: "Phase 1", entries: 1, code: "RV70CS02XN5H2V"),
                chatPreview: ChatPreview(isOpen: true, lastSender: "Aarav",
                                         lastMessage: "Earplugs at the bar are free this time. Take them.")
            )
        )
        .environment(VaultStore())
    }
}
