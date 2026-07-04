"""VideoLoader-Server: liefert Videoinfos und Downloads über yt-dlp."""

import os
import shutil
import tempfile

import yt_dlp
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import FileResponse
from starlette.background import BackgroundTask

app = FastAPI(title="VideoLoader Server")


@app.get("/")
def root():
    return {"status": "ok", "hinweis": "VideoLoader-Server läuft. Diese Adresse in der App eintragen."}


def _extract_info(url: str) -> dict:
    opts = {"quiet": True, "no_warnings": True, "noplaylist": True}
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


def _build_format(height: int | None) -> str:
    h = f"[height<={height}]" if height else ""
    # Bevorzugt H.264 + AAC, damit das Video sicher in der iPhone-Galerie abspielbar ist
    return (
        f"bestvideo{h}[vcodec^=avc1]+bestaudio[acodec^=mp4a]/"
        f"bestvideo{h}+bestaudio/"
        f"best{h}/best"
    )


@app.get("/api/download")
def api_download(
    url: str = Query(..., description="Link zum Video"),
    height: int | None = Query(None, description="Maximale Auflösung, z. B. 1080"),
):
    tmpdir = tempfile.mkdtemp(prefix="videoloader_")
    opts = {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "format": _build_format(height),
        "outtmpl": os.path.join(tmpdir, "video.%(ext)s"),
        "merge_output_format": "mp4",
        "postprocessors": [{"key": "FFmpegVideoRemuxer", "preferedformat": "mp4"}],
    }
    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(url, download=True)
    except Exception as exc:
        shutil.rmtree(tmpdir, ignore_errors=True)
        raise HTTPException(status_code=422, detail=f"Download fehlgeschlagen: {exc}")

    files = [os.path.join(tmpdir, f) for f in os.listdir(tmpdir)]
    files = [f for f in files if os.path.isfile(f)]
    if not files:
        shutil.rmtree(tmpdir, ignore_errors=True)
        raise HTTPException(status_code=500, detail="Der Server konnte keine Videodatei erzeugen.")
    path = max(files, key=os.path.getsize)

    title = (info.get("title") or "video")[:80]
    safe_title = "".join(c for c in title if c.isalnum() or c in " -_").strip() or "video"

    return FileResponse(
        path,
        media_type="video/mp4",
        filename=f"{safe_title}.mp4",
        background=BackgroundTask(shutil.rmtree, tmpdir, ignore_errors=True),
    )
