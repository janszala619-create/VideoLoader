#!/bin/bash
# VideoLoader-Server starten (auf dem Mac ausführen)
cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
  echo "Richte Python-Umgebung ein (nur beim ersten Mal) ..."
  python3 -m venv .venv
  ./.venv/bin/pip install --upgrade pip
  ./.venv/bin/pip install -r requirements.txt
fi

# yt-dlp aktuell halten – wichtig, damit YouTube & Co. funktionieren
./.venv/bin/pip install --upgrade --quiet yt-dlp

echo ""
echo "Server startet. Diese Adresse in der App eintragen:"
IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
echo "  http://${IP:-<Mac-IP-Adresse>}:8000"
echo ""
./.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
