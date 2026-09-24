import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch
from fastapi.testclient import TestClient
from server import main


class ServerContractTests(unittest.TestCase):
    def tearDown(self):
        main._javascript_runtime.cache_clear()

    def test_runtime_rejects_old_and_accepts_supported_deno(self):
        for version, expected in [('deno 2.2.0', False), ('deno 2.3.0', True), ('deno 2.6.1', True)]:
            main._javascript_runtime.cache_clear()
            with patch.object(main.shutil, 'which', return_value='deno'), patch.object(main.subprocess, 'run', return_value=Mock(returncode=0, stdout=version)):
                self.assertEqual(main._javascript_runtime()['available'], expected)

    def test_missing_deno_is_reported_without_breaking_other_sources(self):
        main._javascript_runtime.cache_clear()
        with patch.object(main.shutil, 'which', return_value=None):
            self.assertFalse(main._javascript_runtime()['available'])

    def test_health_distinguishes_missing_media_tools(self):
        main._javascript_runtime.cache_clear()
        with tempfile.TemporaryDirectory() as directory, patch.object(main, 'OUTPUT_DIR', Path(directory)), patch.object(main.shutil, 'which', return_value=None):
            response = TestClient(main.app).get('/api/health')
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()['status'], 'degraded')
            self.assertFalse(response.json()['javascript_runtime']['available'])

    def test_info_maps_login_and_unsupported_errors(self):
        for text, code in [('Please sign in', 'LOGIN_REQUIRED'), ('Unsupported URL', 'UNSUPPORTED_SITE'), ('DRM protected', 'DRM_PROTECTED')]:
            with patch.object(main, '_extract_info', side_effect=RuntimeError(text)):
                response = TestClient(main.app).get('/api/info', params={'url': 'https://example.org/watch'})
                self.assertEqual(response.status_code, 422)
                self.assertEqual(response.json()['error']['code'], code)

    def test_live_and_drm_are_rejected(self):
        self.assertIsNotNone(main._reject_unsupported_video({'is_live': True}))
        self.assertIsNotNone(main._reject_unsupported_video({'has_drm': True}))
        self.assertIsNone(main._reject_unsupported_video({'live_status': 'was_live'}))

    def test_playlist_metadata_is_rejected(self):
        with patch.object(main.yt_dlp, 'YoutubeDL') as factory:
            factory.return_value.__enter__.return_value.extract_info.return_value = {'_type': 'playlist', 'entries': [{}]}
            response = TestClient(main.app).get('/api/info', params={'url': 'https://example.org/playlist'})
            self.assertEqual(response.status_code, 422)

    def test_quality_bound_applies_to_all_fallbacks(self):
        selector = main._format_selector(720)
        self.assertTrue(all('[height<=?720]' in part for part in selector.split('/')))
        self.assertIn('bestvideo[height<=?720]+bestaudio', selector)

    def test_direct_file_without_resolution_survives_format_selection(self):
        # Exercise yt-dlp itself: direct files often have no height or codec metadata.
        with main.yt_dlp.YoutubeDL({'quiet': True, 'format': main._format_selector(720)}) as ydl:
            info = ydl.process_ie_result({
                'id': 'direct', 'title': 'Direct file',
                'formats': [{'format_id': 'http', 'url': 'https://example.org/video.mp4', 'ext': 'mp4'}],
            }, download=False)
        self.assertEqual(info['format_id'], 'http')

    def test_quality_selection_does_not_choose_known_higher_resolution(self):
        with main.yt_dlp.YoutubeDL({'quiet': True, 'format': main._format_selector(720)}) as ydl:
            info = ydl.process_ie_result({
                'id': 'quality', 'title': 'Quality selection',
                'formats': [dict(format_id=str(h), url=f'https://example.org/{h}.mp4',
                                 ext='mp4', height=h, vcodec='avc1', acodec='mp4a')
                            for h in (480, 1080)],
            }, download=False)
        self.assertEqual(info['height'], 480)


@unittest.skipUnless(os.name == 'nt' and shutil.which('pwsh'), 'Windows PowerShell integration tests')
class WindowsStartupTests(unittest.TestCase):
    def test_invalid_port_stops_before_install(self):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / 'start.ps1'
            shutil.copyfile(Path(__file__).resolve().parents[1] / 'server/start.ps1', script)
            env = dict(os.environ, PORT='invalid')
            result = subprocess.run(['pwsh', '-NoProfile', '-File', str(script), '-CheckOnly'], env=env, capture_output=True, text=True, timeout=20)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('PORT muss', result.stderr)
            self.assertFalse((Path(directory) / '.venv').exists())
