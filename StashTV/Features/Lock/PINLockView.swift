import SwiftUI

struct PINLockView: View {
    @Bindable var appLock: AppLock

    @State private var pin: String = ""
    @State private var attemptError: String?
    @State private var shake = false

    var body: some View {
        VStack(spacing: 60) {
            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Enter PIN")
                    .font(.largeTitle).bold()
                PINDots(filled: pin.count, total: 4)
                    .offset(x: shake ? 8 : 0)
                    .animation(.default.repeatCount(3, autoreverses: true).speed(8), value: shake)
                Text(attemptError ?? " ")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            PINPadView(pin: $pin, onComplete: verify)
        }
        .padding(80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    private func verify() {
        guard appLock.verify(pin) else {
            attemptError = "Incorrect PIN"
            shake.toggle()
            pin = ""
            return
        }
    }
}

struct PINDots: View {
    let filled: Int
    let total: Int

    var body: some View {
        HStack(spacing: 24) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < filled ? Color.white : Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
            }
        }
    }
}
