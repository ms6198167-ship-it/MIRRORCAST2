# MirrorCast TCP framing v1

- Transport: TCP, default port 8765.
- Frame: ASCII magic `MCST` (4 bytes), header byte length (unsigned 32-bit network byte order), UTF-8 JSON header, payload bytes.
- Header must contain `v: 1`, `kind`, and `length` (payload bytes). Header limit 16 KiB; payload limit 32 MiB.
- `hello`: zero-length payload, optional `device`; receiver replies with a framed `hello` status packet.
- `video`: `codec: "jpeg"`, `timestamp` in seconds, JPEG payload.
- `audio_app` / `audio_mic`: `codec: "replaykit-raw"`, `sampleRate`, `channels`, `timestamp`, sample-buffer payload. Payload encoding is not normalized yet and must not be assumed to be portable PCM.
- `end`: zero-length payload.

This is an unauthenticated prototype protocol. Do not transmit private or sensitive content on untrusted networks. Before production, add TLS with certificate/public-key pinning or an explicit pairing handshake, strict limits, protocol negotiation, and replay/session protections.
