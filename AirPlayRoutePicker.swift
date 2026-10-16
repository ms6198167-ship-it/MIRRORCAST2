import SwiftUI
import AVKit

/// Presents Apple's supported system route picker. This does not grant whole-screen capture.
struct AirPlayRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView(frame: .zero)
        picker.prioritizesVideoDevices = true
        picker.activeTintColor = UIColor.systemBlue
        picker.tintColor = UIColor.secondaryLabel
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) { }
}
