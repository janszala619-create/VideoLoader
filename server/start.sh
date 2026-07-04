#!/bin/bash
# VideoLoader-Server starten (auf dem Mac ausführen)
cd "$(dirname "$0")"

REQ_STAMP=".venv/.requirements.sha256"
YTDLP_STAMP=".venv/.yt-dlp-updated"

requirements_hash() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 requirements.txt | awk '{print $1}'
  else
    python3 - <<'PY'
import hashlib
print(hashlib.sha256(open("requirements.txt", "rb").read()).hexdigest())
PY
  fi
}

if [ ! -d ".venv" ]; then
  echo "Richte Python-Umgebung ein (nur beim ersten Mal) ..."
  python3 -m venv .venv
  ./.venv/bin/pip install --upgrade pip
fi

CURRENT_REQ_HASH="$(requirements_hash)"
INSTALLED_REQ_HASH="$(cat "$REQ_STAMP" 2>/dev/null || true)"
if [ "$CURRENT_REQ_HASH" != "$INSTALLED_REQ_HASH" ]; then
  echo "Aktualisiere Server-Abhängigkeiten ..."
  ./.venv/bin/pip install --upgrade --quiet -r requirements.txt
  echo "$CURRENT_REQ_HASH" > "$REQ_STAMP"
fi

# yt-dlp regelmäßig aktuell halten – wichtig, damit YouTube & Co. funktionieren
TODAY="$(date +%Y-%m-%d)"
LAST_YTDLP_UPDATE="$(cat "$YTDLP_STAMP" 2>/dev/null || true)"
if [ "$TODAY" != "$LAST_YTDLP_UPDATE" ]; then
  echo "Prüfe yt-dlp-Update ..."
  ./.venv/bin/pip install --upgrade --quiet yt-dlp
  echo "$TODAY" > "$YTDLP_STAMP"
fi

echo ""
echo "Server startet. Diese Adresse in der App eintragen:"
IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
echo "  http://${IP:-<Mac-IP-Adresse>}:8000"
echo ""
./.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
