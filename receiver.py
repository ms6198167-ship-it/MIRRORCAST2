#!/usr/bin/env python3
"""MirrorCast Windows LAN receiver prototype. Python 3.10+; optional Pillow/zeroconf."""
from __future__ import annotations
import argparse, json, logging, socket, socketserver, struct, threading, time
from pathlib import Path
from typing import Any

MAGIC = b"MCST"
PROTOCOL_VERSION = 1
MAX_HEADER = 16 * 1024
MAX_PAYLOAD = 32 * 1024 * 1024
DEFAULT_PORT = 8765


def recv_exact(sock: socket.socket, size: int) -> bytes:
    chunks = bytearray()
    while len(chunks) < size:
        chunk = sock.recv(size - len(chunks))
        if not chunk:
            raise ConnectionError("peer closed connection")
        chunks.extend(chunk)
    return bytes(chunks)


def encode_packet(header: dict[str, Any], payload: bytes = b"") -> bytes:
    header = dict(header)
    header["length"] = len(payload)
    raw = json.dumps(header, separators=(",", ":")).encode("utf-8")
    if len(raw) > MAX_HEADER or len(payload) > MAX_PAYLOAD:
        raise ValueError("packet exceeds protocol limits")
    return MAGIC + struct.pack("!I", len(raw)) + raw + payload


def read_packet(sock: socket.socket) -> tuple[dict[str, Any], bytes]:
    if recv_exact(sock, 4) != MAGIC:
        raise ValueError("invalid packet magic")
    header_size = struct.unpack("!I", recv_exact(sock, 4))[0]
    if not 1 <= header_size <= MAX_HEADER:
        raise ValueError("invalid header length")
    header = json.loads(recv_exact(sock, header_size).decode("utf-8"))
    if not isinstance(header, dict) or header.get("v") != PROTOCOL_VERSION:
        raise ValueError("unsupported protocol version")
    length = header.get("length")
    if not isinstance(length, int) or length < 0 or length > MAX_PAYLOAD:
        raise ValueError("invalid payload length")
    kind = header.get("kind")
    if kind not in {"hello", "video", "audio_app", "audio_mic", "end"}:
        raise ValueError("unsupported packet kind")
    return header, recv_exact(sock, length) if length else b""


class ReceiverState:
    def __init__(self, output: Path):
        self.output = output
        self.output.mkdir(parents=True, exist_ok=True)
        self.lock = threading.Lock()
        self.last_frame: bytes | None = None
        self.frame_count = 0
        self.audio_app_bytes = 0
        self.audio_mic_bytes = 0
        self.clients = 0
        self.last_activity = "Waiting for a sender"
        self.running = True

    def update_packet(self, header: dict[str, Any], payload: bytes) -> None:
        kind = header["kind"]
        with self.lock:
            self.last_activity = f"Received {kind} packet ({len(payload):,} bytes)"
            if kind == "video":
                if header.get("codec") != "jpeg":
                    raise ValueError("this prototype receiver accepts JPEG video frames")
                self.last_frame = payload
                self.frame_count += 1
            elif kind in ("audio_app", "audio_mic"):
                file_name = "app_audio.raw" if kind == "audio_app" else "microphone.raw"
                with (self.output / file_name).open("ab") as f:
                    f.write(payload)
                key = "audio_app_bytes" if kind == "audio_app" else "audio_mic_bytes"
                setattr(self, key, getattr(self, key) + len(payload))
                # Sidecar records format metadata; raw PCM payloads are not yet played back.
                with (self.output / "audio_packets.jsonl").open("a", encoding="utf-8") as f:
                    f.write(json.dumps({k: v for k, v in header.items() if k != "length"}) + "\n")


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        state: ReceiverState = self.server.state  # type: ignore[attr-defined]
        self.request.settimeout(45)
        with state.lock:
            state.clients += 1
        logging.info("Sender connected from %s", self.client_address[0])
        try:
            while state.running:
                header, payload = read_packet(self.request)
                if header["kind"] == "hello":
                    logging.info("Sender hello: %s", header.get("device", "iOS device"))
                    self.request.sendall(encode_packet({"v": PROTOCOL_VERSION, "kind": "hello", "status": "ok"}))
                    continue
                if header["kind"] == "end":
                    break
                state.update_packet(header, payload)
        except (ConnectionError, TimeoutError, socket.timeout):
            logging.info("Sender disconnected / timed out: %s", self.client_address[0])
        except Exception as exc:
            logging.warning("Rejected sender packet from %s: %s", self.client_address[0], exc)
        finally:
            with state.lock:
                state.clients = max(0, state.clients - 1)


class ThreadedServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True
    def __init__(self, address, handler, state):
        self.state = state
        super().__init__(address, handler)


def start_bonjour(port: int, name: str):
    try:
        from zeroconf import ServiceInfo, Zeroconf
        import socket as _socket
        addresses = []
        for info in _socket.getaddrinfo(_socket.gethostname(), None, _socket.AF_INET, _socket.SOCK_STREAM):
            addr = info[4][0]
            packed = _socket.inet_aton(addr)
            if not addr.startswith("127.") and packed not in addresses:
                addresses.append(packed)
        if not addresses:
            logging.warning("No LAN IPv4 address found; Bonjour advertisement skipped")
            return None
        zc = Zeroconf()
        info = ServiceInfo("_mirrorcast._tcp.local.", f"{name}._mirrorcast._tcp.local.", addresses=addresses,
                           port=port, properties={b"protocol": b"1", b"media": b"jpeg,audio-packets"}, server="mirrorcast.local.")
        zc.register_service(info)
        logging.info("Bonjour service advertised as %s", name)
        return (zc, info)
    except ImportError:
        logging.warning("zeroconf not installed; receiver works by IP but won't appear in Bonjour discovery")
    except Exception as exc:
        logging.warning("Bonjour advertisement failed: %s", exc)
    return None


def ui_loop(state: ReceiverState, host: str, port: int):
    try:
        import tkinter as tk
        from tkinter import ttk
    except Exception:
        logging.warning("Tkinter unavailable; running headless receiver")
        while state.running:
            time.sleep(1)
        return
    try:
        from PIL import Image, ImageTk
        from io import BytesIO
    except ImportError:
        Image = ImageTk = BytesIO = None

    root = tk.Tk()
    root.title("MirrorCast Receiver — Prototype")
    root.geometry("900x650")
    title = ttk.Label(root, text="MirrorCast Receiver", font=("Segoe UI", 20, "bold"))
    title.pack(pady=8)
    ttk.Label(root, text=f"Listening on {host}:{port}  •  Same Wi-Fi/LAN required").pack()
    ttk.Label(root, text=f"Save folder: {state.output.resolve()}").pack(pady=4)
    status = ttk.Label(root, text="Waiting for iPhone broadcast…")
    status.pack(pady=8)
    view = ttk.Label(root, text="Start a ReplayKit broadcast from the iPhone app to show frames here.", anchor="center")
    view.pack(fill="both", expand=True, padx=12, pady=12)
    view.image = None
    def refresh():
        with state.lock:
            frame = state.last_frame
            stats = (state.clients, state.frame_count, state.audio_app_bytes, state.audio_mic_bytes, state.last_activity)
        status.configure(text=f"Senders: {stats[0]}  |  Video frames: {stats[1]}  |  App audio bytes: {stats[2]:,}  |  Mic bytes: {stats[3]:,}\n{stats[4]}")
        if frame and Image is not None:
            try:
                image = Image.open(BytesIO(frame))
                image.thumbnail((850, 480))
                photo = ImageTk.PhotoImage(image)
                view.configure(image=photo, text="")
                view.image = photo
            except Exception as exc:
                logging.debug("Could not render frame: %s", exc)
        root.after(100, refresh)
    def close():
        state.running = False
        root.destroy()
    root.protocol("WM_DELETE_WINDOW", close)
    refresh()
    root.mainloop()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="0.0.0.0", help="bind address (default all local interfaces)")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--name", default="MirrorCast Windows")
    parser.add_argument("--output", type=Path, default=Path("captures"))
    parser.add_argument("--no-ui", action="store_true")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    state = ReceiverState(args.output)
    server = ThreadedServer((args.host, args.port), Handler, state)
    bonjour = start_bonjour(args.port, args.name)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    logging.info("Listening on %s:%s", args.host, args.port)
    try:
        if args.no_ui:
            while True: time.sleep(1)
        else:
            ui_loop(state, args.host, args.port)
    except KeyboardInterrupt:
        pass
    finally:
        state.running = False
        server.shutdown(); server.server_close()
        if bonjour:
            zc, info = bonjour
            zc.unregister_service(info); zc.close()

if __name__ == "__main__":
    main()
