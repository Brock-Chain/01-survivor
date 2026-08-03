# BESTAGON - gather everything worth sending after a crash or a freeze.
#
# ASCII ONLY, same reason as package.ps1: Windows PowerShell 5.1 reads a .ps1 as
# ANSI unless it has a BOM, so one em-dash in a comment is a parser error.
#
# Run it via COLLECT-LOGS.bat. Writes one zip to the Desktop and nothing else;
# it never touches the game's files and never deletes a log.
#
# Exists because a remote "it froze" report is unactionable on its own. The game
# writes a log to a folder nobody can be expected to find, and the half that a
# report never includes -- which GPU, which driver -- is the half that decides
# most graphics questions. One double-click, one file to send back.

$ErrorActionPreference = "Stop"

$logs  = Join-Path $env:APPDATA "Godot\app_userdata\BESTAGON\logs"
$stamp = Get-Date -Format "yyyy-MM-ddTHH.mm.ss"
$stage = Join-Path $env:TEMP "BESTAGON-logs-$stamp"
New-Item -ItemType Directory -Path $stage -Force | Out-Null

$count = 0
if (Test-Path $logs) {
    Copy-Item (Join-Path $logs "*") $stage -Force -ErrorAction SilentlyContinue
    $count = @(Get-ChildItem $stage -File -ErrorAction SilentlyContinue).Count
}

# Collected even when there are NO logs. "No log exists" is itself a finding --
# it means the game never started, or never got far enough to write one.
$info = @()
$info += "collected  : $stamp"
$info += "log_files  : $count"
$info += "log_dir    : $logs"
$info += "log_dir_ok : $(Test-Path $logs)"
try {
    $os = Get-CimInstance Win32_OperatingSystem
    $info += "os         : $($os.Caption) $($os.Version)"
    $cpu = @(Get-CimInstance Win32_Processor)[0]
    $info += "cpu        : $($cpu.Name)"
    $info += "cores      : $env:NUMBER_OF_PROCESSORS"
    $cs = Get-CimInstance Win32_ComputerSystem
    $info += "ram_gb     : $([math]::Round($cs.TotalPhysicalMemory / 1GB, 1))"
    foreach ($gpu in @(Get-CimInstance Win32_VideoController)) {
        $info += "gpu        : $($gpu.Name) | driver $($gpu.DriverVersion) | $($gpu.DriverDate)"
    }
} catch {
    # Never let a WMI hiccup cost us the logs, which are the point.
    $info += "sysinfo    : FAILED - $($_.Exception.Message)"
}

# Overlay and capture software. The one hang dump we have (2026-08-03) had
# NVIDIA's ShadowPlay capture hook (nvspcap64.dll) injected into the game, and
# this whole class of tool hooks the GL/present path where that hang lived.
# Whether the SAME overlays are running on every machine that freezes is the
# first cross-machine question, and no reporter volunteers it because none of
# this feels like "software you are running".
try {
    $overlayPattern = '^(nvcontainer|nvsphelper|NVDisplay|NVIDIA|RTSS|MSIAfterburner|obs|Discord|Overwolf|Medal|GameBar|XboxGameBar|steamwebhelper)'
    $found = @(Get-Process | Where-Object { $_.ProcessName -match $overlayPattern } |
        Select-Object -ExpandProperty ProcessName -Unique | Sort-Object)
    if ($found.Count -eq 0) {
        $info += "overlays   : none of the known ones running"
    } else {
        foreach ($p in $found) { $info += "overlay    : $p" }
    }
} catch {
    $info += "overlays   : FAILED - $($_.Exception.Message)"
}
$info | Set-Content (Join-Path $stage "system.txt")

$desktop = [Environment]::GetFolderPath("Desktop")
if (-not $desktop) { $desktop = $env:USERPROFILE }
$out = Join-Path $desktop "BESTAGON-logs-$stamp.zip"
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $out -CompressionLevel Optimal
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($count -eq 0) {
    Write-Host "  No log files were found." -ForegroundColor Yellow
    Write-Host "  Sending this anyway is still useful - it says the game never wrote one."
} else {
    Write-Host "  Collected $count log file(s)." -ForegroundColor Green
}
Write-Host ""
Write-Host "  Send this file:" -ForegroundColor Cyan
Write-Host "    $out"
Write-Host ""
