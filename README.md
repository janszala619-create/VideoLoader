# VideoLoader – private Video-Download-App fürs iPhone

Die App besteht aus zwei Teilen:

| Teil | Ordner | Aufgabe |
|---|---|---|
| Server | `server/` | Läuft auf deinem Mac. Holt die Videos mit yt-dlp von YouTube & über 1.000 anderen Plattformen. |
| iPhone-App | `ios/` | Link einfügen → Vorschau ansehen → Qualität wählen → Download → Video landet im Tab „Meine Videos“ und kann von dort angesehen, geteilt oder in die Fotos-Galerie gesichert werden. |

### Zwei Server – oben in der App umschaltbar

Die App kann zwei verschiedene Server ansprechen; oben wählst du per Schalter aus:

- **Cloud-Server** (Standard, Adresse `http://158.101.168.11:8765`): überall erreichbar, du brauchst keinen Mac laufen zu lassen. **Aber:** YouTube, Vimeo und viele große Seiten blockieren diesen Server, weil er in einem Rechenzentrum steht (getestet am 04.07.2026). Gut geeignet für Seiten, die Cloud-Server durchlassen.
- **Mac-Server** (der Server in `server/`): läuft bei dir zu Hause und wird von YouTube **nicht** blockiert – die zuverlässige Wahl, besonders für YouTube. Dafür muss der Mac an und im selben WLAN sein.

> **Wichtig:** Nur für den privaten Gebrauch. Lade nur Videos herunter, zu deren Download du berechtigt bist. Solche Apps sind im App Store nicht erlaubt – die Installation erfolgt direkt über Xcode auf dein eigenes iPhone.

---

## Schritt 1: Projekt auf den Mac übertragen

Kopiere den kompletten Ordner `VideoLoader` auf deinen Mac (z. B. per USB-Stick, iCloud, oder als ZIP per E-Mail an dich selbst).

## Schritt 2: Server auf dem Mac starten

1. **ffmpeg installieren** (einmalig, wird zum Zusammenfügen von Bild und Ton gebraucht).
   Öffne die **Terminal**-App und tippe:
   ```bash
   brew install ffmpeg
   ```
   Falls `brew` nicht gefunden wird, installiere zuerst Homebrew von https://brew.sh.

2. **Server starten.** Im Terminal:
   ```bash
   cd /Pfad/zum/VideoLoader/server
   chmod +x start.sh
   ./start.sh
   ```
   Beim ersten Start richtet das Skript alles automatisch ein. Danach zeigt es dir die Adresse an, z. B.:
   ```
   Server startet. Diese Adresse in der App eintragen:
     http://192.168.1.23:8000
   ```
   **Diese Adresse brauchst du gleich in der App.** Lass das Terminal-Fenster offen, solange du die App benutzt.

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

1. Beim ersten Start öffnen sich die **Einstellungen**: Trage dort die Server-Adresse aus Schritt 2 ein (z. B. `http://192.168.1.23:8000`). iPhone und Mac müssen im **selben WLAN** sein.
2. Video-Link kopieren (z. B. über „Teilen → Kopieren“ in der YouTube-App), in der App einfügen und **„Video prüfen“** tippen.
3. Vorschau ansehen (▶ auf dem Vorschaubild), **Qualität wählen** und **„Herunterladen“** tippen.
4. Das Video erscheint im Tab **„Meine Videos“**: Antippen zum Abspielen, Teilen-Symbol zum Weitergeben, Foto-Symbol zum Sichern in die **Fotos-Galerie** (beim ersten Mal fragt iOS nach Erlaubnis – erlauben). Wischen nach links löscht ein Video.

---

## Häufige Probleme

- **„Server nicht erreichbar“** – Läuft `start.sh` noch auf dem Mac? Sind iPhone und Mac im selben WLAN? Stimmt die Adresse (inkl. `:8000`)?
- **YouTube-Video schlägt fehl** – yt-dlp muss aktuell sein. Einfach den Server neu starten (`./start.sh` aktualisiert yt-dlp automatisch).
- **Unterwegs nutzen (nicht im Heim-WLAN)** – Installiere [Tailscale](https://tailscale.com) (kostenlos) auf Mac und iPhone; trage dann in der App die Tailscale-Adresse des Macs ein (z. B. `http://100.x.y.z:8000`).
- **Server in der Cloud statt auf dem Mac?** – Möglich (der `server/`-Ordner läuft überall, wo Python + ffmpeg vorhanden sind), aber Achtung: YouTube blockiert Rechenzentrums-IP-Adressen häufig. Der Server zu Hause auf dem Mac ist am zuverlässigsten.
