import socket, threading, unittest
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from receiver import encode_packet, read_packet, MAX_PAYLOAD

class ProtocolTests(unittest.TestCase):
    def round_trip(self, header, payload=b""):
        left, right = socket.socketpair()
        try:
            encoded = encode_packet(header, payload)
            t = threading.Thread(target=lambda: (left.sendall(encoded), left.close()))
            t.start()
            got_header, got_payload = read_packet(right)
            t.join(timeout=2)
            return got_header, got_payload
        finally:
            right.close()

    def test_video_packet_round_trip(self):
        header, payload = self.round_trip({"v": 1, "kind": "video", "codec": "jpeg", "timestamp": 123}, b"jpegdata")
        self.assertEqual(header["kind"], "video")
        self.assertEqual(header["length"], 8)
        self.assertEqual(payload, b"jpegdata")

    def test_zero_length_hello(self):
        header, payload = self.round_trip({"v": 1, "kind": "hello", "device": "test"})
        self.assertEqual(header["kind"], "hello")
        self.assertEqual(payload, b"")

    def test_reject_oversized_payload(self):
        with self.assertRaises(ValueError):
            encode_packet({"v": 1, "kind": "video"}, b"x" * (MAX_PAYLOAD + 1))

    def test_reject_bad_magic(self):
        left, right = socket.socketpair()
        try:
            left.sendall(b"NOPE" + b"\x00\x00\x00\x02{}")
            left.close()
            with self.assertRaises(ValueError):
                read_packet(right)
        finally:
            right.close()

if __name__ == "__main__":
    unittest.main()
