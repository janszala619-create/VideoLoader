# VideoLoader – iPhone-App mit Windows-Server

Link einfügen → Video prüfen → Qualität wählen → herunterladen → offline ansehen.
Die SwiftUI-App benötigt iOS 17 oder neuer. Der private Hilfsdienst läuft auf deinem Windows-PC im selben WLAN. GitHub Actions baut die IPA auf macOS; ein eigener Mac ist dafür nicht erforderlich.

## 1. Windows einmalig vorbereiten

In PowerShell installieren:

```powershell
winget install Python.Python.3.12
winget install Gyan.FFmpeg
winget install DenoLand.Deno
```

Danach PowerShell neu öffnen. Python 3.10 oder neuer, ffmpeg samt ffprobe und Deno ab 2.3 werden benötigt. Die Python-Abhängigkeit `yt-dlp[default]` enthält die passenden YouTube-Challenge-Skripte; das Startskript installiert sie in einer eigenen Umgebung.

## 2. Server starten

Repository herunterladen oder klonen. Im Projektordner:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\server\start.ps1
```

Die Ausführungsrichtlinie gilt nur für diesen Prozess. Das Skript stoppt bei fehlgeschlagenen Installationen, prüft die Werkzeuge und zeigt die aktiven Netzwerkadressen an. Wähle die WLAN/LAN-Adresse deines PCs, beispielsweise `http://192.168.1.10:9876`. Dies ist nur ein Beispiel, keine voreingestellte Adresse.

Python in der Windows-Firewall ausschließlich für das private Netzwerk zulassen. Kein Port-Forwarding einrichten: Der Dienst ist für dein privates WLAN bestimmt und hat keine Benutzeranmeldung. PC und Terminal müssen während der Downloads eingeschaltet bleiben; Energiesparmodus unterbricht die Verbindung.

Prüfung ohne Installation oder Serverstart:

```powershell
.\server\start.ps1 -CheckOnly
```

Downloader bei Plattformänderungen aktualisieren:

```powershell
.\server\start.ps1 -UpdateDownloader
```

Standard-Port ist **9876**, optional mit der Umgebungsvariable `PORT` überschreibbar. Bei mehreren angezeigten Adressen diejenige des gemeinsamen iPhone-WLANs verwenden. Im iPhone-Browser `http://DEINE-PC-IP:9876/api/health` testen. `/api/diagnostics` zeigt fehlende Werkzeuge und den beschreibbaren Ausgabeordner an. Nach Installation neuer Werkzeuge den Server neu starten.

## 3. IPA mit GitHub bauen

Änderungen in dein Repository übertragen. Unter **Actions → Build → Run workflow** starten. Derselbe Workflow läuft auch bei Push und Pull Requests.

- Servertests laufen unter Windows und Linux.
- Ein macOS-Runner prüft den Simulator-Build und baut anschließend die iPhone-App in Release-Konfiguration.
- Im erfolgreichen Lauf unter **Artifacts → VideoLoader-unsigned-ipa** die ZIP herunterladen und entpacken.
- Das Ergebnis heißt `VideoLoader-unsigned.ipa`. Es ist noch nicht signiert und lässt sich nicht durch bloßes Antippen installieren.
- Build-Protokolle stehen auch nach fehlgeschlagenen Builds als Artefakt bereit.

## 4. Auf dem iPhone installieren

[AltStore Classic für Windows installieren](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows). Dabei die dort genannten Apple-Komponenten installieren, das iPhone mit dem PC verbinden und AltServer mit deiner Apple-ID einrichten. Apple-Zugangsdaten gehören weder in das Repository noch in GitHub Secrets.

Die heruntergeladene IPA auf dem iPhone in Dateien bereitstellen und in AltStore Classic unter **My Apps → +** auswählen. AltStore signiert die App. Falls iOS es verlangt, dem Entwicklerprofil vertrauen und den Entwicklermodus aktivieren.

