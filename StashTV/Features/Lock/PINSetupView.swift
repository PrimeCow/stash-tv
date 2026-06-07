import SwiftUI

struct PINSetupView: View {
    @Bindable var appLock: AppLock

    @State private var firstPIN: String = ""
    @State private var confirmPIN: String = ""
    @State private var step: Step = .first
    @State private var error: String?

    private enum Step {
        case first
        case confirm
    }

    var body: some View {
        VStack(spacing: 60) {
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text(step == .first ? "Create a 4-digit PIN" : "Confirm your PIN")
                    .font(.largeTitle).bold()
                Text(step == .first
                    ? "Required each time you open StashTV."
                    : "Enter it again to confirm.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                PINDots(filled: currentPIN.count, total: 4)
                Text(error ?? " ")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            PINPadView(pin: currentBinding, onComplete: handleSubmit)
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
                appLock.setupPIN(firstPIN)
            } else {
                error = "PINs didn't match — try again."
                firstPIN = ""
                confirmPIN = ""
                step = .first
            }
        }
    }
}
