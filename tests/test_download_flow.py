import json
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from server import main


class FakeYoutubeDL:
    calls = []
    fail_download = False

    def __init__(self, opts):
        self.opts = opts
        self.__class__.calls.append(opts)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def extract_info(self, url, download=False):
        self.__class__.calls.append({"url": url, "download": download})
        if "invalid" in url:
            raise RuntimeError("unsupported url")
        if "gone" in url:
            raise RuntimeError("video unavailable")
        if download and self.__class__.fail_download:
            raise RuntimeError("ERROR: unable to download video data: HTTP Error 404: Not Found")
        if download:
            outtmpl = self.opts["outtmpl"]
            path = outtmpl.replace("%(ext)s", "mp4")
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "wb") as file:
                file.write(b"video")
        return {
            "title": "Test Video",
            "extractor": "TestExtractor",
            "formats": [
                {
                    "height": 720,
                    "vcodec": "avc1.64001f",
                    "acodec": "mp4a.40.2",
                    "ext": "mp4",
                    "url": "https://cdn.example.test/temporary-720.mp4",
                },
                {
                    "height": 1080,
                    "vcodec": "avc1.640028",
                    "acodec": "none",
                    "ext": "mp4",
                    "url": "https://cdn.example.test/temporary-1080-video.mp4",
                },
                {
                    "height": None,
                    "vcodec": "none",
                    "acodec": "mp4a.40.2",
                    "ext": "m4a",
                    "url": "https://cdn.example.test/temporary-audio.m4a",
                },
            ],
        }


class DownloadFlowTests(unittest.TestCase):
    def setUp(self):
        FakeYoutubeDL.calls = []
        FakeYoutubeDL.fail_download = False
        self.patcher = patch.object(main.yt_dlp, "YoutubeDL", FakeYoutubeDL)
        self.patcher.start()

    def tearDown(self):
        self.patcher.stop()

    def test_720p_download_uses_height_selector(self):
        response = main.api_download("https://example.test/watch/1", quality=720)

        self.assertEqual(response.media_type, "video/mp4")
        self.assertEqual(
            FakeYoutubeDL.calls[0]["format"],
            "best[height<=720][ext=mp4]/best[height<=720]/bestvideo[height<=720]+bestaudio/best",
        )
        self.assertEqual(FakeYoutubeDL.calls[1]["download"], True)

    def test_1080p_download_uses_height_selector(self):
        main.api_download("https://example.test/watch/1", quality=1080)

        self.assertEqual(
            FakeYoutubeDL.calls[0]["format"],
            "best[height<=1080][ext=mp4]/best[height<=1080]/bestvideo[height<=1080]+bestaudio/best",
        )

    def test_direct_mp4_is_preferred_before_video_audio_merge(self):
        main.api_download("https://example.test/watch/1", quality=1080)

        opts = FakeYoutubeDL.calls[0]
        self.assertEqual(opts["merge_output_format"], "mp4")
        self.assertTrue(opts["format"].startswith("best[height<=1080][ext=mp4]/"))
        self.assertIn("+bestaudio", opts["format"])

    def test_fragment_downloads_are_parallelized_for_hls_fallbacks(self):
        main.api_download("https://example.test/watch/1", quality=1080)

        self.assertEqual(FakeYoutubeDL.calls[0]["concurrent_fragment_downloads"], 16)

    def test_download_after_info_extracts_again_without_reusing_cdn_url(self):
        info = main.api_info("https://example.test/watch/1")
        main.api_download("https://example.test/watch/1", quality=1080)

        self.assertIn("preview_url", info)
        self.assertEqual(FakeYoutubeDL.calls[1]["download"], False)
        self.assertEqual(FakeYoutubeDL.calls[3]["download"], True)
        self.assertEqual(FakeYoutubeDL.calls[3]["url"], "https://example.test/watch/1")
        self.assertNotIn("temporary-1080-video", FakeYoutubeDL.calls[3]["url"])

    def test_download_after_delay_uses_original_url_only(self):
        main.api_info("https://example.test/watch/1")
        main.api_download("https://example.test/watch/1", quality=720)

        download_call = FakeYoutubeDL.calls[3]
        self.assertEqual(download_call["url"], "https://example.test/watch/1")

    def test_invalid_url_returns_structured_download_error(self):
        response = main.api_download("https://invalid.example.test/watch/1", quality=720)
        payload = json.loads(response.body)

        self.assertEqual(response.status_code, 502)
        self.assertEqual(payload["error"]["code"], "DOWNLOAD_FAILED")
        self.assertEqual(payload["error"]["message"], "Video download failed")
        self.assertEqual(payload["error"]["phase"], "download")

    def test_unavailable_video_returns_structured_download_error(self):
        response = main.api_download("https://gone.example.test/watch/1", quality=1080)
        payload = json.loads(response.body)

        self.assertEqual(response.status_code, 502)
        self.assertEqual(payload["error"]["code"], "DOWNLOAD_FAILED")
        self.assertIn("request_id", payload["error"])

    def test_log_sanitizer_removes_query_values(self):
        text = main._sanitize_log_text(
            "failed https://www.example.test/view_video.php?viewkey=abc123&token=secret"
        )

        self.assertEqual(text, "failed https://www.example.test/view_video.php")


if __name__ == "__main__":
    unittest.main()
