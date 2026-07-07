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
from urllib.parse import unquote as urllib_unquote

import yt_dlp
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from fastapi.responses import FileResponse
from yt_dlp.version import __version__ as YT_DLP_VERSION

app = FastAPI(title="VideoLoader Server")
logger = logging.getLogger("videoloader")
logging.basicConfig(level=os.getenv("VIDEOLOADER_LOG_LEVEL", "INFO").upper())

SERVER_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = Path(os.getenv("VIDEOLOADER_OUTPUT_DIR", SERVER_DIR / "downloads")).resolve()
_NORMALIZATION_TARGET = {
    "container": "mp4",
    "video_codec": "h264",
    "pixel_format": "yuv420p",
    "audio_codec": "aac",
    "faststart": True,
}


@app.get("/")
def root():
    return {"status": "ok", "hinweis": "VideoLoader-Server läuft. Diese Adresse in der App eintragen."}


@app.get("/health")
def health(request: Request = None):
    diagnostics = _diagnostics()
    port = request.url.port if request is not None else None
    required_ok = (
        diagnostics["output_dir"]["writable"]
        and diagnostics["ffmpeg"]["available"]
        and diagnostics["ffprobe"]["available"]
    )
    payload = {
        "status": "ok" if required_ok else "degraded",
        "server_name": "VideoLoader local server",
        "port": port,
        "yt_dlp": YT_DLP_VERSION,
        "ffmpeg": diagnostics["ffmpeg"]["available"],
        "ffmpeg_path": diagnostics["ffmpeg"]["path"],
        "ffprobe": diagnostics["ffprobe"]["available"],
        "ffprobe_path": diagnostics["ffprobe"]["path"],
        "output_dir": diagnostics["output_dir"]["path"],
        "output_dir_writable": diagnostics["output_dir"]["writable"],
        "normalization_target": _NORMALIZATION_TARGET,
    }
    logger.info(
        "VideoLoader /api/health requested port=%s yt_dlp=%s ffmpeg=%s ffprobe=%s output_dir=%s",
        port,
        YT_DLP_VERSION,
        diagnostics["ffmpeg"]["path"] or "missing",
        diagnostics["ffprobe"]["path"] or "missing",
        diagnostics["output_dir"]["path"],
    )
    return payload


@app.get("/api/health")
def api_health(request: Request):
    return health(request)


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


def _raw_query_param(request: Request | None, name: str) -> str | None:
    """Read a query parameter from the raw query string instead of FastAPI's
    parsed value. FastAPI/Starlette decode query values with parse_qsl
    semantics, which turns a literal "+" into a space. yt-dlp format
    selectors (format_id) can legitimately contain "+" (e.g. "137+bestaudio")
    but never a literal space, so that decoding would silently corrupt them.
    Only %XX sequences are unescaped here, "+" is left untouched.
    """
    if request is None:
        return None
    raw = request.scope.get("query_string", b"").decode("utf-8", "replace")
    for part in raw.split("&"):
        key, _, value = part.partition("=")
        if urllib_unquote(key, errors="replace") == name:
            return urllib_unquote(value, errors="replace")
    return None


def _validate_video_url(url: str) -> str:
    trimmed = (url or "").strip()
    if not trimmed:
        raise HTTPException(status_code=400, detail="Bitte gib einen Video-Link ein.")
    parts = urlsplit(trimmed)
    if parts.scheme not in {"http", "https"} or not parts.netloc:
        raise HTTPException(status_code=400, detail="Bitte gib einen gültigen http- oder https-Link ein.")
    return trimmed


def _invalid_video_url_response(request_id: str | None = None):
    return JSONResponse(
        status_code=400,
        content={
            "error": {
                "code": "INVALID_VIDEO_URL",
                "message": "Bitte gib einen YouTube-Link ins Linkfeld ein. Die Server-Adresse gehört in die Einstellungen.",
                "phase": "validation",
                "request_id": request_id,
            }
        },
    )


