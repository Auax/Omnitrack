import SwiftUI
import SDWebImageSwiftUI

struct DetailHeroSection: View {
    let item: MediaItem
    @Environment(\.colorScheme) private var colorScheme
    @State private var backdropImageVisible = false

    private let baseHeight: CGFloat = 300

    var body: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
            let stretch = max(0, minY)
            let height = proxy.size.height + stretch

            Color(hex: "000000").opacity(0.3)
                .frame(width: proxy.size.width, height: height)
                .overlay {
                    WebImage(url: item.backdropURL ?? item.posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 8)
                            .onAppear {
                                withAnimation(.easeOut(duration: 0.55)) {
                                    backdropImageVisible = true
                                }
                            }
                    } placeholder: {
                        Color.clear
                    }
                    .id(item.id)
                    .opacity(backdropImageVisible ? 0.7 : 0)
                    .allowsHitTesting(false)
                }
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        stops: [
                            // .init(color: .clear, location: 1.0),
                            // .init(color: Color(hex: "ff0000"), location: 0.4)
                            .init(color: .clear, location: 0.4),
                            .init(color: AppTheme.adaptiveBackground(colorScheme), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .offset(y: -stretch)
        }
        .frame(height: baseHeight)
        .onChange(of: item.id) { _, _ in
            backdropImageVisible = false
        }
    }
}
