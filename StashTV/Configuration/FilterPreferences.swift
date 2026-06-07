import Foundation
import Observation

@Observable
@MainActor
final class FilterPreferences {
    private enum Keys {
        static let enabledIDs = "stashtv.enabledFilterIDs"
        static let showRecentScenes = "stashtv.showRecentScenes"
        static let activeFilterID = "stashtv.activeFilterID"
    }

    static let recentScenesID = "recent"

    var enabledFilterIDs: Set<String> {
        didSet { defaults.set(Array(enabledFilterIDs), forKey: Keys.enabledIDs) }
    }

    var showRecentScenes: Bool {
        didSet { defaults.set(showRecentScenes, forKey: Keys.showRecentScenes) }
    }

    var activeFilterID: String? {
        didSet {
            if let activeFilterID {
                defaults.set(activeFilterID, forKey: Keys.activeFilterID)
            } else {
                defaults.removeObject(forKey: Keys.activeFilterID)
            }
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.enabledFilterIDs = Set((defaults.array(forKey: Keys.enabledIDs) as? [String]) ?? [])
        self.showRecentScenes = (defaults.object(forKey: Keys.showRecentScenes) as? Bool) ?? true
        self.activeFilterID = defaults.string(forKey: Keys.activeFilterID)
    }
}
