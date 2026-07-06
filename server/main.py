"""VideoLoader-Server: liefert Videoinfos und Downloads über yt-dlp."""

import json
import logging
import os
import re
import shutil
import subprocess
import tempfile
import traceback
import uuid
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

import yt_dlp
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import JSONResponse
from fastapi.responses import FileResponse
from yt_dlp.version import __version__ as YT_DLP_VERSION

app = FastAPI(title="VideoLoader Server")
logger = logging.getLogger("videoloader")
logging.basicConfig(level=os.getenv("VIDEOLOADER_LOG_LEVEL", "INFO").upper())

SERVER_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = Path(os.getenv("VIDEOLOADER_OUTPUT_DIR", SERVER_DIR / "downloads")).resolve()


@app.get("/")
def root():
    return {"status": "ok", "hinweis": "VideoLoader-Server läuft. Diese Adresse in der App eintragen."}


@app.get("/health")
def health():
    diagnostics = _diagnostics()
    required_ok = diagnostics["output_dir"]["writable"] and diagnostics["ffmpeg"]["available"]
    return {
        "status": "ok" if required_ok else "degraded",
        "yt_dlp": YT_DLP_VERSION,
        "ffmpeg": diagnostics["ffmpeg"]["available"],
        "ffprobe": diagnostics["ffprobe"]["available"],
        "output_dir_writable": diagnostics["output_dir"]["writable"],
    }


@app.get("/api/health")
def api_health():
    return health()


@app.get("/api/diagnostics")
def api_diagnostics():
    return _diagnostics()


def _command_status(name: str) -> dict[str, str | bool | None]:
    path = shutil.which(name)
    return {"available": bool(path), "path": path}


def _output_dir_status() -> dict[str, str | bool | None]:
    try:
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        probe = OUTPUT_DIR / f".write-test-{uuid.uuid4().hex}"
        probe.write_text("ok", encoding="utf-8")
        probe.unlink(missing_ok=True)
        return {"path": str(OUTPUT_DIR), "writable": True, "error": None}
    except Exception as exc:
        return {"path": str(OUTPUT_DIR), "writable": False, "error": str(exc)}


def _diagnostics() -> dict:
    return {
        "status": "ok",
        "yt_dlp": {"available": True, "version": YT_DLP_VERSION},
        "ffmpeg": _command_status("ffmpeg"),
        "ffprobe": _command_status("ffprobe"),
        "aria2c": _command_status("aria2c"),
        "output_dir": _output_dir_status(),
        "env": {
            "VIDEOLOADER_OUTPUT_DIR": os.getenv("VIDEOLOADER_OUTPUT_DIR"),
            "VIDEOLOADER_LOG_LEVEL": os.getenv("VIDEOLOADER_LOG_LEVEL"),
        },
    }


def _safe_url(url: str, max_length: int = 160) -> str:
    parts = urlsplit(url)
    safe = urlunsplit((parts.scheme, parts.netloc, parts.path, "", ""))
    if len(safe) > max_length:
        return safe[: max_length - 3] + "..."
    return safe


def _sanitize_log_text(text: str) -> str:
    return re.sub(r"https?://[^\s)]+", lambda match: _safe_url(match.group(0)), text)


def _validate_video_url(url: str) -> str:
    trimmed = (url or "").strip()
    if not trimmed:
        raise HTTPException(status_code=400, detail="Bitte gib einen Video-Link ein.")
    parts = urlsplit(trimmed)
    if parts.scheme not in {"http", "https"} or not parts.netloc:
        raise HTTPException(status_code=400, detail="Bitte gib einen gültigen http- oder https-Link ein.")
    return trimmed


def _missing_prerequisite_response(request_id: str, message: str, detail: str | None = None):
    body = {
        "code": "MISSING_PREREQUISITE",
        "message": message,
        "phase": "startup",
        "request_id": request_id,
    }
    if detail:
        body["detail"] = detail
    return JSONResponse(status_code=503, content={"error": body})


def _safe_filename(title: str, fallback: str = "video") -> str:
    safe = "".join(c for c in title if c.isalnum() or c in " -_").strip()
    safe = re.sub(r"\s+", " ", safe)[:80].strip()
    return safe or fallback


def _unique_output_path(title: str, suffix: str) -> Path:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    base = _safe_filename(title)
    target = OUTPUT_DIR / f"{base}{suffix}"
    counter = 2
    while target.exists():
        target = OUTPUT_DIR / f"{base} {counter}{suffix}"
        counter += 1
    return target


class YtdlpLogger:
    def debug(self, message):
        logger.debug("yt_dlp %s", _sanitize_log_text(str(message)))

    def warning(self, message):
        logger.warning("yt_dlp %s", _sanitize_log_text(str(message)))

    def error(self, message):
        logger.error("yt_dlp %s", _sanitize_log_text(str(message)))


def _http_headers(url: str) -> dict[str, str]:
    parts = urlsplit(url)
    origin = urlunsplit((parts.scheme, parts.netloc, "/", "", "")) if parts.scheme and parts.netloc else ""
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
            "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 "
            "Mobile/15E148 Safari/604.1"
        ),
        "Accept-Language": "en-US,en;q=0.9",
    }
    if origin:
        headers["Referer"] = origin
    return headers


