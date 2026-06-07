import Foundation
import Observation

@Observable
@MainActor
final class FilterCatalog {
    enum Status: Equatable {
        case idle
        case loading
        case loaded
        case failed(message: String)
    }

    let mode: FilterPreferences.Mode

    private(set) var status: Status = .idle
    private(set) var savedFilters: [SavedFilter] = []

    init(mode: FilterPreferences.Mode) {
        self.mode = mode
    }

    func loadIfNeeded(using config: ServerConfig) async {
        guard case .idle = status else { return }
        await load(using: config)
    }

    func refresh(using config: ServerConfig) async {
        status = .idle
        savedFilters = []
        await load(using: config)
    }

    private func load(using config: ServerConfig) async {
        status = .loading
        do {
            let client = try StashClient.make(from: config)
            let result = try await client.execute(FindSavedFiltersQuery(mode: mode.stashFilterModeName))
            savedFilters = result.findSavedFilters.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            status = .loaded
        } catch {
            status = .failed(message: (error as? LocalizedError)?.errorDescription ?? "\(error)")
        }
    }
}
