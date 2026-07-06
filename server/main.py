"""VideoLoader-Server: liefert Videoinfos und Downloads über yt-dlp."""

import logging
import os
import re
import shutil
import tempfile
import traceback
import uuid
from urllib.parse import urlsplit, urlunsplit

import yt_dlp
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import JSONResponse
from fastapi.responses import FileResponse
from starlette.background import BackgroundTask
from yt_dlp.version import __version__ as YT_DLP_VERSION

app = FastAPI(title="VideoLoader Server")
logger = logging.getLogger("videoloader")


@app.get("/")
def root():
    return {"status": "ok", "hinweis": "VideoLoader-Server läuft. Diese Adresse in der App eintragen."}


@app.get("/health")
def health():
    return {
        "status": "ok",
        "yt_dlp": YT_DLP_VERSION,
        "ffmpeg": bool(_FFMPEG_PATH),
        "aria2c": bool(_ARIA2C_PATH),
    }


def _safe_url(url: str, max_length: int = 160) -> str:
    parts = urlsplit(url)
    safe = urlunsplit((parts.scheme, parts.netloc, parts.path, "", ""))
    if len(safe) > max_length:
        return safe[: max_length - 3] + "..."
    return safe


def _sanitize_log_text(text: str) -> str:
    return re.sub(r"https?://[^\s)]+", lambda match: _safe_url(match.group(0)), text)


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
        "extractor_args": {"youtube": {"player_client": ["android", "web"]}},
        "logger": YtdlpLogger(),
    }


def _extract_info(url: str) -> dict:
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
    # Getrennte Video+Audio-Streams zuerst (liefern 720p/1080p auf YouTube).
    # H.264 (avc1) ist auf iPhone nativ decodierbar; m4a Audio fügt sich sauber
    # in MP4 ein. Fallback auf kombinierte Streams falls ffmpeg fehlt.
    return (
        f"bestvideo{h}[vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/"
        f"bestvideo{h}[vcodec^=avc1]+bestaudio/"
        f"bestvideo{h}[ext=mp4]+bestaudio[ext=m4a]/"
        f"bestvideo{h}+bestaudio/"
        f"best{h}[ext=mp4]/"
        f"best{h}/"
        f"best"
    )


_ARIA2C_PATH = shutil.which("aria2c")
_FFMPEG_PATH = shutil.which("ffmpeg")

if not _FFMPEG_PATH:
    logger.warning(
        "ffmpeg nicht gefunden – getrennte Video+Audio-Streams (720p/1080p) "
        "können nicht zusammengeführt werden. Bitte 'brew install ffmpeg' ausführen."
    )


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
    if _FFMPEG_PATH:
        opts["ffmpeg_location"] = os.path.dirname(_FFMPEG_PATH)
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


def _download_error_response(request_id: str):
    return JSONResponse(
        status_code=502,
        content={
            "error": {
                "code": "DOWNLOAD_FAILED",
                "message": "Video download failed",
                "phase": "download",
                "request_id": request_id,
            }
        },
    )


@app.get("/api/download")
def api_download(
    url: str = Query(..., description="Link zum Video"),
    height: int | None = Query(None, description="Maximale Auflösung, z. B. 1080"),
    quality: int | None = Query(None, description="Maximale Auflösung, z. B. 1080"),
):
    request_id = uuid.uuid4().hex[:12]
    requested_quality = quality if quality is not None else height
    format_selector = _format_selector(requested_quality)
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
        logger.error(
            "download_failed request_id=%s url=%s quality=%s selector=%s yt_dlp=%s "
            "extractor=%s phase=download exception_type=%s message=%s traceback=%s",
            request_id,
            _safe_url(url),
            requested_quality,
            format_selector,
            YT_DLP_VERSION,
            getattr(exc, "ie", None) or "unknown",
            type(exc).__name__,
            _sanitize_log_text(str(exc)),
            _sanitize_log_text(traceback.format_exc()),
        )
        return _download_error_response(request_id)

    files = [os.path.join(tmpdir, f) for f in os.listdir(tmpdir)]
    files = [f for f in files if os.path.isfile(f)]
    if not files:
        shutil.rmtree(tmpdir, ignore_errors=True)
        logger.error(
            "download_failed request_id=%s url=%s quality=%s selector=%s yt_dlp=%s "
            "extractor=unknown phase=download exception_type=MissingOutput message=no_file_created",
            request_id,
            _safe_url(url),
            requested_quality,
            format_selector,
            YT_DLP_VERSION,
        )
        return _download_error_response(request_id)
    path = max(files, key=os.path.getsize)

    title = (info.get("title") or "video")[:80]
    safe_title = "".join(c for c in title if c.isalnum() or c in " -_").strip() or "video"

    return FileResponse(
        path,
        media_type="video/mp4",
        filename=f"{safe_title}.mp4",
        background=BackgroundTask(shutil.rmtree, tmpdir, ignore_errors=True),
    )
