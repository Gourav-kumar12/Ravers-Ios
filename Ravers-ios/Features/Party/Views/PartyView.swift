//
//  PartyView.swift
//  Raverse-ios
//
//  Event feed (Screen 4). Location header, genre filter pills and event cards.
//
import SwiftUI

struct PartyView: View {
    @State private var model = PartyViewModel()
    @State private var savedIDs: Set<String> = []

    var body: some View {
        ZStack {
            Color.rvBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    genreFilter
                    eventList
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: 440)
        }
        .task { await model.load() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PARTY")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(Color.rvText)

            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.rvRed)
                Text(model.locationLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)
            }
        }
    }

    // MARK: - Genre filter chips

    private var genreFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.genres, id: \.self) { genre in
                    let selected = model.selectedGenre == genre
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { model.selectedGenre = genre }
                    } label: {
                        Text(genre)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selected ? .black : Color.rvText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(
                                selected ? Color.rvRed : Color.white.opacity(0.08),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().stroke(Color.red.opacity(selected ? 0 : 0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Event list

    private var eventList: some View {
        LazyVStack(spacing: 18) {
            ForEach(model.filteredEvents) { event in
                NavigationLink {
                    EventDetailView(event: event)
                } label: {
                    EventCard(
                        event: event,
                        isSaved: savedIDs.contains(event.id),
                        onSave: { toggleSave(event) }
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleSave(_ event: Event) {
        if savedIDs.contains(event.id) { savedIDs.remove(event.id) }
        else { savedIDs.insert(event.id) }
    }
}

#Preview {
    NavigationStack {
        PartyView()
    }
}
