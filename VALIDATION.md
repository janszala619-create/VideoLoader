# Prüfprotokoll

Stand: 23. September 2026. Lokale Prüfung unter Windows; keine allgemeine Plattformgarantie.

## Automatisiert

- Servertests: bestehende Download-/Konvertierungstests plus API-Vertrag, Deno-Versionserkennung, fehlende Voraussetzungen, Login-/DRM-/Seitenfehler, Playlist-/Live-Ablehnung und Windows-Portvalidierung.
- Qualitätsauswahl zusätzlich mit dem echten yt-dlp-Formatselektor geprüft: fehlende Auflösungsmetadaten bleiben erlaubt, bekannte höhere Auflösungen werden ausgeschlossen.
- Windows-Start mit tatsächlicher Installation einer neuen virtuellen Umgebung, ffmpeg/ffprobe 9.0.2, Deno 2.9.7 und yt-dlp 2026.8.19 erfolgreich auf Port 9876 ausgeführt.
- Fehlender Python-Interpreter (Windows-Store-Platzhalter, Exit 9009) stoppt das Skript, statt eine erfolgreiche Installation vorzutäuschen.

## Echte HTTP-Downloads

Der Server wurde über seine HTTP-Endpunkte angesprochen; Ausgabedateien anschließend mit ffprobe geprüft.

| Quelle / Testvideo | Ergebnis |
| --- | --- |
| YouTube `jNQXAC9IVRw` | HTTP 200, 744.412 Bytes, ca. 19 s; H.264/yuv420p und AAC |
| Instagram Reel `Chunk8-jurw` | HTTP 200, 918.120 Bytes, ca. 5 s; H.264/yuv420p, Datei enthält keine Audiospur |
| W3Schools `https://www.w3schools.com/html/mov_bbb.mp4` | HTTP 200, 788.493 Bytes, ca. 10 s; H.264/yuv420p und AAC |
| Mux `https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8` | HTTP 200, 66.978.180 Bytes, ca. 635 s; H.264/yuv420p und AAC |
| TikTok `6742501081818877190`, `6748451240264420610` | Quelle antwortet „Video not available, status code 0“; kein erfolgreicher Download nachweisbar |
| Altes YouTube-Testvideo `BaW_jenozKc` | Quelle meldet „This video is unavailable“; deshalb zweites öffentliches Video geprüft |

Instagram und direkte MP4 hatten zunächst fehlende Auflösungsmetadaten. Der dabei gefundene Filterfehler wurde behoben; beide Downloads anschließend erfolgreich wiederholt. Die Testmedien liegen nur im lokalen Arbeitsbereich, nicht im Git-Repository.

## Noch am echten iPhone prüfen

- AltStore-Installation und Signierung mit eigener Apple-ID; Erneuerung nach sieben Tagen.
- Ersteinrichtung mit WLAN-Adresse; bestehende individuelle Adressen und Bibliothek nach Update erhalten.
- Lokale Netzwerkberechtigung, abgeschalteter PC und WLAN-Abbruch.
- Download bei gesperrtem Bildschirm sowie Wiederöffnung nach erzwungenem Beenden.
- Offline-Wiedergabe, Export in Dateien und Fotos, verweigerte Foto-Berechtigung, voller iPhone-Speicher.

Diese Gerätetests wurden hier nicht durchgeführt. Der lokale Windows-Rechner enthält kein Xcode; der iOS-Build muss über den GitHub-Workflow geprüft werden. TikTok ist als nicht erfolgreich verifiziert dokumentiert und bleibt abhängig von erreichbaren öffentlichen Quellen.
