import SwiftUI

struct ReceiverDetailsView: View {
    let receiver: Receiver
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Label(receiver.name, systemImage: "display")
                    .font(.title2.bold())
                Text("A Bonjour service was discovered. Discovery alone does not authenticate this receiver or confirm that it supports mirroring.")
                    .font(.body).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 10) {
                    capability("Service", "_mirrorcast._tcp")
                    capability("Identity", "Not verified")
                    capability("Media support", "Not negotiated")
                    capability("Remote controls", "Not negotiated")
                }
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                Spacer()
                Text("Secure pairing and streaming will be enabled only after the receiver protocol is implemented and verified.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(20)
            .navigationTitle("Device details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func capability(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }.font(.subheadline)
    }
}
