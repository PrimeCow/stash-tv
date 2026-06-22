import SwiftUI

struct FilterChipBarView: View {
    struct Chip: Identifiable, Hashable {
        let id: String
        let title: String
    }

    let chips: [Chip]
    @Binding var activeID: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(chips) { chip in
                    Button {
                        activeID = chip.id
                    } label: {
                        Text(chip.title)
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(activeID == chip.id ? Color.accentColor : Color.gray)
                }
            }
        }
        // Its own focus section so the engine can navigate into the chips even
        // when the content below is an error state with little else focusable.
        .focusSection()
    }
}
