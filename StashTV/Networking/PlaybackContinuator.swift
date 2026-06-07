import Foundation

@MainActor
struct PlaybackContinuator {
    let config: ServerConfig

    func fetchMore(context: PlaybackContext, alreadyLoaded: Int) async -> [PlaylistEntry] {
        switch context {
        case .oneOff:
            return []
        case .scenes(let descriptor):
            return await fetchScenes(descriptor: descriptor, alreadyLoaded: alreadyLoaded)
        case .markers(let descriptor):
            return await fetchMarkers(descriptor: descriptor, alreadyLoaded: alreadyLoaded)
        case .performer(let performerID):
            return await fetchPerformerScenes(performerID: performerID, alreadyLoaded: alreadyLoaded)
        }
    }

    private func fetchScenes(descriptor: SceneFeedDescriptor, alreadyLoaded: Int) async -> [PlaylistEntry] {
        let page = (alreadyLoaded / descriptor.perPage) + 1
        do {
            let client = try StashClient.make(from: config)
            let query = FindScenesQuery(
                page: page,
                perPage: descriptor.perPage,
                sort: descriptor.sort,
                direction: descriptor.direction,
                sceneFilter: descriptor.sceneFilter
            )
            let result = try await client.execute(query)
            return result.findScenes.scenes.map { PlaylistEntry(scene: $0, startTime: nil) }
        } catch {
            print("[Continuator] scenes fetch failed: \(error)")
            return []
        }
    }

    private func fetchMarkers(descriptor: MarkerFeedDescriptor, alreadyLoaded: Int) async -> [PlaylistEntry] {
        let page = (alreadyLoaded / descriptor.perPage) + 1
        do {
            let client = try StashClient.make(from: config)
            let query = FindSceneMarkersQuery(
                page: page,
                perPage: descriptor.perPage,
                sort: descriptor.sort,
                direction: descriptor.direction,
                sceneMarkerFilter: descriptor.sceneMarkerFilter
            )
            let result = try await client.execute(query)
            return result.findSceneMarkers.scene_markers.map {
                PlaylistEntry(scene: $0.scene, startTime: $0.seconds)
            }
        } catch {
            print("[Continuator] markers fetch failed: \(error)")
            return []
        }
    }

    private func fetchPerformerScenes(performerID: String, alreadyLoaded: Int) async -> [PlaylistEntry] {
        let perPage = 40
        let page = (alreadyLoaded / perPage) + 1
        do {
            let client = try StashClient.make(from: config)
            let sceneFilter: JSONValue = .object([
                "performers": .object([
                    "value": .array([.string(performerID)]),
                    "modifier": .string("INCLUDES"),
                ])
            ])
            let query = FindScenesQuery(
                page: page,
                perPage: perPage,
                sort: "date",
                direction: "DESC",
                sceneFilter: sceneFilter
            )
            let result = try await client.execute(query)
            return result.findScenes.scenes.map { PlaylistEntry(scene: $0, startTime: nil) }
        } catch {
            print("[Continuator] performer fetch failed: \(error)")
            return []
        }
    }
}
