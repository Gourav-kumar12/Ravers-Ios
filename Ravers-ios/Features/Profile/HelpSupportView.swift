
import SwiftUI

struct HelpSupportView: View {
    @Environment(\.dismiss) private var dismiss

    /// Which FAQ / legal section is currently expanded (nil = all collapsed).
    @State private var openSection: String?

    var body: some View {
        ZStack {
            Color.rvBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    topBar
                    intro
                    contactCard
                    faqSection
                    legalSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: 440)
        }
        .toolbar(.hidden, for: .navigationBar)
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

            Text("Help & Support")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Color.rvText)

            Spacer()

            // Balances the back button so the title stays centred.
            Color.clear.frame(width: 40, height: 40)
        }
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("We've got you.")
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(Color.rvText)
            Text("Trouble with a pass, an order or your account? Reach the crew below or scan the common questions — most answers are a tap away.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.rvTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Contact options

    private var contactCard: some View {
        VStack(spacing: 0) {
            contactRow(icon: "bubble.left.and.bubble.right.fill",
                       title: "Live chat",
                       subtitle: "Typically replies in a few minutes")
            Divider().overlay(Color.rvBorder).padding(.leading, 56)
            contactRow(icon: "envelope.fill",
                       title: "Email us",
                       subtitle: "support@theravers.app")
            Divider().overlay(Color.rvBorder).padding(.leading, 56)
            contactRow(icon: "phone.fill",
                       title: "Call the crew",
                       subtitle: "Mon–Sun · 10am to 2am IST")
        }
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func contactRow(icon: String, title: String, subtitle: String) -> some View {
        Button {
            // Contact action (deep-link to chat / mail / dialer).
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.rvRed)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.rvText)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.rvTextMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.rvTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - FAQs

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("COMMON QUESTIONS")
            VStack(spacing: 0) {
                ForEach(Array(faqs.enumerated()), id: \.element.q) { index, item in
                    expandable(title: item.q, body: item.a)
                    if index < faqs.count - 1 {
                        Divider().overlay(Color.rvBorder)
                    }
                }
            }
            .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private let faqs: [(q: String, a: String)] = [
        ("Where is my ticket?",
         "Every pass you hold lives under Your Passes on the Profile tab. Open a pass to show its QR at the door — no printout needed."),
        ("Can I get a refund?",
         "Passes are non-refundable once a party is live, but you can transfer a pass to a crew member up to 24 hours before doors open."),
        ("How do I change my phone number?",
         "Head to Accounts & Settings and update your contact details. You'll verify the new number with a one-time code."),
        ("A payment failed — what now?",
         "No money leaves your account on a failed charge. Retry with another method from Accounts & Settings, or reach the crew above.")
    ]

    // MARK: - Legal

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("LEGAL")
            VStack(spacing: 0) {
                expandable(title: "Terms & Conditions", body: Self.termsText)
                Divider().overlay(Color.rvBorder)
                expandable(title: "Privacy Policy", body: Self.privacyText)
            }
            .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            Text("THE RAVERS · v1.0 · Made for the night")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Color.rvTextMuted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
        }
    }

    // MARK: - Shared expandable row

    @ViewBuilder
    private func expandable(title: String, body text: String) -> some View {
        let isOpen = openSection == title
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    openSection = isOpen ? nil : title
                }
            } label: {
                HStack(spacing: 14) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.rvText)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 12)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.rvTextMuted)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                Text(text)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.rvTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(Color.rvTextMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Long-form copy

    private static let termsText = """
    By creating an account and using THE RAVERS you agree to these terms.

    1. Passes & Entry. A pass grants entry to a single event for a single person, subject to the venue's age and conduct rules. Management reserves the right to refuse entry. Passes are non-transferable once scanned.

    2. Payments. All charges are processed by our payment partners. Prices include applicable taxes unless stated. You are responsible for keeping your payment details accurate.

    3. Conduct. We run a zero-tolerance policy on harassment and unsafe behaviour. Breaching venue or community rules may result in removal without refund and suspension of your account.

    4. Content & Privacy. Photos and video may be captured at events for promotion. Your personal data is handled per our Privacy Policy.

    5. Changes. Events may be rescheduled or cancelled. In the event of a cancellation you will be offered a credit or refund to the original payment method.

    6. Liability. THE RAVERS is not liable for personal belongings, or for injury arising from misuse of a venue or its facilities.

    These terms may be updated from time to time. Continued use of the app means you accept the current version.
    """

    private static let privacyText = """
    We collect only what we need to get you into the party: your name, contact details, the passes you hold and how you use the app.

    We never sell your data. Payment details are tokenised by our payment partners and are not stored on our servers. You can request export or deletion of your data at any time from Accounts & Settings, or by emailing support@theravers.app.

    Location is used only to surface nearby parties and drops, and only while the app is in use. You can turn this off in your device settings at any time.
    """
}

#Preview {
    NavigationStack {
        HelpSupportView()
    }
}
