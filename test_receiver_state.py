import tempfile, unittest
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from receiver import ReceiverState

class ReceiverStateTests(unittest.TestCase):
    def test_video_frame_is_retained_for_display(self):
        with tempfile.TemporaryDirectory() as folder:
            state = ReceiverState(Path(folder))
            state.update_packet({"kind": "video", "codec": "jpeg", "length": 4}, b"jpeg")
            self.assertEqual(state.last_frame, b"jpeg")
            self.assertEqual(state.frame_count, 1)

    def test_audio_packets_are_saved_with_metadata(self):
        with tempfile.TemporaryDirectory() as folder:
            state = ReceiverState(Path(folder))
            state.update_packet({"kind": "audio_mic", "length": 3, "sampleRate": 48000}, b"pcm")
            self.assertEqual((Path(folder) / "microphone.raw").read_bytes(), b"pcm")
            self.assertIn('"sampleRate": 48000', (Path(folder) / "audio_packets.jsonl").read_text())

if __name__ == "__main__":
    unittest.main()
