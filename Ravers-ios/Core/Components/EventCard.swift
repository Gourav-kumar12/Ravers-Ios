//
//  EventCard.swift
//  Raverse-ios
//
//  A single event tile for the Party feed: hero image, date badge, bookmark,
//  title, venue + distance, genre tags and "from ₹" price.
//

import SwiftUI

struct EventCard: View {
    let event: Event
    var isSaved: Bool = false
    var onSave: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            hero

            // Legibility gradient so text sits over any image.
            LinearGradient(
                colors: [.clear, .black.opacity(0.35), .black.opacity(0.9)],
                startPoint: .center,
                endPoint: .bottom
            )

            topRow
                .frame(maxHeight: .infinity, alignment: .top)

            details
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Hero image (falls back to a themed gradient if the asset is missing)

    @ViewBuilder
    private var hero: some View {
        if UIImage(named: event.imageName) != nil {
            Image(event.imageName)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [Color.rvRedDeep, .black],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .overlay(
                RadialGradient(
                    colors: [Color.rvRed.opacity(0.55), .clear],
                    center: .init(x: 0.7, y: 0.25),
                    startRadius: 8,
                    endRadius: 220
                )
            )
        }
    }

    // MARK: - Date badge + bookmark

    private var topRow: some View {
        HStack(alignment: .top) {
            Text(dateBadge)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.rvText)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(.black.opacity(0.55), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))

            Spacer()

            Button(action: onSave) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSaved ? Color.rvRed : Color.rvText)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.45), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    // MARK: - Title / venue / tags / price

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(event.name)
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(Color.rvText)

            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.rvTextMuted)
                .lineLimit(1)

            HStack(spacing: 8) {
                ForEach(event.genres, id: \.self) { genre in
                    Text(genre)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.rvText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.10), in: Capsule())
                }

                Spacer()

                Text("from ₹\(event.fromPrice)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.rvText)
            }
        }
        .padding(16)
    }

    // MARK: - Formatting

    private var dateBadge: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM"
        return f.string(from: event.date).uppercased()
    }

    private var subtitle: String {
        if let km = event.distanceKm {
            return "\(event.venue) · \(String(format: "%.1f", km)) km"
        }
        return "\(event.venue), \(event.city)"
    }
}

#Preview {
    ZStack {
        Color.rvBackground.ignoresSafeArea()
        EventCard(
            event: Event(
                id: "x", name: "VOID FREQUENCY",
                venue: "Warehouse 7, Peenya Industrial Area", city: "Bengaluru",
                distanceKm: 14.2, date: .now, genres: ["Techno", "Industrial"],
                fromPrice: 799, imageName: "party-1", passes: []
            )
        )
        .padding()
    }
}
