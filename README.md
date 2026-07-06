# VideoLoader – private Video-Download-App fürs iPhone

Die App besteht aus zwei Teilen:

| Teil | Ordner | Aufgabe |
|---|---|---|
| Server | `server/` | Läuft auf deinem Mac. Holt die Videos mit yt-dlp von YouTube & über 1.000 anderen Plattformen. |
| iPhone-App | `ios/` | Link einfügen → Vorschau ansehen → Qualität wählen → Download → Video landet im Tab „Meine Videos“ und kann von dort angesehen, geteilt oder in die Fotos-Galerie gesichert werden. |

### Zwei Server – oben in der App umschaltbar

Die App kann zwei verschiedene Server ansprechen; oben wählst du per Schalter aus:

- **Lokaler Server** (Standard, z. B. `http://100.80.105.62:9876`): läuft bei dir zu Hause und wird von YouTube **nicht** blockiert – die zuverlässige Wahl, besonders für YouTube.
- **Cloud-Server / VidSave** (Legacy, Adresse `http://158.101.168.11:8765`): überall erreichbar, aber YouTube, Vimeo und viele große Seiten blockieren diesen Server häufig.

> **Wichtig:** Nur für den privaten Gebrauch. Lade nur Videos herunter, zu deren Download du berechtigt bist. Solche Apps sind im App Store nicht erlaubt – die Installation erfolgt direkt über Xcode auf dein eigenes iPhone.

---

## Schritt 1: Projekt auf den Mac übertragen

Kopiere den kompletten Ordner `VideoLoader` auf deinen Mac (z. B. per USB-Stick, iCloud, oder als ZIP per E-Mail an dich selbst).

## Schritt 2: Server lokal starten

1. **ffmpeg installieren** (einmalig, wird zum Zusammenfügen von Bild und Ton gebraucht).
   Auf macOS in der **Terminal**-App:
   ```bash
   brew install ffmpeg
   ```
   Falls `brew` nicht gefunden wird, installiere zuerst Homebrew von https://brew.sh.

   Auf Windows in **PowerShell**:
   ```powershell
   winget install Gyan.FFmpeg
   ```
   Öffne danach PowerShell neu, damit `ffmpeg` im PATH gefunden wird.

2. **Server starten.**

   macOS/Linux:
   ```bash
   cd /Pfad/zum/VideoLoader/server
   VIDEOLOADER_LOG_LEVEL=DEBUG python -m uvicorn main:app --host 0.0.0.0 --port 9876 --log-level debug
   ```

   Windows PowerShell:
   ```powershell
   cd C:\Pfad\zum\VideoLoader\server
   $env:VIDEOLOADER_LOG_LEVEL="DEBUG"
   python -m uvicorn main:app --host 0.0.0.0 --port 9876 --log-level debug
   ```

   Beim ersten Start richtet das Skript alles automatisch ein. Danach zeigt es dir die Adresse an, z. B.:
   ```
   Server startet. Diese Adresse in der App eintragen:
     http://100.80.105.62:9876
   ```
   **Diese Adresse brauchst du gleich in der App.** Lass das Terminal-Fenster offen, solange du die App benutzt.

3. **Server prüfen.** Öffne im Browser:
   ```text
   http://100.80.105.62:9876/api/health
   ```
   Für eine ausführlichere Diagnose:
   ```text
   http://100.80.105.62:9876/api/diagnostics
   ```
   Dort siehst du, ob der Download-Ordner beschreibbar ist und ob `ffmpeg`, `ffprobe` und `yt-dlp` gefunden werden.

## Schritt 3: App auf das iPhone installieren

1. Öffne `ios/VideoLoader.xcodeproj` mit **Xcode** (Version 16 oder neuer, kostenlos im Mac App Store).
2. Klicke links oben im Dateibaum auf **VideoLoader** (das Projekt) → Tab **Signing & Capabilities**:
   - Setze bei **Team** deine Apple-ID (über „Add an Account…“ hinzufügen – ein normaler, kostenloser Apple-Account reicht).
   - Ändere die **Bundle Identifier** in etwas Eigenes, z. B. `de.deinname.VideoLoader`.