Mit kostenloser Apple-ID laufen Apps gewöhnlich nach **sieben Tagen** ab; regelmäßig mit erreichbarem AltServer erneuern. Kostenloses Sideloading begrenzt außerdem aktive Apps und App-IDs. VideoLoader enthält eine Share Extension, die eine weitere App-ID beanspruchen kann. Bei Updates dieselbe Apple-ID und App-Identität verwenden und die App nicht deinstallieren, damit lokale Videos erhalten bleiben.

## 5. Benutzen

1. VideoLoader öffnen, unter Einstellungen die vom PC angezeigte Adresse eingeben und **Verbindung testen** wählen. Den Zugriff auf das lokale Netzwerk erlauben.
2. Öffentlichen Einzelvideo-Link einfügen und prüfen.
3. Standard ist **Automatisch**; andere angebotene Auflösungen lassen sich auswählen.
4. Herunterladen: Zunächst bereitet der PC die Datei vor, anschließend zeigt die App den Übertragungsfortschritt, sofern die Größe bekannt ist.
5. In der Bibliothek offline abspielen, nach Dateien teilen oder in Fotos sichern. Fotozugriff wird erst beim Export angefragt.

Öffentliche YouTube-, Instagram- und TikTok-Videos sowie viele eingebettete Player, direkte Videodateien und ungeschützte HLS-Streams werden über yt-dlp verarbeitet. Unterstützung hängt von Quelle und Plattform ab; Login-, Regions- und Bot-Sperren können Downloads verhindern. Keine Website-Anmeldung, Playlist-Verarbeitung, Livestream-Aufzeichnung oder DRM-Entschlüsselung vorgesehen. Nur Videos laden, zu deren Download du berechtigt bist.

Vorhandene eigene Server-Adressen, Qualitätspräferenzen und Videos bleiben erhalten. Alte mitgelieferte Beispieladressen werden einmalig entfernt. Der optionale Legacy-VidSave-Modus bleibt für bestehende eigene Einstellungen verfügbar; es gibt keinen voreingestellten Cloud-Server und keinen automatischen Wechsel dorthin.

## Fehler beheben

- **Server nicht erreichbar:** PC eingeschaltet, richtiger Port, gleiche WLAN-Verbindung, privates Firewall-Profil und iOS-Lokalnetzfreigabe prüfen. Gastnetze können Geräte voneinander isolieren.
- **Server nicht bereit:** `start.ps1 -CheckOnly` ausführen; ffmpeg/ffprobe und PC-Speicher prüfen.
- **YouTube funktioniert nicht:** Deno prüfen, Downloader aktualisieren. Manche Videos benötigen eine Anmeldung oder werden von der Plattform blockiert.
- **Abbruch bei gesperrtem Bildschirm:** Die App verwendet iOS-Hintergrunddownloads. iOS entscheidet über deren Ausführung; erzwungenes Beenden stoppt sie. App erneut öffnen und gegebenenfalls wiederholen.
- **Speicher voll:** Auf PC oder iPhone Platz schaffen. Fertige Server-Dateien liegen unter `server/downloads` und können nach Abschluss des Transfers manuell gelöscht werden.
- **Fotos verweigert:** In den iOS-Einstellungen den Fotozugriff erlauben oder stattdessen nach Dateien exportieren.

## Entwicklung und Tests

```powershell
.\server\.venv\Scripts\python.exe -m pip install httpx
.\server\.venv\Scripts\python.exe -m unittest discover -s tests
```

Die bestehenden GET-Endpunkte bleiben erhalten: `/api/info?url=…`, `/api/download?url=…&quality=720`, `/api/health`, `/api/diagnostics`. Fehler liefern `error.code` und `error.message`; Gesundheitsantworten enthalten zusätzlich `javascript_runtime`. Fehlendes Deno wird separat gemeldet und blockiert andere Quellen nicht, wenn der Dienst direkt gestartet wird.

Prüfergebnisse und noch ausstehende Gerätetests: [VALIDATION.md](VALIDATION.md).
