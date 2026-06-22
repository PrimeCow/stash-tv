import SwiftUI

struct ChangePINView: View {
    @Bindable var appLock: AppLock
    @Environment(\.dismiss) private var dismiss

    @State private var firstPIN = ""
    @State private var confirmPIN = ""
    @State private var step: Step = .first
    @State private var error: String?

    private enum Step {
        case first
        case confirm
    }

    var body: some View {
        VStack(spacing: 60) {
            VStack(spacing: 24) {
                Image(systemName: "lock.rotation")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text(step == .first ? "Enter a new 4-digit PIN" : "Confirm your new PIN")
                    .font(.largeTitle).bold()
                PINDots(filled: currentPIN.count, total: 4)
                Text(error ?? " ")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            PINPadView(pin: currentBinding, onComplete: handleSubmit)
            Button("Cancel") { dismiss() }
                .buttonStyle(.bordered)
        }
        .padding(80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    private var currentBinding: Binding<String> {
        step == .first ? $firstPIN : $confirmPIN
    }

    private var currentPIN: String {
        step == .first ? firstPIN : confirmPIN
    }

    private func handleSubmit() {
        switch step {
        case .first:
            error = nil
            step = .confirm
        case .confirm:
            if firstPIN == confirmPIN {
                if appLock.changePIN(firstPIN) {
                    dismiss()
                } else {
                    reset("That PIN isn't valid.")
                }
            } else {
                reset("PINs didn't match — try again.")
            }
        }
    }

    private func reset(_ message: String) {
        error = message
        firstPIN = ""
        confirmPIN = ""
        step = .first
    }
}
