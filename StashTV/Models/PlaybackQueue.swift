import Foundation
import Observation

@Observable
@MainActor
final class PlaybackQueue {
    var entries: [PlaylistEntry]
    var currentEntryIndex: Int

    init(entries: [PlaylistEntry], currentEntryIndex: Int) {
        self.entries = entries
        self.currentEntryIndex = currentEntryIndex
    }

    var currentScene: Scene? {
        guard entries.indices.contains(currentEntryIndex) else { return nil }
        return entries[currentEntryIndex].scene
    }

    func append(_ more: [PlaylistEntry]) {
        guard !more.isEmpty else { return }
        entries.append(contentsOf: more)
    }
}
