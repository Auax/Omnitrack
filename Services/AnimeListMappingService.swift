import Foundation

/// Manages the AniList → TMDB ID mapping using the Fribb anime-lists dataset.
///
/// The ~7 MB JSON is downloaded once, cached locally in the app's Documents
/// directory, and refreshed only when the local copy is older than 7 days.
/// Parsing happens on a background thread and the result is stored in a
/// `[Int: Int]` dictionary for O(1) lookups.
actor AnimeListMappingService {

    // MARK: - Singleton

    static let shared = AnimeListMappingService()

    // MARK: - Constants

    private static let remoteURL = URL(string: "https://raw.githubusercontent.com/Fribb/anime-lists/master/anime-list-full.json")!
    private static let localFileName = "anime-list-mapping.json"
    private static let maxAge: TimeInterval = 60 * 60 * 24 * 7 // 7 days

    // MARK: - State

    /// `[AniListID : TMDB_ID]`
    private var mapping: [Int: Int]?
    private var loadTask: Task<Void, Never>?
    private var isLoaded = false

    // MARK: - Public API

    /// Returns the TMDB TV-show ID for a given AniList media ID, or `nil` if
    /// no mapping exists.
    func getTMDBId(for anilistId: Int) async -> Int? {
        await ensureLoaded()
        return mapping?[anilistId]
    }

    /// Call once at app launch (or lazily on first use) to kick off the
    /// background download + parse.
    func preload() {
        guard loadTask == nil else { return }
        loadTask = Task { await ensureLoaded() }
    }

    // MARK: - Loading

    private func ensureLoaded() async {
        if isLoaded { return }

        // Avoid duplicate work if another caller is already loading.
        if let existing = loadTask {
            await existing.value
            return
        }

        let task = Task {
            await self.performLoad()
        }
        loadTask = task
        await task.value
    }

    private func performLoad() async {
        let fileURL = Self.localFileURL()
        let needsDownload = Self.needsRefresh(fileURL: fileURL)

        var jsonData: Data?

        if needsDownload {
            jsonData = await Self.downloadMapping()
            if let data = jsonData {
                Self.saveToLocal(data: data, fileURL: fileURL)
            }
        }

        // Prefer freshly downloaded data, fall back to local cache.
        if jsonData == nil {
            jsonData = Self.loadFromLocal(fileURL: fileURL)
        }

        guard let data = jsonData else {
            // Do not set isLoaded = true so that future calls can retry
            loadTask = nil
            return
        }

        // Parse on a background thread to avoid blocking the actor / main thread.
        let parsed: [Int: Int]? = await Task.detached(priority: .utility) {
            Self.parseMapping(data: data)
        }.value

        mapping = parsed
        isLoaded = true
        loadTask = nil
    }

    // MARK: - File Management

    private static func localFileURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(localFileName)
    }

    private static func needsRefresh(fileURL: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return true }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modified = attrs[.modificationDate] as? Date else {
            return true
        }
        return Date().timeIntervalSince(modified) > maxAge
    }

    private static func loadFromLocal(fileURL: URL) -> Data? {
        try? Data(contentsOf: fileURL)
    }

    private static func saveToLocal(data: Data, fileURL: URL) {
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Network

    private static func downloadMapping() async -> Data? {
        do {
            let (data, _) = try await URLSession.shared.data(from: remoteURL)
            return data
        } catch {
            print("[AnimeListMappingService] Download failed: \(error)")
            return nil
        }
    }

    // MARK: - Parsing

    /// Parses the JSON array into a `[AniListID: TMDB_ID]` dictionary.
    /// Each entry in the array looks like:
    /// ```json
    /// { "anilist_id": 290, "themoviedb_id": 26209, ... }
    /// ```
    /// Some entries may be missing either key; those are skipped.
    private static func parseMapping(data: Data) -> [Int: Int] {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return [:]
        }

        var dict = [Int: Int]()
        dict.reserveCapacity(array.count)

        for entry in array {
            guard let anilistId = entry["anilist_id"] as? Int,
                  let tmdbId = entry["themoviedb_id"] as? Int else {
                continue
            }
            // Keep the first mapping (usually the main/first season).
            if dict[anilistId] == nil {
                dict[anilistId] = tmdbId
            }
        }

        return dict
    }
}