def _base_ydl_options(url: str) -> dict:
    return {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "http_headers": _http_headers(url),
        "extractor_args": {"youtube": {"player_client": ["ios", "android", "web"]}},
        "logger": YtdlpLogger(),
    }


def _extract_info(url: str) -> dict:
    url = _validate_video_url(url)
    opts = _base_ydl_options(url)
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=False)
    if info.get("_type") == "playlist":
        entries = [e for e in (info.get("entries") or []) if e]
        if not entries:
            raise HTTPException(status_code=422, detail="Unter diesem Link wurde kein Video gefunden.")
        info = entries[0]
    return info


@app.get("/api/info")
def api_info(url: str = Query(..., description="Link zum Video")):
    try:
        info = _extract_info(url)
    except HTTPException:
        raise
    except Exception as exc:  # yt-dlp wirft je nach Plattform verschiedene Fehler
        raise HTTPException(
            status_code=422,
            detail=f"Dieser Link wird nicht unterstützt oder das Video ist nicht erreichbar. ({exc})",
        )

    formats = info.get("formats") or []
    heights = sorted(
        {f["height"] for f in formats if f.get("height") and f.get("vcodec") not in (None, "none")},
        reverse=True,
    )

    # Für die Vorschau ein direkt abspielbares MP4 (Bild + Ton) bis 720p suchen
    preview_url = None
    preview_height = -1
    for f in formats:
        if (
            f.get("vcodec") not in (None, "none")
            and f.get("acodec") not in (None, "none")
            and f.get("ext") == "mp4"
            and str(f.get("url", "")).startswith("http")
            and (f.get("height") or 0) <= 720
            and (f.get("height") or 0) > preview_height
        ):
            preview_height = f.get("height") or 0
            preview_url = f["url"]

    return {
        "title": info.get("title") or "Video",
        "uploader": info.get("uploader") or info.get("channel"),
        "duration": info.get("duration"),
        "thumbnail": info.get("thumbnail"),
        "preview_url": preview_url,
        "heights": heights,
    }


def _format_selector(quality: int | None) -> str:
    h = f"[height<={quality}]" if quality else ""
    return "/".join(
        [
            f"bestvideo{h}[vcodec^=avc1][ext=mp4]+bestaudio[acodec^=mp4a][ext=m4a]",
            f"bestvideo{h}[vcodec^=avc1]+bestaudio[acodec^=mp4a]",
            f"best{h}[vcodec^=avc1][acodec^=mp4a][ext=mp4]",
            f"best{h}[vcodec!=none][acodec!=none][ext=mp4]",
            "bestvideo[vcodec^=avc1][ext=mp4]+bestaudio[acodec^=mp4a][ext=m4a]",
            "bestvideo[vcodec^=avc1]+bestaudio[acodec^=mp4a]",
            "best[vcodec!=none][acodec!=none][ext=mp4]",
        ]
    )


_ARIA2C_PATH = shutil.which("aria2c")
_FFPROBE_PATH = shutil.which("ffprobe")
_VIDEO_EXTENSIONS = {".mp4", ".m4v", ".mov", ".webm", ".mkv"}
_AUDIO_EXTENSIONS = {".m4a", ".mp3", ".aac", ".opus", ".ogg", ".weba", ".wav"}


def _has_video_track(path: str) -> bool:
    ext = os.path.splitext(path)[1].lower()
    if ext in _AUDIO_EXTENSIONS:
        return False
    if _FFPROBE_PATH:
        try:
            result = subprocess.run(
                [
                    _FFPROBE_PATH,
                    "-v",
                    "error",
                    "-show_entries",
                    "stream=codec_type",
                    "-of",
                    "json",
                    path,
                ],
                capture_output=True,
                text=True,
                timeout=10,
                check=False,
            )
            if result.returncode == 0:
                data = json.loads(result.stdout or "{}")
                return any(
                    stream.get("codec_type") == "video"
                    for stream in data.get("streams", [])
                )
        except Exception as exc:
            logger.warning(
                "ffprobe_failed path=%s exception_type=%s message=%s",
                path,
                type(exc).__name__,
                exc,
            )
    return ext in _VIDEO_EXTENSIONS


def _select_downloaded_video_file(tmpdir: str) -> str | None:
    files = [os.path.join(tmpdir, f) for f in os.listdir(tmpdir)]
    files = [f for f in files if os.path.isfile(f)]
    video_files = [f for f in files if _has_video_track(f)]
    if not video_files:
        return None
    return max(video_files, key=os.path.getsize)


