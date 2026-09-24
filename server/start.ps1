[CmdletBinding()]
param([switch]$CheckOnly, [switch]$UpdateDownloader)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Set-Location -LiteralPath $PSScriptRoot

function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Fehlgeschlagen: $Executable (Exit-Code $LASTEXITCODE). Bitte die Ausgabe oben pruefen." }
}

$port = 9876
if ($env:PORT) {
    if (-not [int]::TryParse($env:PORT, [ref]$port) -or $port -lt 1 -or $port -gt 65535) {
        throw 'PORT muss eine Zahl zwischen 1 und 65535 sein.'
    }
}
$python = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    $launcher = Get-Command py -ErrorAction SilentlyContinue
    $prefix = @('-3')
    if (-not $launcher) {
        $launcher = Get-Command python -ErrorAction SilentlyContinue
        $prefix = @()
    }
    if (-not $launcher) { throw 'Python fehlt. Installieren: winget install Python.Python.3.12' }
    Invoke-Checked $launcher.Source ($prefix + @('-c', 'import sys; assert sys.version_info >= (3, 10), "Python 3.10 oder neuer erforderlich"'))
    if ($CheckOnly) { throw 'Virtuelle Umgebung fehlt. Zum Einrichten start.ps1 ohne -CheckOnly starten.' }
    Invoke-Checked $launcher.Source ($prefix + @('-m', 'venv', '.venv'))
}
Invoke-Checked $python @('-c', 'import sys; assert sys.version_info >= (3, 10)')

$reqStamp = '.venv\.requirements.sha256'
$currentHash = (Get-FileHash -Algorithm SHA256 -LiteralPath 'requirements.txt').Hash
$installedHash = if (Test-Path -LiteralPath $reqStamp) { (Get-Content -LiteralPath $reqStamp -Raw).Trim() } else { '' }
if (-not $CheckOnly -and $currentHash -ne $installedHash) {
    Invoke-Checked $python @('-m', 'pip', 'install', '-r', 'requirements.txt')
    Set-Content -LiteralPath $reqStamp -Value $currentHash
}
if ($UpdateDownloader -and -not $CheckOnly) {
    Invoke-Checked $python @('-m', 'pip', 'install', '--upgrade', 'yt-dlp[default]')
}
Invoke-Checked $python @('-c', 'import fastapi, uvicorn, yt_dlp, yt_dlp_ejs')
foreach ($tool in @('ffmpeg', 'ffprobe')) {
    $command = Get-Command $tool -ErrorAction SilentlyContinue
    if (-not $command) { throw "$tool fehlt. Installieren: winget install Gyan.FFmpeg; danach PowerShell neu oeffnen." }
    Invoke-Checked $command.Source @('-version')
}
Invoke-Checked $python @('-c', 'from main import _javascript_runtime; r = _javascript_runtime(); print(r); assert r["available"], "Deno >= 2.3 fehlt: winget install DenoLand.Deno"')
if ($CheckOnly) { Write-Host "Voraussetzungen erfuellt. Port: $port"; exit 0 }

$addresses = @(Get-NetIPConfiguration | Where-Object { $_.NetAdapter.Status -eq 'Up' -and $_.IPv4DefaultGateway } | ForEach-Object { $_.IPv4Address.IPAddress })
Write-Host "`nDiese Adresse in VideoLoader eintragen (iPhone und PC im selben WLAN):"
foreach ($address in $addresses) { Write-Host "  http://$($address):$port" }
if ($addresses.Count -eq 0) { Write-Host "  Keine aktive WLAN/LAN-Adresse gefunden. Mit ipconfig pruefen." }
Write-Host 'Windows-Firewall: Python nur im privaten Netzwerk zulassen. Terminal offen lassen.'
Invoke-Checked $python @('-m', 'uvicorn', 'main:app', '--host', '0.0.0.0', '--port', "$port")
