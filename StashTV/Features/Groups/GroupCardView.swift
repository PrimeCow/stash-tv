import SwiftUI

struct GroupCardView: View {
    let group: Group
    let apiKey: String?

    var body: some View {
        NavigationLink(value: group) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Color.gray.opacity(0.2)
                    if let url = imageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure, .empty:
                                Image(systemName: "rectangle.stack")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.secondary)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                .aspectRatio(2/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(group.displayTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(group.scene_count) scene\(group.scene_count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.card)
    }

    private var imageURL: URL? {
        StashURL.authenticated(group.front_image_path ?? group.back_image_path, apiKey: apiKey)
    }
}
