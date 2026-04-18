import Foundation

enum DiscoverCatalog: String, CaseIterable, Identifiable {
    case popularity = "Popularity"
    case trending = "Trending"
    case rating = "Rating"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .popularity: return "flame"
        case .trending: return "chart.line.uptrend.xyaxis"
        case .rating: return "star.fill"
        }
    }
}
