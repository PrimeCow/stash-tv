import Foundation
import Observation

@Observable
@MainActor
final class FilterPreferences {
    enum Mode: String, CaseIterable, Sendable {
        case scenes
        case markers

        var recentChipID: String {
            switch self {
            case .scenes: return "recent"
            case .markers: return "recent_markers"
            }
        }

        var stashFilterModeName: String {
            switch self {
            case .scenes: return "SCENES"
            case .markers: return "SCENE_MARKERS"
            }
        }
    }

    private enum Keys {
        static let enabledSceneIDs = "stashtv.enabledFilterIDs"
        static let showRecentScenes = "stashtv.showRecentScenes"
        static let activeSceneID = "stashtv.activeFilterID"
        static let enabledMarkerIDs = "stashtv.enabledMarkerFilterIDs"
        static let showRecentMarkers = "stashtv.showRecentMarkers"
        static let activeMarkerID = "stashtv.activeMarkerFilterID"
    }

    static let recentScenesID = Mode.scenes.recentChipID

    var enabledFilterIDs: Set<String> {
        didSet { defaults.set(Array(enabledFilterIDs), forKey: Keys.enabledSceneIDs) }
    }

    var showRecentScenes: Bool {
        didSet { defaults.set(showRecentScenes, forKey: Keys.showRecentScenes) }
    }

    var activeFilterID: String? {
        didSet {
            if let activeFilterID {
                defaults.set(activeFilterID, forKey: Keys.activeSceneID)
            } else {
                defaults.removeObject(forKey: Keys.activeSceneID)
            }
        }
    }

    var enabledMarkerFilterIDs: Set<String> {
        didSet { defaults.set(Array(enabledMarkerFilterIDs), forKey: Keys.enabledMarkerIDs) }
    }

    var showRecentMarkers: Bool {
        didSet { defaults.set(showRecentMarkers, forKey: Keys.showRecentMarkers) }
    }

    var activeMarkerFilterID: String? {
        didSet {
            if let activeMarkerFilterID {
                defaults.set(activeMarkerFilterID, forKey: Keys.activeMarkerID)
            } else {
                defaults.removeObject(forKey: Keys.activeMarkerID)
            }
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.enabledFilterIDs = Set((defaults.array(forKey: Keys.enabledSceneIDs) as? [String]) ?? [])
        self.showRecentScenes = (defaults.object(forKey: Keys.showRecentScenes) as? Bool) ?? true
        self.activeFilterID = defaults.string(forKey: Keys.activeSceneID)
        self.enabledMarkerFilterIDs = Set((defaults.array(forKey: Keys.enabledMarkerIDs) as? [String]) ?? [])
        self.showRecentMarkers = (defaults.object(forKey: Keys.showRecentMarkers) as? Bool) ?? true
        self.activeMarkerFilterID = defaults.string(forKey: Keys.activeMarkerID)
    }
}
