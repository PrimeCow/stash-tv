import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct PairingView: View {
    /// Called on the main actor with the values submitted from the phone.
    let onReceive: (String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model = PairingModel()

    var body: some View {
        VStack(spacing: 36) {
            Text("Pair with your phone")
                .font(.largeTitle).bold()

            content

            Button("Cancel") { dismiss() }
                .buttonStyle(.bordered)
        }
        .padding(80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            model.onReceive = { url, key in
                onReceive(url, key)
                dismiss()
            }
            model.start()
        }
        .onDisappear { model.stop() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.status {
        case .starting:
            ProgressView("Starting…")
        case .failed(let message):
            VStack(spacing: 16) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("Make sure the TV is allowed local-network access, then try again.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        case .received:
            Label("Received — finishing up…", systemImage: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        case .running(let address):
            VStack(spacing: 28) {
                Text("On a phone connected to the same Wi-Fi, open this address in a browser:")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 900)

                Text(address)
                    .font(.system(.title, design: .monospaced).weight(.bold))

                if let qr = Self.qrImage(from: address) {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 360, height: 360)
                        .padding(20)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Text("Enter your Stash URL and API key there, then tap “Send to TV.”")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static func qrImage(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
