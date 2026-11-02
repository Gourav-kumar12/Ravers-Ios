import SwiftUI

struct RaverPortrait: View {
    let raver: RaverProfile
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let url = URL(string: raver.imageName), url.scheme == "https" {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() }
                        placeholder: { fallback }
                } else if !raver.imageName.isEmpty, UIImage(named: raver.imageName) != nil {
                    Image(raver.imageName).resizable().scaledToFill()
                } else { fallback }
            }
            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .accessibilityLabel("\(raver.name)'s profile photo")
    }
    private var fallback: some View {
        ZStack {
            LinearGradient(colors: [Color.rvRedDeep, Color.rvSurface], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "person.fill").resizable().scaledToFit().padding(36)
                .foregroundStyle(Color.rvText.opacity(0.18))
            Text(String(raver.name.prefix(1))).font(.system(size: 52, weight: .black)).foregroundStyle(Color.rvText)
        }
    }
}

struct ChatUnlockLabel: View {
    let date: Date
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if date > context.date {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                    Text("Chat opens in")
                    Text(date, style: .timer).monospacedDigit()
                }
            } else {
                Label("Chat is open", systemImage: "bubble.left.and.bubble.right")
            }
        }
    }
}