def _download_options(url: str, tmpdir: str, format_selector: str) -> dict:
    opts = _base_ydl_options(url)
    opts.update({
        "format": format_selector,
        "outtmpl": os.path.join(tmpdir, "video.%(ext)s"),
        "merge_output_format": "mp4",
        "retries": 5,
        "fragment_retries": 5,
        # Bei in Häppchen aufgeteilten Quellen (HLS/DASH) so viele Stücke
        # gleichzeitig laden wie sinnvoll möglich.
        "concurrent_fragment_downloads": 16,
        "extractor_retries": 3,
        "file_access_retries": 3,
        "socket_timeout": 30,
    })
    if _ARIA2C_PATH:
        # Für normale (nicht fragmentierte) Downloads nutzt aria2c mehrere
        # parallele Verbindungen zur Quelle statt nur einer – oft der größte
        # Geschwindigkeitsgewinn. Wird automatisch übersprungen, falls
        # aria2c auf diesem Server nicht installiert ist.
        opts["external_downloader"] = "aria2c"
        opts["external_downloader_args"] = {
            "aria2c": ["-x", "16", "-s", "16", "-k", "1M", "--summary-interval=0"]
        }
    return opts


def _download_error_response(
    request_id: str,
    exception_type: str | None = None,
    detail: str | None = None,
):
    body: dict = {
        "code": "DOWNLOAD_FAILED",
        "message": "Video download failed",
        "phase": "download",
        "request_id": request_id,
    }
    # Der echte technische Grund (yt-dlp-Fehlertyp + Nachricht) wird mitgegeben,
    # damit die App ihn anzeigen kann und Fehler ohne Server-Log-Zugriff
    # diagnostizierbar sind. Die Nachricht ist bereits URL-bereinigt.
    if exception_type:
        body["exception_type"] = exception_type
    if detail:
        body["detail"] = detail
    return JSONResponse(status_code=502, content={"error": body})


@app.get("/api/download")
def api_download(
    url: str = Query(..., description="Link zum Video"),
    height: int | None = Query(None, description="Maximale Auflösung, z. B. 1080"),
    quality: int | None = Query(None, description="Maximale Auflösung, z. B. 1080"),
    format_id: str | None = Query(None, description="yt-dlp Format-Selektor"),
):
    request_id = uuid.uuid4().hex[:12]
    try:
        url = _validate_video_url(url)
    except HTTPException as exc:
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": {
                    "code": "INVALID_URL",
                    "message": exc.detail,
                    "phase": "validation",
                    "request_id": request_id,
                }
            },
        )
    output_status = _output_dir_status()
    if not output_status["writable"]:
        return _missing_prerequisite_response(
            request_id,
            "Der Download-Ordner ist nicht beschreibbar.",
            str(output_status.get("error") or ""),
        )
    if not shutil.which("ffmpeg"):
        return _missing_prerequisite_response(
            request_id,
            "ffmpeg wurde nicht gefunden. Bitte installiere ffmpeg und starte den Server neu.",
            "Windows: winget install Gyan.FFmpeg oder choco install ffmpeg. macOS: brew install ffmpeg.",
        )

    requested_quality = quality if quality is not None else height
    format_selector = (
        format_id.strip()
        if isinstance(format_id, str) and format_id.strip()
        else _format_selector(requested_quality)
    )
    tmpdir = tempfile.mkdtemp(prefix="videoloader_")
    try:
        logger.info(
            "download_start request_id=%s url=%s quality=%s selector=%s yt_dlp=%s phase=download",
            request_id,
            _safe_url(url),
            requested_quality,
            format_selector,
            YT_DLP_VERSION,
        )
        opts = _download_options(url, tmpdir, format_selector)
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(url, download=True)
    except Exception as exc:
        shutil.rmtree(tmpdir, ignore_errors=True)
        exc_type = type(exc).__name__
        exc_msg = _sanitize_log_text(str(exc))
        logger.error(
            "download_failed request_id=%s url=%s quality=%s selector=%s yt_dlp=%s "
            "extractor=%s phase=download exception_type=%s message=%s traceback=%s",
            request_id,
            _safe_url(url),
            requested_quality,
            format_selector,
            YT_DLP_VERSION,
            getattr(exc, "ie", None) or "unknown",
            exc_type,
            exc_msg,
            _sanitize_log_text(traceback.format_exc()),
        )
        return _download_error_response(request_id, exception_type=exc_type, detail=exc_msg)

    path = _select_downloaded_video_file(tmpdir)
    if not path:
        shutil.rmtree(tmpdir, ignore_errors=True)
        logger.error(
            "download_failed request_id=%s url=%s quality=%s selector=%s yt_dlp=%s "
            "extractor=unknown phase=download exception_type=MissingVideoOutput message=no_video_file_created",
            request_id,
            _safe_url(url),
            requested_quality,
            format_selector,
            YT_DLP_VERSION,
        )
        return _download_error_response(
            request_id,
            exception_type="MissingVideoOutput",
            detail=(
                "yt-dlp hat keine abspielbare Videodatei erzeugt "
                "(evtl. fehlt ffmpeg/ffprobe oder das Format hatte keine Videospur)."
            ),
        )

    title = info.get("title") or "video"
    source_path = Path(path)
    output_path = _unique_output_path(title, source_path.suffix or ".mp4")
    shutil.move(str(source_path), output_path)
    shutil.rmtree(tmpdir, ignore_errors=True)
    safe_title = _safe_filename(title)

    return FileResponse(
        output_path,
        media_type="video/mp4",
        filename=f"{safe_title}.mp4",
    )
