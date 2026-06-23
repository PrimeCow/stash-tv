import Foundation
import Observation

/// Holds session-scoped performer-list overrides keyed by scene ID. The player
/// writes the updated list here after an add/remove mutation succeeds; views read
/// from here (falling back to whatever Stash returned at query time) so edits
/// show immediately without re-fetching.
@Observable
@MainActor
final class ScenePerformersStore {
    private var overrides: [String: [Performer]] = [:]

    func performers(for sceneID: String, fallback: [Performer]) -> [Performer] {
        overrides[sceneID] ?? fallback
    }

    func setPerformers(_ performers: [Performer], for sceneID: String) {
        overrides[sceneID] = performers
    }
}
