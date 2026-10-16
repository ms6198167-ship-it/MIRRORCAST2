# MirrorCast Windows Receiver (prototype)

This is a Python 3.10+ LAN receiver. It accepts framed TCP packets from the MirrorCast ReplayKit extension, displays incoming JPEG screen frames, and saves received app-audio and microphone payloads as raw files with a JSONL metadata sidecar. It advertises `_mirrorcast._tcp.local.` when `zeroconf` is installed.

## Run on Windows

1. Install Python 3.10 or newer from python.org and enable **Add Python to PATH**.
2. Open PowerShell in this folder.
3. Create an environment and install dependencies:

   ```powershell
   py -m venv .venv
   .\.venv\Scripts\Activate.ps1
   python -m pip install --upgrade pip
   pip install -r requirements.txt
   ```
4. Start it:

   ```powershell
   python receiver.py
   ```
5. Allow Python through Windows Defender Firewall on **Private networks only**. Do not expose port 8765 to the public internet.
6. Find the PC's LAN IPv4 address with `ipconfig`; enter it and port `8765` in the iOS app.

For headless operation: `python receiver.py --no-ui`. To change port: `python receiver.py --port 8766` (also change the iOS setting).

## Current prototype behavior

- Receives JPEG screen frames and displays the latest frame in the receiver window (requires Pillow, installed by `requirements.txt`).
- Receives ReplayKit app-audio and microphone sample-buffer bytes and writes `captures/app_audio.raw`, `captures/microphone.raw`, and `captures/audio_packets.jsonl`.
- **Audio is captured and transported, but is not yet decoded, synchronized, or played back.** The raw audio files are diagnostic captures, not directly playable audio files.
- The current TCP transport is **not encrypted and does not authenticate peers**. Use only on a trusted private LAN. Do not use with sensitive content. TLS identity/pairing is a required next milestone.
- This prototype is not AirPlay receiver software; the AirPlay button opens Apple's system route picker for supported AirPlay destinations.
