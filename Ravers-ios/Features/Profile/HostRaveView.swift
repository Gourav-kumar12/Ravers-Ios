import SwiftUI

/// A dedicated host form reached from the Profile tab. Saving publishes the
/// party at the top of the Party feed through the shared profile model.
struct HostRaveView: View {
    let model: ProfileViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var venue = ""
    @State private var date = Date()
    @State private var details = ""
    @State private var saveError: String?

    var body: some View {
        ZStack {
            Color.rvBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    introCard
                    form
                    publishButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: 440)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await model.load()
            populateFromProfile()
        }
        .alert("Couldn't publish rave", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private var header: some View {
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

            Text("HOST A RAVE")
                .font(.system(size: 16, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Color.rvText)

            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Color.rvRed)
            Text("Bring your crowd together.")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color.rvText)
            Text("Publish your party details for ravers to discover in the Party tab.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.rvTextMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.rvBorder, lineWidth: 1))
    }

    private var form: some View {
        VStack(spacing: 16) {
            input("RAVE NAME", text: $name, placeholder: "e.g. Midnight Frequency")
            input("VENUE", text: $venue, placeholder: "Venue and neighbourhood")

            VStack(alignment: .leading, spacing: 7) {
                label("DATE AND TIME")
                DatePicker("", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Color.rvRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.rvBorder, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 7) {
                label("ABOUT THE RAVE")
                TextField("Tell ravers what to expect", text: $details, axis: .vertical)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.rvText)
                    .lineLimit(3...6)
                    .padding(14)
                    .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.rvBorder, lineWidth: 1))
            }
        }
    }

    private var publishButton: some View {
        Button { Task { await save() } } label: {
            Text(model.isSaving ? "SAVING…" : "PUBLISH RAVE")
                .font(.system(size: 14, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isValid ? Color.rvRed : Color.rvRed.opacity(0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isValid || model.isSaving)
    }

    private var isValid: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 &&
        venue.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 &&
        details.count <= 1000 && date > .now
    }

    private func label(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.rvTextMuted)
    }

    private func input(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            label(title)
            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.rvText)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.rvBorder, lineWidth: 1))
        }
    }

    private func populateFromProfile() {
        guard let profile = model.profile else { return }
        name = profile.hostedRaveName
        venue = profile.hostedRaveVenue
        date = profile.hostedRaveDate
        details = profile.hostedRaveDetails
    }

    private func save() async {
        guard var profile = model.profile else { return }
        profile.isHostingRave = true
        profile.hostedRaveName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.hostedRaveVenue = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.hostedRaveDate = date
        profile.hostedRaveDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard await model.saveHostedRave(profile) else {
            saveError = model.errorMessage ?? "Please check your connection and try again."
            model.errorMessage = nil
            return
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        HostRaveView(model: ProfileViewModel())
    }
}