def _is_server_api_url(url: str, request: Request | None = None) -> bool:
    parts = urlsplit(url or "")
    path = parts.path.lower()
    if path in {"/health", "/api/health", "/api/info", "/api/download"}:
        return True
    if path.startswith("/api/"):
        return True
    if request is not None and parts.netloc and parts.netloc.lower() == request.url.netloc.lower():
        return True
    return False


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
def api_info(
    url: str,
    request: Request = None,
):
    raw_url = _raw_query_param(request, "url")
    if raw_url is not None:
        url = raw_url
    if _is_server_api_url(url, request):
        logger.warning("VideoLoader /api/info rejected_server_url url=%s", _safe_url(url))
        return _invalid_video_url_response()
    logger.info("VideoLoader /api/info requested url=%s", _safe_url(url))
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
    allowed_heights = {2160, 1440, 1080, 720, 480, 360, 240, 144}
    heights = sorted(
        {
            f["height"]
            for f in formats
            if f.get("height") in allowed_heights
            and f.get("vcodec") not in (None, "none")
        },
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
_TEMP_EXTENSIONS = {".part", ".ytdl", ".tmp", ".temp"}


def _ffmpeg_path() -> str | None:
    return shutil.which("ffmpeg")


def _ffprobe_path() -> str | None:
    return _FFPROBE_PATH or shutil.which("ffprobe")


def _list_tmpdir_files(tmpdir: str) -> list[dict[str, int | str]]:
    result = []
    for root, _, filenames in os.walk(tmpdir):
        for filename in filenames:
            path = os.path.join(root, filename)
            try:
                size = os.path.getsize(path)
            except OSError:
                size = 0
            result.append({"path": path, "size": size})
    return result


def _is_intermediate_file(path: str) -> bool:
    name = os.path.basename(path).lower()
    stem = os.path.splitext(name)[0]
    return (
        any(name.endswith(ext) for ext in _TEMP_EXTENSIONS)
        or re.search(r"\.f\d+$", stem) is not None
    )


def _probe_media(path: str) -> dict:
    ext = os.path.splitext(path)[1].lower()
    size = os.path.getsize(path) if os.path.exists(path) else 0
    probe = {
        "path": path,
        "size": size,
        "ext": ext,
        "duration": 0.0,
        "has_video": False,
        "video_codec": None,
        "pix_fmt": None,
        "audio_codec": None,
        "valid": False,
        "error": None,
    }
    ffprobe = _ffprobe_path()
    if not ffprobe:
        probe["error"] = "ffprobe_not_found"
        return probe
    if size <= 0 or ext in _AUDIO_EXTENSIONS or _is_intermediate_file(path):
        return probe
    try:
        result = subprocess.run(
            [
                ffprobe,
                "-v",
                "error",
                "-show_entries",
                "format=duration:stream=codec_type,codec_name,pix_fmt",
                "-of",
                "json",
                path,
            ],
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
        if result.returncode != 0:
            probe["error"] = (result.stderr or "ffprobe_failed").strip()
            return probe
        data = json.loads(result.stdout or "{}")
        try:
            probe["duration"] = float((data.get("format") or {}).get("duration") or 0)
        except (TypeError, ValueError):
            probe["duration"] = 0.0
        for stream in data.get("streams", []):
            if stream.get("codec_type") == "video" and not probe["has_video"]:
                probe["has_video"] = True
                probe["video_codec"] = stream.get("codec_name")
                probe["pix_fmt"] = stream.get("pix_fmt")
            elif stream.get("codec_type") == "audio" and not probe["audio_codec"]:
                probe["audio_codec"] = stream.get("codec_name")
        probe["valid"] = bool(probe["has_video"] and probe["duration"] > 0 and size > 0)
    except Exception as exc:
        probe["error"] = f"{type(exc).__name__}: {exc}"
        logger.warning(
            "ffprobe_failed path=%s exception_type=%s message=%s",
            path,
            type(exc).__name__,
            exc,
        )
    return probe


def _has_video_track(path: str) -> bool:
    return bool(_probe_media(path).get("valid"))


def _select_downloaded_video_file(tmpdir: str) -> tuple[str | None, dict | None]:
    probes = []
    for item in _list_tmpdir_files(tmpdir):
        path = str(item["path"])
        ext = os.path.splitext(path)[1].lower()
        if _is_intermediate_file(path) or ext in _AUDIO_EXTENSIONS:
            continue
        if ext not in _VIDEO_EXTENSIONS:
            continue
        probe = _probe_media(path)
        probes.append(probe)
    valid = [probe for probe in probes if probe.get("valid")]
    if not valid:
        return None, None
    best = max(valid, key=lambda probe: (probe.get("duration") or 0, probe.get("size") or 0))
    return str(best["path"]), best


def _is_ios_compatible(path: str, probe: dict) -> bool:
    return (
        os.path.splitext(path)[1].lower() == ".mp4"
        and probe.get("valid")
        and probe.get("video_codec") == "h264"
        and probe.get("pix_fmt") == "yuv420p"
        and probe.get("audio_codec") in (None, "aac")
    )


def _normalize_to_ios_mp4(source_path: str, tmpdir: str) -> tuple[str | None, dict | None, str | None]:
    ffmpeg = _ffmpeg_path()
    if not ffmpeg:
        return None, None, "ffmpeg_not_found"
    output_path = os.path.join(tmpdir, "normalized.mp4")
    try:
        result = subprocess.run(
            [
                ffmpeg,
                "-y",
                "-i",
                source_path,
                "-map",
                "0:v:0",
                "-map",
                "0:a?",
                "-c:v",
                "libx264",
                "-preset",
                "veryfast",
                "-pix_fmt",
                "yuv420p",
                "-c:a",
                "aac",
                "-b:a",
                "160k",
                "-movflags",
                "+faststart",
                output_path,
            ],
            capture_output=True,
            text=True,
            timeout=1800,
            check=False,
        )
        if result.returncode != 0:
            return None, None, (result.stderr or result.stdout or "ffmpeg_failed").strip()
        probe = _probe_media(output_path)
        if not _is_ios_compatible(output_path, probe):
            return None, probe, "normalized_file_failed_ios_validation"
        return output_path, probe, None
    except Exception as exc:
        return None, None, f"{type(exc).__name__}: {exc}"


def _finalize_ios_video_file(path: str, probe: dict, tmpdir: str) -> tuple[str | None, dict | None, bool, str | None]:
    if _is_ios_compatible(path, probe):
        return path, probe, False, None
    normalized_path, normalized_probe, error = _normalize_to_ios_mp4(path, tmpdir)
    if error:
        return None, normalized_probe, True, error
    return normalized_path, normalized_probe, True, None


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
    url: str,
    height: int | None = None,
    quality: int | None = None,
    format_id: str | None = None,
    request: Request = None,
):
    request_id = uuid.uuid4().hex[:12]
    raw_url = _raw_query_param(request, "url")
    if raw_url is not None:
        url = raw_url
    raw_format_id = _raw_query_param(request, "format_id")
    if raw_format_id is not None:
        format_id = raw_format_id
    if _is_server_api_url(url, request):
        logger.warning(
            "VideoLoader /api/download rejected_server_url request_id=%s url=%s",
            request_id,
            _safe_url(url),
        )
        return _invalid_video_url_response(request_id)
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
    if not _ffmpeg_path():
        return _missing_prerequisite_response(
            request_id,
            "ffmpeg wurde nicht gefunden. Bitte installiere ffmpeg und starte den Server neu.",
            "Windows: winget install Gyan.FFmpeg oder choco install ffmpeg. macOS: brew install ffmpeg.",
        )
    if not _ffprobe_path():
        return _missing_prerequisite_response(
            request_id,
            "ffprobe wurde nicht gefunden. Bitte installiere ffmpeg vollständig und starte den Server neu.",
            "ffprobe ist Teil von ffmpeg und wird benötigt, um die finale Videodatei zu prüfen.",
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
            "VideoLoader /api/download requested request_id=%s url=%s quality=%s height=%s format_id=%s selector=%s yt_dlp=%s phase=download",
            request_id,
            _safe_url(url),
            quality,
            height,
            format_id,
            format_selector,
            YT_DLP_VERSION,
        )
        logger.info(
            "VideoLoader normalization_target=%s normalization_performed=false",
            _NORMALIZATION_TARGET,
        )
        logger.info(
            "download_start request_id=%s url=%s quality=%s selector=%s final_output_template=%s yt_dlp=%s phase=download",
            request_id,
            _safe_url(url),
            requested_quality,
            format_selector,
            os.path.join(tmpdir, "video.%(ext)s"),
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

    tmpdir_files = _list_tmpdir_files(tmpdir)
    logger.info(
        "download_tmpdir_files request_id=%s files=%s",
        request_id,
        tmpdir_files,
    )
    path, probe = _select_downloaded_video_file(tmpdir)
    logger.info(
        "download_ffprobe_selected request_id=%s probe=%s",
        request_id,
        probe,
    )
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

    final_path, final_probe, normalized, normalize_error = _finalize_ios_video_file(path, probe or {}, tmpdir)
    logger.info(
        "download_normalization request_id=%s normalized=%s error=%s final_probe=%s",
        request_id,
        normalized,
        normalize_error,
        final_probe,
    )
    if not final_path or not final_probe or not final_probe.get("valid"):
        shutil.rmtree(tmpdir, ignore_errors=True)
        logger.error(
            "download_failed request_id=%s url=%s quality=%s selector=%s yt_dlp=%s "
            "extractor=unknown phase=validation exception_type=InvalidFinalVideo "
            "message=%s",
            request_id,
            _safe_url(url),
            requested_quality,
            format_selector,
            YT_DLP_VERSION,
            normalize_error or "final_file_failed_ffprobe_validation",
        )
        return _download_error_response(
            request_id,
            exception_type="InvalidFinalVideo",
            detail="Die erzeugte Datei enthält keinen abspielbaren iOS-kompatiblen Video-Track.",
        )

    title = info.get("title") or "video"
    source_path = Path(final_path)
    output_path = _unique_output_path(title, ".mp4")
    shutil.move(str(source_path), output_path)
    shutil.rmtree(tmpdir, ignore_errors=True)
    safe_title = _safe_filename(title)
    logger.info(
        "download_ready request_id=%s filename=%s size=%s normalized=%s",
        request_id,
        output_path.name,
        output_path.stat().st_size,
        normalized,
    )

    return FileResponse(
        output_path,
        media_type="video/mp4",
        filename=f"{safe_title}.mp4",
    )
