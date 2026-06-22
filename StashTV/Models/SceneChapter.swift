import Foundation

/// A marker within a single scene, used to jump around during playback.
/// Lighter than `SceneMarker` — it carries no embedded `scene`, since it's
/// always loaded in the context of the scene currently playing.
struct SceneChapter: Identifiable, Decodable, Hashable {
    let id: String
    let title: String
    let seconds: Double
    let primary_tag: Tag
    let tags: [Tag]

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? primary_tag.name : trimmed
    }

    var subtitleTags: [String] {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let others = tags.filter { $0.id != primary_tag.id }.map(\.name)
        return trimmed.isEmpty ? others : [primary_tag.name] + others
    }

    var formattedTimecode: String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
