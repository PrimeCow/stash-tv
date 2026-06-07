import Foundation
import Observation

/// Holds session-scoped stats overrides keyed by scene ID. The player writes
/// new o-counter values here after the increment mutation succeeds; the grid
/// cards read from here (falling back to whatever Stash returned at query
/// time) so they reflect updates without re-fetching the entire list.
@Observable
@MainActor
final class SceneStatsStore {
    private var oCounters: [String: Int] = [:]

    func oCounter(for sceneID: String, fallback: Int?) -> Int? {
        oCounters[sceneID] ?? fallback
    }

    func setOCounter(_ value: Int, for sceneID: String) {
        oCounters[sceneID] = value
    }
}