3. Schließe dein iPhone per Kabel an und wähle es oben in der Geräteliste aus.
4. Drücke **▶ (Run)**. Beim ersten Mal:
   - Am iPhone unter **Einstellungen → Allgemein → VPN & Geräteverwaltung** deinem Entwicklerprofil vertrauen.
   - Ggf. den **Entwicklermodus** aktivieren (Einstellungen → Datenschutz & Sicherheit → Entwicklermodus).

> Mit einem kostenlosen Apple-Account läuft die App 7 Tage, dann einfach erneut über Xcode installieren (▶ drücken genügt). Mit einem bezahlten Entwickler-Account (99 €/Jahr) hält die Installation 1 Jahr.

## Schritt 4: App benutzen

1. Beim ersten Start öffnen sich die **Einstellungen**: Trage dort die Server-Adresse aus Schritt 2 ein (z. B. `http://100.80.105.62:9876`). iPhone und Computer müssen im selben WLAN oder Tailscale-Netz sein.
2. Video-Link kopieren (z. B. über „Teilen → Kopieren“ in der YouTube-App), in der App einfügen und **„Video prüfen“** tippen.
3. Vorschau ansehen (▶ auf dem Vorschaubild), **Qualität wählen** und **„Herunterladen“** tippen.
4. Das Video erscheint im Tab **„Meine Videos“**: Antippen zum Abspielen, Teilen-Symbol zum Weitergeben, Foto-Symbol zum Sichern in die **Fotos-Galerie** (beim ersten Mal fragt iOS nach Erlaubnis – erlauben). Wischen nach links löscht ein Video.

---

## Häufige Probleme

- **„Server nicht erreichbar“** – Läuft der lokale Server noch? Sind iPhone und Computer im selben WLAN oder Tailscale-Netz? Stimmt die Adresse (inkl. `:9876`)?
- **„ffmpeg wurde nicht gefunden“** – Installiere `ffmpeg` wie oben beschrieben und starte danach Terminal/PowerShell und den Server neu.
- **YouTube-Video schlägt fehl** – yt-dlp muss aktuell sein. Einfach den Server neu starten (`./start.sh` aktualisiert yt-dlp automatisch).
- **Unterwegs nutzen (nicht im Heim-WLAN)** – Installiere [Tailscale](https://tailscale.com) (kostenlos) auf Computer und iPhone; trage dann in der App die Tailscale-Adresse des Computers ein (z. B. `http://100.x.y.z:9876`).
- **Server in der Cloud statt auf dem Mac?** – Möglich (der `server/`-Ordner läuft überall, wo Python + ffmpeg vorhanden sind), aber Achtung: YouTube blockiert Rechenzentrums-IP-Adressen häufig. Der Server zu Hause auf dem Mac ist am zuverlässigsten.

### Diagnose: richtiger Server und Ports

Der lokale VideoLoader-Server meldet sich unter:

```text
http://TAILSCALE_IP:9876/api/health
```

Die Antwort muss `server_name: "VideoLoader local server"` enthalten. Verwende in der App nur die Basisadresse `http://TAILSCALE_IP:9876`, nicht `/api/health`, nicht `localhost`, nicht `127.0.0.1` und keinen YouTube-Link.

Falls noch ein alter VidSave-Prozess auf Port 8765 läuft:

```powershell
netstat -ano | findstr :8765
netstat -ano | findstr :9876
Get-Process -Id <PID>
Stop-Process -Id <PID> -Force
```

Korrekte Server-Logs enthalten `VideoLoader /api/info`, `VideoLoader /api/download`, `quality=` und `ffprobe`. Wenn Logs `vidsave.server`, `info_requested` oder `download_requested` zeigen, trifft die App noch den alten VidSave-Server oder den falschen Port.
