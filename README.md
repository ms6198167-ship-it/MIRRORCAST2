# MirrorCast — native iOS sender + Windows receiver prototype

MirrorCast is being built as a native SwiftUI iOS app with a ReplayKit Broadcast Upload Extension and companion receivers. This milestone adds a runnable Python Windows receiver and the first sender-side media transport source.

**This is a working-source milestone, not a finished secure mirroring product.** The Windows receiver accepts JPEG screen frames and displays them, and captures incoming ReplayKit audio/microphone payloads for diagnostics. Audio playback/synchronization, authenticated encrypted pairing, remote controls, and non-Windows receivers remain future work. The iOS targets have not been compiled or device-tested because this environment has no macOS/Xcode toolchain.

## Start on Windows

See [`WindowsReceiver/README.md`](WindowsReceiver/README.md). Quick start:

```powershell
cd WindowsReceiver
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m unittest discover -s tests -v
python receiver.py
```

## Build the iOS sender

See [`Docs/BUILD_AND_TEST.md`](Docs/BUILD_AND_TEST.md). A Mac with Xcode is required to create/sign the app and ReplayKit extension. Register/configure an App Group and bundle IDs before testing.

## Privacy and safety

The current TCP prototype is unencrypted and unauthenticated. Use only on a trusted private LAN, never expose port 8765 to the public internet, and do not send sensitive content. TLS pairing is a blocker for production use.
