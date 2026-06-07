import SwiftUI

struct ManageFiltersView: View {
    let mode: FilterPreferences.Mode
    let catalog: FilterCatalog
    @Bindable var prefs: FilterPreferences

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 48) {
                    recentSection
                    savedFiltersSection
                }
                .padding(.horizontal, 100)
                .padding(.vertical, 60)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Text(headerTitle)
                .font(.largeTitle).bold()
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 100)
        .padding(.vertical, 40)
        .background(.regularMaterial)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading("General")
            Toggle(recentToggleTitle, isOn: recentBinding)
                .font(.title3)
            Text(recentFooter)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var savedFiltersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading("Saved Filters")
            switch catalog.status {
            case .idle, .loading:
                HStack(spacing: 16) {
                    ProgressView()
                    Text("Loading…").foregroundStyle(.secondary)
                }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            case .loaded:
                if catalog.savedFilters.isEmpty {
                    Text(emptyFiltersMessage)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 12) {
                        ForEach(catalog.savedFilters) { filter in
                            Toggle(filter.name, isOn: enabledBinding(for: filter))
                                .font(.title3)
                        }
                    }
                }
            }
        }
    }

    private var headerTitle: String {
        switch mode {
        case .scenes: return "Scene Filters"
        case .markers: return "Marker Filters"
        }
    }

    private var recentToggleTitle: String {
        switch mode {
        case .scenes: return "Show Recent Scenes"
        case .markers: return "Show Recent Markers"
        }
    }

    private var recentFooter: String {
        switch mode {
        case .scenes: return "When off, only your enabled saved filters appear at the top of the browse view."
        case .markers: return "When off, only your enabled saved filters appear at the top of the markers view."
        }
    }

    private var emptyFiltersMessage: String {
        switch mode {
        case .scenes: return "No saved scene filters on this server."
        case .markers: return "No saved marker filters on this server."
        }
    }

    private var recentBinding: Binding<Bool> {
        switch mode {
        case .scenes:
            return Binding(get: { prefs.showRecentScenes }, set: { prefs.showRecentScenes = $0 })
        case .markers:
            return Binding(get: { prefs.showRecentMarkers }, set: { prefs.showRecentMarkers = $0 })
        }
    }

    private func enabledBinding(for filter: SavedFilter) -> Binding<Bool> {
        switch mode {
        case .scenes:
            return Binding(
                get: { prefs.enabledFilterIDs.contains(filter.id) },
                set: { isOn in
                    if isOn { prefs.enabledFilterIDs.insert(filter.id) }
                    else { prefs.enabledFilterIDs.remove(filter.id) }
                }
            )
        case .markers:
            return Binding(
                get: { prefs.enabledMarkerFilterIDs.contains(filter.id) },
                set: { isOn in
                    if isOn { prefs.enabledMarkerFilterIDs.insert(filter.id) }
                    else { prefs.enabledMarkerFilterIDs.remove(filter.id) }
                }
            )
        }
    }
}

private struct SectionHeading: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .tracking(2)
            .foregroundStyle(.secondary)
    }
}
