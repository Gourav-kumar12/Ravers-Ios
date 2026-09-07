

import SwiftUI
import CoreImage.CIFilterBuiltins

/// The account-menu screens the Profile tab can push.
enum ProfileRoute: Hashable {
    case helpSupport
    case accountSettings

    /// Maps a menu row title to its destination, or nil if the row has none yet.
    init?(menuTitle: String) {
        switch menuTitle {
        case "Help & Support":      self = .helpSupport
        case "Accounts & Settings": self = .accountSettings
        default:                    return nil
        }
    }
}


struct ProfileView: View {
    @Environment(VaultStore.self) private var vault
    @State private var model = ProfileViewModel()
    @State private var showEditProfile = false
    @State private var ticket: UpcomingPass?
    /// Which account-menu screen to push, if any.
    @State private var route: ProfileRoute?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rvBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        header
                        emailPrompt
                        statsRow
                        upcomingSection
    
                        SettingsCard(model: model)
                        menuList
                        signOutButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .frame(maxWidth: 440)
            }
            .navigationDestination(isPresented: $showEditProfile) {
                EditProfileView(model: model)
            }
            .navigationDestination(item: $route) { route in
                switch route {
                case .helpSupport:      HelpSupportView()
                case .accountSettings:  AccountSettingsView()
                }
            }
            .sheet(item: $ticket) { pass in
                TicketQRView(pass: pass)
                    .presentationDetents([.medium, .large])
            }
        }
        .task { await model.load() }
    }

    // MARK: - Stats (Parties / Pieces owned / Crew)

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(value: "\(model.profile?.partiesCount ?? 0)", label: "PARTIES")
            // Pieces owned reflects the live vault cart / orders in real time.
            statCard(value: "\(vault.count)", label: "PIECES\nOWNED")
            statCard(value: "\(model.profile?.crewCount ?? 0)", label: "CREW")
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Color.rvText)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.rvTextMuted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rvBorder, lineWidth: 1)
        )
    }

    // MARK: - Upcoming tickets

    @ViewBuilder
    private var upcomingSection: some View {
        if !model.upcomingPasses.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("UPCOMING")
                VStack(spacing: 12) {
                    ForEach(model.upcomingPasses) { pass in
                        upcomingRow(pass)
                    }
                }
            }
        }
    }

    private func upcomingRow(_ pass: UpcomingPass) -> some View {
        HStack(spacing: 14) {
            thumbnail(pass.imageName)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(pass.eventName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.rvText)
                Text("\(pass.dateText) · \(pass.tier)")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.rvTextMuted)
            }

            Spacer()

            // Show the ticket QR to be scanned at the door.
            Button { ticket = pass } label: {
                Image(systemName: "qrcode")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.rvText)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rvBorder, lineWidth: 1)
        )
    }

    // MARK: - Been there


    // MARK: - Small shared pieces

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .heavy))
            .foregroundStyle(Color.rvText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func thumbnail(_ name: String) -> some View {
        if UIImage(named: name) != nil {
            Image(name).resizable().scaledToFill()
        } else {
            LinearGradient(colors: [Color.rvRedDeep, .black],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Hey\(firstName.map { ", \($0)" } ?? "")!")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Color.rvText)

                Button {
                    showEditProfile = true
                } label: {
                    HStack(spacing: 3) {
                        Text("Edit Profile")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Color.rvRed)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            avatar
        }
    }

    private var avatar: some View {
        Group {
            if let name = model.profile?.avatarName {
                Image(name)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.rvTextMuted)
            }
        }
        .frame(width: 52, height: 52)
        .background(Color.rvSurface)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.rvBorder, lineWidth: 1))
    }

    // MARK: - Email prompt (accented top card)

    private var emailPrompt: some View {
        let email = model.profile?.email ?? ""
        let phone = model.profile?.phone ?? ""
        let hasContact = !email.isEmpty || !phone.isEmpty

        return Button {
            showEditProfile = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: hasContact ? "envelope.fill" : "envelope.badge")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.rvRed)

                VStack(alignment: .leading, spacing: 2) {
                    Text(hasContact ? (email.isEmpty ? phone : email) : "Get tickets on email!")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.rvText)
                        .lineLimit(1)
                    Text(hasContact
                         ? (!email.isEmpty && !phone.isEmpty ? phone : "Tap to edit your contact details")
                         : "Add your email address")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.rvTextMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.rvTextMuted)
            }
            .padding(16)
            .background(Color.rvRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.rvRed.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Menu list

    private var menuList: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.menuItems.enumerated()), id: \.element.id) { index, item in
                MenuRow(item: item) {
                    route = ProfileRoute(menuTitle: item.title)
                }
                if index < model.menuItems.count - 1 {
                    Divider()
                        .overlay(Color.rvBorder)
                        .padding(.leading, 56)
                }
            }
        }
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        Button {
            // Sign out action.
        } label: {
            Text("Sign out")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.rvRed)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.rvRed.opacity(0.6), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private var firstName: String? {
        guard let name = model.profile?.displayName.split(separator: " ").first else { return nil }
        return name.prefix(1).uppercased() + name.dropFirst().lowercased()
    }
}

