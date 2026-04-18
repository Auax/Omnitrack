# OmniTrack

iOS app for tracking movies, TV, and anime.

## Views

- **Home** — Continue watching and watchlist preview.
- **Discover** — Browse by type (All / Movies / TV / Anime), sort catalog (trending, popularity, ratings), filter by genre, infinite-scroll grid.
- **Library** — Manage your watchlist and watched elements.

Local state (queue, watched episodes, progress) is persisted on device.

## Requirements

- **Xcode** 16+ (recommended)
- **iOS** 18.0+ deployment target
- Active internet connection for API calls

## Getting started

1. Clone the repository and open `OmniTrack.xcodeproj` in Xcode.
2. Select your development team and a unique bundle identifier for signing.
3. Configure API keys (see below).
4. Build and run on a simulator or device (`⌘R`).

## Configuration

API keys are injected at build time via **Info.plist** from `Config.xcconfig` (see `Config.swift`).

| Key | Purpose |
|-----|--------|
| `TMDB_API_KEY` | Required — TMDB for movies, TV metadata, discover, and search. [Get a key](https://www.themoviedb.org/settings/api). |
| `OMDB_API_KEY` | Optional — OMDb is used for IMDb-style ratings when that provider is selected in Settings. [OMDb API](https://www.omdbapi.com/apikey.aspx). |

Edit `Config.xcconfig` (or your own `.xcconfig` / build settings) so `TMDB_API_KEY` and optionally `OMDB_API_KEY` are set. **Do not commit real keys** to public repositories—use a local override or Xcode user-defined settings for secrets.

AniList integration uses its public GraphQL API (no app key required for typical usage).

## Project structure

```
OmniTrack/
├── OmniTrackApp.swift       # App entry, environment objects
├── ContentView.swift        # Tab bar (Home, Discover, Library, Search)
├── Models/                  # MediaItem, episodes, stats, discover catalog
├── Services/              # MediaService, TMDB, AniList, settings, progress
├── Views/                   # Feature screens and components
│   ├── Home/
│   ├── Discover/
│   ├── Library/
│   ├── Detail/
│   └── …
├── Utilities/               # Theme, colors
└── Assets.xcassets/         # Images, app icons, tab bar assets
```

## Architecture (short)

- **SwiftUI** + **`@Observable`** / **`@Environment`** for `MediaService`, `SettingsManager`, and `LibraryViewModel`.
- **`MediaService`** centralizes fetching, merging user state, and persistence (UserDefaults-backed lists and episode maps).
- **Detail** flows load TV/anime season and episode data through **`TMDBService`** and mapping helpers (e.g. AniList → TMDB where needed).

## Privacy & data

Watch state and preferences stay on the device unless you add cloud sync yourself. Clearing data is available from **Settings → Remove All Saved Data**.

## Troubleshooting

- **Empty Discover / Home after launch** — Check network and that `TMDB_API_KEY` is valid and not placeholder text.
- **IMDb ratings missing or “…”** — Ensure `OMDB_API_KEY` is set and the rating provider in Settings is set to IMDb; OMDb has its own quotas and behavior.

## License

This project is provided as-is for development and personal use. Third-party APIs (TMDB, AniList, OMDb) are subject to their respective terms of use.
