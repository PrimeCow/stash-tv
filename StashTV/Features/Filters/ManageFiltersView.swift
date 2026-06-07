import SwiftUI

struct ManageFiltersView: View {
    let catalog: FilterCatalog
    @Bindable var prefs: FilterPreferences

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 48) {
                    recentScenesSection
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
            Text("Filters")
                .font(.largeTitle).bold()
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 100)
        .padding(.vertical, 40)
        .background(.regularMaterial)
    }

    private var recentScenesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading("General")
            Toggle("Show Recent Scenes", isOn: $prefs.showRecentScenes)
                .font(.title3)
            Text("When off, only your enabled saved filters appear at the top of the browse view.")
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
                    Text("No saved scene filters on this server.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 12) {
                        ForEach(catalog.savedFilters) { filter in
                            Toggle(filter.name, isOn: binding(for: filter))
                                .font(.title3)
                        }
                    }
                }
            }
        }
    }

    private func binding(for filter: SavedFilter) -> Binding<Bool> {
        Binding(
            get: { prefs.enabledFilterIDs.contains(filter.id) },
            set: { isOn in
                if isOn { prefs.enabledFilterIDs.insert(filter.id) }
                else { prefs.enabledFilterIDs.remove(filter.id) }
            }
        )
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
