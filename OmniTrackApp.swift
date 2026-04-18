import SwiftUI

@main
struct OmniTrackApp: App {
    @State private var mediaService = MediaService()
    @State private var settingsManager = SettingsManager()
    @State private var libraryViewModel = LibraryViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(mediaService)
                .environment(settingsManager)
                .environment(libraryViewModel)
                .preferredColorScheme(settingsManager.preferredColorScheme)
        }
    }
}
