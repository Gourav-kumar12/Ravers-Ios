

import SwiftUI

struct PartnerLockedView: View {
    /// Lets the paywall's CTAs jump the user to another tab (Home / Party).
    var goToStore: () -> Void = {}
    var goToParties: () -> Void = {}

    var body: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    emblem
                    heading
                    perks
                    unlockCard
                    footnote
                }
                .padding(.horizontal, 24)
                .padding(.top, 44)
                .padding(.bottom, 32)
                .frame(maxWidth: 440)
            }
        }
    }

    // MARK: - Background (black with a red glow up top)

    private var background: some View {
        ZStack {
            Color.rvBackground.ignoresSafeArea()
            RadialGradient(
                colors: [Color.rvRed.opacity(0.28), .clear],
                center: .top, startRadius: 0, endRadius: 380
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Emblem + wordmark

    private var emblem: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 92, height: 92)
                .background(
                    LinearGradient(colors: [Color.rvRed, Color.rvRedDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.rvRed.opacity(0.55), radius: 26, y: 10)

            HStack(spacing: 8) {
                Text("RAVERS PLUS")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(Color.rvRed)

                Text("MEMBERS ONLY")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.rvText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.rvRed.opacity(0.18), in: Capsule())
                    .overlay(Capsule().stroke(Color.rvRed.opacity(0.5), lineWidth: 1))
            }
        }
    }

    // MARK: - Heading

    private var heading: some View {
        VStack(spacing: 12) {
            Text("The floor knows\nits own")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

           
        }
    }

    // MARK: - Perks

    private var perks: some View {
        VStack(spacing: 0) {
            perkRow("waveform", "Taste-matched crew",
                    "Paired on the music you live in, never on a photo grid.")
            divider
            perkRow("dot.radiowaves.left.and.right", "See who's on the same floor",
                    "Spot ravers heading to the exact parties you hold passes for.")
            divider
            perkRow("bubble.left.and.bubble.right.fill", "Frequency chats",
                    "Lock in your crew and a meet point before the doors open.")
            divider
            perkRow("checkmark.seal.fill", "Verified ravers only",
                    "Everyone here has bought a drop or booked a pass. Real people, real floors.")
        }
        .padding(18)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.rvBorder, lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1).padding(.vertical, 14)
    }

    private func perkRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.rvRed)
                .frame(width: 30, height: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Unlock card

    private var unlockCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("UNLOCK RAVE SYNC")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(2.5)
                    .foregroundStyle(Color.rvRed)
                
            }

            Button(action: goToStore) {
                Text("Buy a drop")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(colors: [Color.rvRed, Color.rvRedDeep],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(color: Color.rvRed.opacity(0.4), radius: 16, y: 6)
            }
            .buttonStyle(.plain)

            Button(action: goToParties) {
                Text("Book a party pass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.rvRed)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.rvRed.opacity(0.6), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.rvSurface.opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.rvRed.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Footnote

    private var footnote: some View {
        Text("MEMBERSHIP IS EARNED, NOT SOLD SEPARATELY")
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(Color.rvTextMuted.opacity(0.7))
            .multilineTextAlignment(.center)
    }
}

#Preview {
    PartnerLockedView()
}
