<h1 align="center">OmniTrack</h1>

<p align="center">
  <em>An elegant iOS application for tracking movies, TV shows, and anime.</em>
</p>

<p align="center">
  <img alt="iOS 18.0+" src="https://img.shields.io/badge/iOS-18.0%2B-blue.svg">
  <img alt="Xcode 16+" src="https://img.shields.io/badge/Xcode-16%2B-blue.svg">
  <img alt="SwiftUI" src="https://img.shields.io/badge/SwiftUI-blue.svg">
</p>

<p align="center">
  <img width="600" alt="OmniTrack App Screenshot" src="https://github.com/user-attachments/assets/7d67ef8d-7226-49e7-82b9-7e6d9c0cc77c" />
</p>

---

## ✨ Features

- **Home** — Jump right back in with "Continue watching" and a preview of your watchlist.
- **Discover** — Browse by media type (All / Movies / TV / Anime). Sort the catalog by trending, popularity, or ratings, and filter by genre using an infinite-scroll grid.
- **Library** — Manage your watchlist and track your watched elements.

*Note: Local state (queue, watched episodes, progress) is persisted securely directly on the device.*

## 🛠️ Requirements

- **Xcode** 16+ (recommended)
- **iOS** 18.0+ deployment target
- Active internet connection for API calls

## 🚀 Getting Started

1. Clone the repository and open `OmniTrack.xcodeproj` in Xcode.
2. Select your development team and choose a unique bundle identifier for signing.
3. Configure your API keys (see the [Configuration](#-configuration) section below).
4. Build and run on a simulator or physical device (`⌘ + R`).

## 🔑 Configuration

API keys are injected at build time via **Info.plist** from `Config.xcconfig` (see `Config.swift`).

| Key | Purpose |
|-----|---------|
| `TMDB_API_KEY` | **Required** — TMDB is used for movies, TV metadata, discover, and search. [Get a key here](https://www.themoviedb.org/settings/api). |
| `OMDB_API_KEY` | **Optional** — OMDb is used for IMDb-style ratings when that provider is selected in Settings. [Get an OMDb API key](https://www.omdbapi.com/apikey.aspx). |

> **⚠️ Security Warning:**
> Edit `Config.xcconfig` (or your own `.xcconfig` / build settings) so `TMDB_API_KEY` and `OMDB_API_KEY` are set. **Do not commit real keys** to public repositories. Use a local override, `.gitignore`, or Xcode user-defined settings for your secrets.

*AniList integration uses its public GraphQL API, so no app key is required for typical usage.*

## 📂 Project Structure

```text
OmniTrack/
├── OmniTrackApp.swift       # App entry, environment objects
├── ContentView.swift        # Tab bar (Home, Discover, Library, Search)
├── Models/                  # MediaItem, episodes, stats, discover catalog
├── Services/                # MediaService, TMDB, AniList, settings, progress
├── Views/                   # Feature screens and components
│   ├── Home/
│   ├── Discover/
│   ├── Library/
│   ├── Detail/
│   └── …
├── Utilities/               # Theme, colors
└── Assets.xcassets/         # Images, app icons, tab bar assets
