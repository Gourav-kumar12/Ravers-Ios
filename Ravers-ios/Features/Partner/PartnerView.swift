
import SwiftUI
import PhotosUI

struct PartnerView: View {
    @State private var model = PartnerViewModel()

    // Photo picker selections — loaded into the model as Data on change.
    @State private var pick1: PhotosPickerItem?
    @State private var pick2: PhotosPickerItem?
    @State private var showDiscovery = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rvBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        intro
                        progressBar
                        photosSection
                        chipSection("GENRES YOU LIVE IN", options: model.genreOptions, selection: \.genres)
                        chipSection("ARTISTS AND DJS", options: model.artistOptions, selection: \.artists)
                        chipSection("PARTY STYLES", options: model.partyStyleOptions, selection: \.partyStyles)
                        continueButton
                        lockNote
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: 440)
            }
            .navigationDestination(isPresented: $showDiscovery) {
                NearbyRaversView()
            }
        }
        .task { await model.load() }
        .onChange(of: pick1) { _, item in load(item, into: \.photo1) }
        .onChange(of: pick2) { _, item in load(item, into: \.photo2) }
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RAVE SYNC")
                .font(.system(size: 30, weight: .heavy))
                .tracking(1)
                .foregroundStyle(Color.rvText)
            Text("Set your frequency before you scan. Rave Sync runs on taste, never on looks.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.rvTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Progress meter

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.rvSurface)
                    Capsule()
                        .fill(LinearGradient(colors: [.rvRed, .rvRedDeep],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(model.tunedCount) / CGFloat(model.totalSteps))
                }
            }
            .frame(height: 6)

            Text("\(model.tunedCount) OF \(model.totalSteps) TUNED")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color.rvTextMuted)
        }
    }

    // MARK: - Two clear photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("TWO CLEAR PHOTOS")
            Text("Both slots are required before discovery opens. Face the light, strobes do the rest.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.rvTextMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                photoSlot(index: 1, data: model.photo1, pick: $pick1)
                photoSlot(index: 2, data: model.photo2, pick: $pick2)
            }
        }
    }

    private func photoSlot(index: Int, data: Data?, pick: Binding<PhotosPickerItem?>) -> some View {
        PhotosPicker(selection: pick, matching: .images, photoLibrary: .shared()) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.rvSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(data == nil ? Color.rvRed.opacity(0.4) : Color.rvBorder,
                                    style: StrokeStyle(lineWidth: 1.5, dash: data == nil ? [6] : []))
                    )

                if let data, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(Color.rvText)
                        Text("Photo \(index)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.rvText)
                        Text("REQUIRED")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(Color.rvRed)
                    }
                }
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Chip sections

    private func chipSection(
        _ title: String,
        options: [String],
        selection: ReferenceWritableKeyPath<PartnerViewModel, Set<String>>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(title)
            ChipFlowLayout(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    chip(option, selected: model[keyPath: selection].contains(option)) {
                        model.toggle(option, in: selection)
                    }
                }
            }
        }
    }

    private func chip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? .black : Color.rvText)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(selected ? Color.rvRed : Color.rvSurface,
                            in: Capsule())
                .overlay(
                    Capsule().stroke(selected ? Color.rvRed : Color.rvBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Continue + lock note

    private var continueButton: some View {
        Button {
            // Unlock discovery once both photos are added.
            showDiscovery = true
        } label: {
            Text(model.bothPhotosAdded ? "OPEN DISCOVERY" : "ADD BOTH PHOTOS TO CONTINUE")
                .font(.system(size: 14, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(model.bothPhotosAdded ? Color.rvRed : Color.rvRed.opacity(0.4),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!model.bothPhotosAdded)
        .padding(.top, 6)
    }

    private var lockNote: some View {
        Text("DISCOVERY STAYS LOCKED UNTIL YOUR FREQUENCY IS SET")
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Color.rvTextMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(Color.rvText)
    }

    /// Loads a picked photo into the model as JPEG data.
    private func load(_ item: PhotosPickerItem?, into keyPath: ReferenceWritableKeyPath<PartnerViewModel, Data?>) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run { model[keyPath: keyPath] = data }
            }
        }
    }
}

// MARK: - Flow layout (wrapping chips)

/// A simple wrapping layout that flows its subviews left-to-right, moving to a
/// new line when the current row runs out of width. Used for the taste chips.
private struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    PartnerView()
        .environment(MatchStore())
}
