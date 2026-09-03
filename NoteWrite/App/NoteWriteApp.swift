import SwiftUI
import SwiftData

@main
struct NoteWriteApp: App {
    @State private var settings = SettingsStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(for: [
                    TodoItem.self,
                    SubTask.self,
                    Note.self,
                    NoteChecklistItem.self
                ])
                .preferredColorScheme(settings.scheme)
                .tint(settings.accentColor)
        }
    }
}
