import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from fastapi.testclient import TestClient

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from server import main


class FakeYoutubeDL:
    calls = []
    fail_download = False
    output_extension = "mp4"

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
            path = outtmpl.replace("%(ext)s", self.__class__.output_extension)
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
                    "height": 292,
                    "vcodec": "avc1.640015",
                    "acodec": "none",
                    "ext": "mp4",
                    "url": "https://cdn.example.test/temporary-292-video.mp4",
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
        FakeYoutubeDL.output_extension = "mp4"
        self.output_dir = tempfile.TemporaryDirectory()
        self.patcher = patch.object(main.yt_dlp, "YoutubeDL", FakeYoutubeDL)
        self.ffprobe_patcher = patch.object(main, "_FFPROBE_PATH", "/usr/bin/ffprobe")
        self.ffmpeg_patcher = patch.object(
            main.shutil,
            "which",
            lambda name: f"/usr/bin/{name}" if name in {"ffmpeg", "ffprobe"} else None,
        )
        self.output_patcher = patch.object(main, "OUTPUT_DIR", Path(self.output_dir.name))
        self.probe_patcher = patch.object(main, "_probe_media", self.fake_probe_media)
        self.patcher.start()
        self.ffprobe_patcher.start()
        self.ffmpeg_patcher.start()
        self.output_patcher.start()
        self.probe_patcher.start()

    def tearDown(self):
        self.output_patcher.stop()
        self.ffmpeg_patcher.stop()
        self.ffprobe_patcher.stop()
        self.probe_patcher.stop()
        self.patcher.stop()
        self.output_dir.cleanup()

    def fake_probe_media(self, path):
        ext = os.path.splitext(path)[1].lower()
        size = os.path.getsize(path) if os.path.exists(path) else 0
        return {
            "path": path,
            "size": size,
            "ext": ext,
            "duration": 12.0 if ext not in main._AUDIO_EXTENSIONS and size > 0 else 0.0,
            "has_video": ext not in main._AUDIO_EXTENSIONS and size > 0,
            "video_codec": "h264" if ext == ".mp4" else "vp9",
            "pix_fmt": "yuv420p" if ext == ".mp4" else "yuv420p",
            "audio_codec": "aac" if ext == ".mp4" else "opus",
            "valid": ext not in main._AUDIO_EXTENSIONS and size > 0,
            "error": None,
        }

    def test_720p_download_uses_height_selector(self):
        response = main.api_download("https://example.test/watch/1", quality=720)

        self.assertEqual(response.media_type, "video/mp4")
        self.assertEqual(
            FakeYoutubeDL.calls[0]["format"],
            "bestvideo[height<=720][vcodec^=avc1][ext=mp4]+bestaudio[acodec^=mp4a][ext=m4a]/"
            "bestvideo[height<=720][vcodec^=avc1]+bestaudio[acodec^=mp4a]/"
            "best[height<=720][vcodec^=avc1][acodec^=mp4a][ext=mp4]/"
            "best[height<=720][vcodec!=none][acodec!=none][ext=mp4]/"
            "bestvideo[vcodec^=avc1][ext=mp4]+bestaudio[acodec^=mp4a][ext=m4a]/"
            "bestvideo[vcodec^=avc1]+bestaudio[acodec^=mp4a]/"
            "best[vcodec!=none][acodec!=none][ext=mp4]",
        )
        self.assertEqual(FakeYoutubeDL.calls[1]["download"], True)

    def test_1080p_download_uses_height_selector(self):
        main.api_download("https://example.test/watch/1", quality=1080)

        self.assertEqual(
            FakeYoutubeDL.calls[0]["format"],
            "bestvideo[height<=1080][vcodec^=avc1][ext=mp4]+bestaudio[acodec^=mp4a][ext=m4a]/"
            "bestvideo[height<=1080][vcodec^=avc1]+bestaudio[acodec^=mp4a]/"
            "best[height<=1080][vcodec^=avc1][acodec^=mp4a][ext=mp4]/"
            "best[height<=1080][vcodec!=none][acodec!=none][ext=mp4]/"
            "bestvideo[vcodec^=avc1][ext=mp4]+bestaudio[acodec^=mp4a][ext=m4a]/"
            "bestvideo[vcodec^=avc1]+bestaudio[acodec^=mp4a]/"
            "best[vcodec!=none][acodec!=none][ext=mp4]",
        )

    def test_direct_mp4_is_preferred_before_video_audio_merge(self):
        main.api_download("https://example.test/watch/1", quality=1080)

        opts = FakeYoutubeDL.calls[0]
        self.assertEqual(opts["merge_output_format"], "mp4")
        self.assertTrue(opts["format"].startswith("bestvideo[height<=1080][vcodec^=avc1][ext=mp4]+bestaudio"))
        self.assertIn("+bestaudio", opts["format"])
        self.assertIn("[vcodec!=none][acodec!=none]", opts["format"])
        self.assertIn("[vcodec^=avc1]", opts["format"])
        self.assertIn("[acodec^=mp4a]", opts["format"])

    def test_format_id_selector_is_honored_when_present(self):
        main.api_download(
            "https://example.test/watch/1",
            quality=720,
            format_id="bestvideo[height<=480]+bestaudio",
        )

        self.assertEqual(FakeYoutubeDL.calls[0]["format"], "bestvideo[height<=480]+bestaudio")

    def test_audio_only_temp_file_is_not_returned_as_video(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            audio_path = os.path.join(tmpdir, "video.m4a")
            video_path = os.path.join(tmpdir, "video.mp4")
            with open(audio_path, "wb") as file:
                file.write(b"a" * 100)
            with open(video_path, "wb") as file:
                file.write(b"v" * 10)

            selected, probe = main._select_downloaded_video_file(tmpdir)
            self.assertEqual(selected, video_path)
            self.assertTrue(probe["valid"])

    def test_intermediate_split_video_audio_files_are_not_returned(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            intermediate_video = os.path.join(tmpdir, "video.f137.mp4")
            audio_path = os.path.join(tmpdir, "video.f140.m4a")
            final_path = os.path.join(tmpdir, "video.mp4")
            for path, content in [
                (intermediate_video, b"v" * 100),
                (audio_path, b"a" * 120),
                (final_path, b"final"),
            ]:
                with open(path, "wb") as file:
                    file.write(content)

            selected, probe = main._select_downloaded_video_file(tmpdir)
            self.assertEqual(selected, final_path)
            self.assertTrue(probe["valid"])

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

    def test_empty_download_url_returns_validation_error_without_ytdlp(self):
        response = main.api_download("", quality=720)
        payload = json.loads(response.body)

        self.assertEqual(response.status_code, 400)
        self.assertEqual(payload["error"]["code"], "INVALID_URL")
        self.assertEqual(payload["error"]["phase"], "validation")
        self.assertEqual(FakeYoutubeDL.calls, [])

    def test_info_rejects_health_url_as_video_url(self):
        response = main.api_info("http://100.80.105.62:9876/api/health")
        payload = json.loads(response.body)

        self.assertEqual(response.status_code, 400)
        self.assertEqual(payload["error"]["code"], "INVALID_VIDEO_URL")
        self.assertEqual(FakeYoutubeDL.calls, [])

    def test_download_rejects_server_url_before_ytdlp(self):
        response = main.api_download("http://100.80.105.62:9876/api/health", quality=720)
        payload = json.loads(response.body)

        self.assertEqual(response.status_code, 400)
        self.assertEqual(payload["error"]["code"], "INVALID_VIDEO_URL")
        self.assertEqual(FakeYoutubeDL.calls, [])

    def test_download_requires_ffmpeg_with_clear_error(self):
        with patch.object(main.shutil, "which", return_value=None):
            response = main.api_download("https://example.test/watch/1", quality=720)
        payload = json.loads(response.body)

        self.assertEqual(response.status_code, 503)
        self.assertEqual(payload["error"]["code"], "MISSING_PREREQUISITE")
        self.assertIn("ffmpeg", payload["error"]["message"])

    def test_download_requires_ffprobe_with_clear_error(self):
        with patch.object(main, "_FFPROBE_PATH", None), patch.object(
            main.shutil,
            "which",
            lambda name: "/usr/bin/ffmpeg" if name == "ffmpeg" else None,
        ):
            response = main.api_download("https://example.test/watch/1", quality=720)
        payload = json.loads(response.body)

        self.assertEqual(response.status_code, 503)
        self.assertEqual(payload["error"]["code"], "MISSING_PREREQUISITE")
        self.assertIn("ffprobe", payload["error"]["message"])

    def test_health_reports_diagnostics(self):
        request = Mock()
        request.url.port = 9876
        payload = main.health(request)

        self.assertEqual(payload["status"], "ok")
        self.assertEqual(payload["server_name"], "VideoLoader local server")
        self.assertEqual(payload["port"], 9876)
        self.assertTrue(payload["ffmpeg"])
        self.assertTrue(payload["ffprobe"])
        self.assertTrue(payload["output_dir_writable"])
        self.assertEqual(payload["normalization_target"]["container"], "mp4")

    def test_api_health_route_returns_videoloader_identity(self):
        response = TestClient(main.app).get("/api/health")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["server_name"], "VideoLoader local server")

    def test_info_filters_unusual_raw_heights(self):
        payload = main.api_info("https://example.test/watch/1")

        self.assertIn(720, payload["heights"])
        self.assertIn(1080, payload["heights"])
        self.assertNotIn(292, payload["heights"])

    def test_normalizes_non_ios_file_before_response(self):
        FakeYoutubeDL.output_extension = "webm"

        with patch.object(main, "_normalize_to_ios_mp4") as normalize:
            def fake_normalize(source_path, tmpdir):
                output_path = os.path.join(tmpdir, "normalized.mp4")
                with open(output_path, "wb") as file:
                    file.write(b"normalized video")
                return output_path, self.fake_probe_media(output_path), None
            normalize.side_effect = fake_normalize

            response = main.api_download("https://example.test/watch/1", quality=720)

        self.assertEqual(response.media_type, "video/mp4")
        self.assertTrue(normalize.called)
        saved = list(Path(self.output_dir.name).glob("*.mp4"))
        self.assertEqual(len(saved), 1)

    def test_unavailable_video_returns_structured_download_error(self):
        response = main.api_download("https://gone.example.test/watch/1", quality=1080)
        payload = json.loads(response.body)

        self.assertEqual(response.status_code, 502)
        self.assertEqual(payload["error"]["code"], "DOWNLOAD_FAILED")
        self.assertIn("request_id", payload["error"])

    def test_download_error_includes_exception_type_and_detail(self):
        FakeYoutubeDL.fail_download = True
        response = main.api_download("https://example.test/watch/1", quality=720)
        payload = json.loads(response.body)

        self.assertEqual(response.status_code, 502)
        self.assertEqual(payload["error"]["exception_type"], "RuntimeError")
        self.assertIn("HTTP Error 404", payload["error"]["detail"])

    def test_log_sanitizer_removes_query_values(self):
        text = main._sanitize_log_text(
            "failed https://www.example.test/view_video.php?viewkey=abc123&token=secret"
        )

        self.assertEqual(text, "failed https://www.example.test/view_video.php")


if __name__ == "__main__":
    unittest.main()
