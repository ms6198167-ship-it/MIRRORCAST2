import ReplayKit
import Network
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import AVFoundation
import QuartzCore
import CoreGraphics

/// Broadcast Upload Extension: sends JPEG screen frames and raw ReplayKit audio sample bytes
/// over the MirrorCast v1 framed TCP protocol. This prototype is LAN-only and not TLS protected.
final class SampleHandler: RPBroadcastSampleHandler {
    private let queue = DispatchQueue(label: "com.mirrorcast.broadcast.network")
    private let ciContext = CIContext()
    private var connection: NWConnection?
    private var connected = false
    private var configuredHost: NWEndpoint.Host?
    private var configuredPort: NWEndpoint.Port?
    private let maxFrameRateInterval: CFTimeInterval = 1.0 / 12.0
    private var lastVideoTime: CFTimeInterval = 0

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        let defaults = UserDefaults(suiteName: "group.com.example.MirrorCast")
        let host = defaults?.string(forKey: "receiverHost")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let portValue = defaults?.integer(forKey: "receiverPort") ?? 8765
        guard !host.isEmpty, let port = NWEndpoint.Port(rawValue: UInt16(clamping: portValue)) else {
            finishBroadcastWithError(NSError(domain: "MirrorCast", code: 1, userInfo: [NSLocalizedDescriptionKey: "Enter the Windows receiver IP address in MirrorCast before starting broadcast."]))
            return
        }
        configuredHost = NWEndpoint.Host(host)
        configuredPort = port
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let conn = NWConnection(host: configuredHost!, port: port, using: params)
        connection = conn
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.connected = true
                self.sendPacket(header: ["v": 1, "kind": "hello", "device": "iOS ReplayKit", "codec": "jpeg"], payload: Data())
            case .failed(let error):
                self.finishBroadcastWithError(error)
            case .cancelled:
                self.connected = false
            default: break
            }
        }
        conn.start(queue: queue)
    }

    override func broadcastPaused() { }
    override func broadcastResumed() { }

    override func broadcastFinished() {
        sendPacket(header: ["v": 1, "kind": "end"], payload: Data())
        connection?.cancel()
        connection = nil
        connected = false
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard connected else { return }
        switch sampleBufferType {
        case .video:
            let now = CACurrentMediaTime()
            guard now - lastVideoTime >= maxFrameRateInterval else { return }
            lastVideoTime = now
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let image = CIImage(cvPixelBuffer: imageBuffer)
            guard let data = ciContext.jpegRepresentation(of: image, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.55]) else { return }
            sendPacket(header: ["v": 1, "kind": "video", "codec": "jpeg", "timestamp": CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds], payload: data)
        case .audioApp:
            sendAudio(sampleBuffer, kind: "audio_app")
        case .audioMic:
            sendAudio(sampleBuffer, kind: "audio_mic")
        @unknown default: break
        }
    }

    private func sendAudio(_ sampleBuffer: CMSampleBuffer, kind: String) {
        guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        let length = CMBlockBufferGetDataLength(block)
        guard length > 0, length <= 2 * 1024 * 1024 else { return }
        var bytes = Data(count: length)
        let status = bytes.withUnsafeMutableBytes { raw in
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: raw.baseAddress!)
        }
        guard status == kCMBlockBufferNoErr else { return }
        var sampleRate = 0.0
        var channels = 0
        if let desc = CMSampleBufferGetFormatDescription(sampleBuffer), let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee {
            sampleRate = asbd.mSampleRate
            channels = Int(asbd.mChannelsPerFrame)
        }
        sendPacket(header: ["v": 1, "kind": kind, "codec": "replaykit-raw", "sampleRate": sampleRate, "channels": channels, "timestamp": CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds], payload: bytes)
    }

    private func sendPacket(header: [String: Any], payload: Data) {
        guard let connection else { return }
        var body = header
        body["length"] = payload.count
        guard let headerData = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]), headerData.count <= 16 * 1024 else { return }
        var framed = Data([0x4D, 0x43, 0x53, 0x54])
        var headerLength = UInt32(headerData.count).bigEndian
        withUnsafeBytes(of: &headerLength) { framed.append(contentsOf: $0) }
        framed.append(headerData)
        framed.append(payload)
        connection.send(content: framed, completion: .contentProcessed { [weak self] error in
            if let error { self?.finishBroadcastWithError(error) }
        })
    }
}
