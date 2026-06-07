import SwiftUI

struct PINPadView: View {
    @Binding var pin: String
    let maxLength: Int
    let onComplete: () -> Void

    init(pin: Binding<String>, maxLength: Int = 4, onComplete: @escaping () -> Void) {
        self._pin = pin
        self.maxLength = maxLength
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 24) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
        .focusSection()
    }

    private var rows: [[PadKey]] {
        [
            [.digit(1), .digit(2), .digit(3)],
            [.digit(4), .digit(5), .digit(6)],
            [.digit(7), .digit(8), .digit(9)],
            [.clear, .digit(0), .backspace]
        ]
    }

    @ViewBuilder
    private func keyButton(_ key: PadKey) -> some View {
        Button {
            handle(key)
        } label: {
            keyLabel(for: key)
                .frame(width: 180, height: 110)
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private func keyLabel(for key: PadKey) -> some View {
        switch key {
        case .digit(let n):
            Text("\(n)").font(.largeTitle)
        case .clear:
            Text("Clear").font(.title3)
        case .backspace:
            Image(systemName: "delete.left").font(.title)
        }
    }

    private func handle(_ key: PadKey) {
        switch key {
        case .digit(let n):
            guard pin.count < maxLength else { return }
            pin.append("\(n)")
            if pin.count == maxLength { onComplete() }
        case .clear:
            pin = ""
        case .backspace:
            if !pin.isEmpty { pin.removeLast() }
        }
    }

    private enum PadKey: Hashable {
        case digit(Int)
        case clear
        case backspace
    }
}