// MARK: - Menu row

private struct MenuRow: View {
    let item: ProfileMenuItem
    /// Tapped — the parent decides where (if anywhere) to navigate.
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.rvText)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.rvText)
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.rvTextMuted)
                    }
                }

                Spacer()

                if let badge = item.badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.rvRed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.rvRed.opacity(0.15), in: Capsule())
                }

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
}

// MARK: - Privacy & Notifications settings card

/// A grouped card with two expandable dropdowns — Privacy and Notifications.
/// Tapping a header reveals its toggle rows; toggles bind straight into the
/// shared ProfileViewModel so their state persists while the tab is alive.
private struct SettingsCard: View {
    @Bindable var model: ProfileViewModel
    @State private var privacyOpen = false
    @State private var notificationsOpen = false

    var body: some View {
        VStack(spacing: 0) {
            disclosure(
                icon: "lock.shield",
                title: "Privacy",
                subtitle: "Ghost mode, visibility & attendance",
                isOpen: $privacyOpen
            ) {
                toggleRow("Ghost mode", "Hide your profile from Partner discovery", $model.ghostMode)
                toggleRow("Show my area", "Partners see your neighbourhood, never your address", $model.showMyArea)
                toggleRow("Share attendance", "Crew can see which parties you hold passes for", $model.shareAttendance)

                if model.ghostMode {
                    Text("YOU ARE INVISIBLE ON PARTNER RIGHT NOW")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(Color.rvRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
            }

            Divider().overlay(Color.rvBorder)

            disclosure(
                icon: "bell",
                title: "Notifications",
                subtitle: "Drops, party alerts & sync requests",
                isOpen: $notificationsOpen
            ) {
                toggleRow("Drops", "New hardware and apparel releases", $model.notifyDrops)
                toggleRow("Party alerts", "New parties near you and lineup changes", $model.notifyPartyAlerts)
                toggleRow("Sync requests", "When someone wants you in their crew", $model.notifySyncRequests)
            }
        }
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Expandable header + content

    @ViewBuilder
    private func disclosure<Content: View>(
        icon: String,
        title: String,
        subtitle: String,
        isOpen: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { isOpen.wrappedValue.toggle() }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.rvText)
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

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.rvTextMuted)
                        .rotationEffect(.degrees(isOpen.wrappedValue ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen.wrappedValue {
                VStack(spacing: 16) {
                    content()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func toggleRow(_ title: String, _ subtitle: String, _ isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.rvText)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.rvRed)
        }
    }
}

// MARK: - Ticket QR sheet

/// The entry ticket for an upcoming pass — a scannable QR generated from the
/// pass code, shown at the door.
private struct TicketQRView: View {
    let pass: UpcomingPass

    var body: some View {
        ZStack {
            Color.rvBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.rvBorder)
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                VStack(spacing: 4) {
                    Text(pass.eventName)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(Color.rvText)
                    Text("\(pass.dateText) · \(pass.tier)")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.rvTextMuted)
                }

                qrImage
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(20)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                Text(pass.code)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Color.rvText)

                Text("Show this at the door to be scanned")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    /// Generates a QR code image from the pass code using Core Image.
    private var qrImage: Image {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(pass.code.utf8)
        filter.correctionLevel = "M"

        if let output = filter.outputImage,
           let cg = context.createCGImage(output, from: output.extent) {
            return Image(decorative: cg, scale: 1)
        }
        return Image(systemName: "qrcode")
    }
}

#Preview {
    ProfileView()
        .environment(VaultStore())
}
