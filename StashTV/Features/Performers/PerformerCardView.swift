import SwiftUI

struct PerformerCardView: View {
    let performer: Performer
    let apiKey: String?

    var body: some View {
        NavigationLink(value: performer) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Color.gray.opacity(0.2)
                    if let url = StashURL.authenticated(performer.image_path, apiKey: apiKey) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                            case .failure, .empty:
                                Image(systemName: "person.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.secondary)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(2/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(performer.name)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let count = performer.scene_count {
                        Text("\(count) scene\(count == 1 ? "" : "s")")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.card)
    }
}
