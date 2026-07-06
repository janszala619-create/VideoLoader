$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

$reqStamp = ".venv\.requirements.sha256"
$ytDlpStamp = ".venv\.yt-dlp-updated"

function Get-RequirementsHash {
    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath "requirements.txt"
    return $hash.Hash.ToLowerInvariant()
}

if (-not (Test-Path -LiteralPath ".venv")) {
    Write-Host "Richte Python-Umgebung ein (nur beim ersten Mal) ..."
    py -3 -m venv .venv
    .\.venv\Scripts\python.exe -m pip install --upgrade pip
}

$currentReqHash = Get-RequirementsHash
$installedReqHash = if (Test-Path -LiteralPath $reqStamp) { Get-Content -LiteralPath $reqStamp -Raw } else { "" }
if ($currentReqHash -ne $installedReqHash.Trim()) {
    Write-Host "Aktualisiere Server-Abhaengigkeiten ..."
    .\.venv\Scripts\python.exe -m pip install --upgrade --quiet -r requirements.txt
    New-Item -ItemType Directory -Force -Path ".venv" | Out-Null
    Set-Content -LiteralPath $reqStamp -Value $currentReqHash
}

$today = Get-Date -Format "yyyy-MM-dd"
$lastYtDlpUpdate = if (Test-Path -LiteralPath $ytDlpStamp) { Get-Content -LiteralPath $ytDlpStamp -Raw } else { "" }
if ($today -ne $lastYtDlpUpdate.Trim()) {
    Write-Host "Pruefe yt-dlp-Update ..."
    .\.venv\Scripts\python.exe -m pip install --upgrade --quiet yt-dlp
    Set-Content -LiteralPath $ytDlpStamp -Value $today
}

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "Hinweis: ffmpeg wurde nicht gefunden. Installiere es z. B. mit:"
    Write-Host "  winget install Gyan.FFmpeg"
    Write-Host "Danach PowerShell neu oeffnen und den Server erneut starten."
    Write-Host ""
}

$port = if ($env:PORT) { $env:PORT } else { "8765" }
$ip = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254.*" -and
        $_.PrefixOrigin -ne "WellKnown"
    } |
    Select-Object -First 1 -ExpandProperty IPAddress)

Write-Host ""
Write-Host "Server startet. Diese Adresse in der App eintragen:"
Write-Host "  http://$($ip):$port"
Write-Host ""
.\.venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port $port
