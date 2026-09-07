

import SwiftUI

struct EditProfileView: View {
    /// The shared profile model. On save we write `draft` back into it.
    let model: ProfileViewModel

    @Environment(\.dismiss) private var dismiss

    /// Local, editable copy so changes only commit on Save.
    @State private var draft: UserProfile

    init(model: ProfileViewModel) {
        self.model = model
        _draft = State(initialValue: model.profile ?? UserProfile(
            id: "me", displayName: "", handle: "@", email: "", phone: "",
            city: "", memberSince: "", avatarName: "", personality: "",
            genres: [], venues: [], favoriteArtists: [],
            partiesCount: 0, piecesOwned: 0, crewCount: 0
        ))
    }

    var body: some View {
        ZStack {
            Color.rvBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    topBar
                    headerPreview
                    detailsSection
                    personalitySection
                    musicTasteSection
                    venueSection
                    saveButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: 440)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Top bar (back + Save)

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

            Text("Edit Profile")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Color.rvText)

            Spacer()

            Button { save() } label: {
                Text("Save")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.rvRed)
                    .frame(width: 52, height: 40)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Live header preview (matches the design reference)

    private var headerPreview: some View {
        HStack(alignment: .top, spacing: 16) {
            avatar

            VStack(alignment: .leading, spacing: 8) {
                Text(draft.displayName.isEmpty ? "Your name" : draft.displayName)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Color.rvText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("\(draft.handle) · since \(draft.memberSince)")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.rvTextMuted)

                Text(draft.city)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.rvTextMuted)

                if !draft.personality.isEmpty {
                    FlowChips(items: [draft.personality], accent: true)
                        .padding(.top, 2)
                }
                if !draft.genres.isEmpty {
                    FlowChips(items: draft.genres, accent: false)
                }
                if !draft.venues.isEmpty {
                    FlowChips(items: draft.venues, accent: false)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.rvBorder, lineWidth: 1)
        )
    }

    private var avatar: some View {
        Group {
            if UIImage(named: draft.avatarName) != nil {
                Image(draft.avatarName).resizable().scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.rvTextMuted)
            }
        }
        .frame(width: 76, height: 76)
        .background(Color.rvBackground)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.rvBorder, lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
            // Camera badge hinting the avatar is editable.
            Image(systemName: "camera.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.rvText)
                .frame(width: 26, height: 26)
                .background(Color.rvRed, in: Circle())
                .overlay(Circle().stroke(Color.rvBackground, lineWidth: 2))
        }
    }

    // MARK: - Editable text fields

    private var detailsSection: some View {
        VStack(spacing: 14) {
            field(
                title: "Display name",
                text: $draft.displayName,
                placeholder: "Your name",
                icon: "person",
                keyboard: .default,
                capitalization: .words
            )
            field(
                title: "Email",
                text: $draft.email,
                placeholder: "you@email.com",
                icon: "envelope",
                keyboard: .emailAddress,
                capitalization: .never
            )
            field(
                title: "Phone number",
                text: $draft.phone,
                placeholder: "+91 00000 00000",
                icon: "phone",
                keyboard: .phonePad,
                capitalization: .never
            )
        }
    }

    private func field(
        title: String,
        text: Binding<String>,
        placeholder: String,
        icon: String,
        keyboard: UIKeyboardType,
        capitalization: TextInputAutocapitalization
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.rvTextMuted)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)
                    .frame(width: 20)

                TextField(placeholder, text: text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.rvText)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.rvBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Personality (single-select)

    private var personalitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("PERSONALITY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.rvTextMuted)
                Text("Pick the one that's most you")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted.opacity(0.7))
            }

            FlowLayout(spacing: 10) {
                ForEach(model.personalityOptions, id: \.self) { option in
                    let selected = draft.personality == option
                    Button {
                        // Single-select: tap toggles this option on (or off if re-tapped).
                        draft.personality = selected ? "" : option
                    } label: {
                        Text(option)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selected ? Color.white : Color.rvText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(selected ? Color.rvRed : Color.rvSurface)
                            )
                            .overlay(
                                Capsule().stroke(
                                    selected ? Color.rvRed : Color.rvBorder,
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Music taste (multi-select genres)

    private var musicTasteSection: some View {
        multiSelectSection(
            title: "MUSIC TASTE",
            subtitle: "Pick the sounds you love",
            options: model.genreOptions,
            selection: $draft.genres
        )
    }

    // MARK: - Venue / vibe (multi-select)

    private var venueSection: some View {
        multiSelectSection(
            title: "VENUE",
            subtitle: "Where you like to lose yourself",
            options: model.venueOptions,
            selection: $draft.venues
        )
    }

    /// A titled section of tappable pill chips backed by a `[String]` selection.
    /// Tapping toggles an option in or out of the bound array (multi-select).
    private func multiSelectSection(
        title: String,
        subtitle: String,
        options: [String],
        selection: Binding<[String]>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.rvTextMuted)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted.opacity(0.7))
            }

            FlowLayout(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    let selected = selection.wrappedValue.contains(option)
                    Button {
                        if selected {
                            selection.wrappedValue.removeAll { $0 == option }
                        } else {
                            selection.wrappedValue.append(option)
                        }
                    } label: {
                        Text(option)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selected ? Color.white : Color.rvText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(selected ? Color.rvRed : Color.rvSurface)
                            )
                            .overlay(
                                Capsule().stroke(
                                    selected ? Color.rvRed : Color.rvBorder,
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Save

    private var saveButton: some View {
        Button { save() } label: {
            Text("Save changes")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.rvRed, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Actions

    /// Commit the draft into the shared model. Because ProfileViewModel is
    /// @Observable, the Profile tab re-renders with the new values immediately.
    private func save() {
        model.profile = draft
        dismiss()
    }
}

// MARK: - Chips

/// A wrapping row of read-only pill chips used inside the header preview.
/// Red-tinted when `accent`, otherwise a plain surface pill.
private struct FlowChips: View {
    let items: [String]
    let accent: Bool

    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent ? Color.rvRed : Color.rvText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(accent ? Color.rvRed.opacity(0.12) : Color.rvSurface)
                    )
                    .overlay(
                        Capsule().stroke(accent ? Color.rvRed.opacity(0.55) : Color.rvBorder, lineWidth: 1)
                    )
            }
        }
    }
}

/// Minimal flow layout that wraps its children onto multiple lines.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    let model = ProfileViewModel()
    return NavigationStack {
        EditProfileView(model: model)
            .task { await model.load() }
    }
}
