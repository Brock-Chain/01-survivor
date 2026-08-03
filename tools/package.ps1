# BESTAGON - build both exports and package them for someone else to play.
#
#   powershell -File tools/package.ps1
#
# ASCII ONLY, same reason as verify.ps1: Windows PowerShell 5.1 reads a .ps1 as
# ANSI unless it has a BOM, so one em-dash in a comment is a parser error.
#
# Exists because this was done by hand twice and got it wrong both times. The
# first pass shipped a web zip with stray .import sidecars that Godot had
# generated inside builds/, and no local launcher - so the tester double-clicked
# index.html, hit the browser's file:// fetch block, and saw the Godot splash
# with "Failed to fetch". Nothing was broken; the package was just wrong.
#
# The two things that MUST be true of the web zip and are easy to get wrong:
#   1. index.html sits at the ZIP ROOT. itch.io looks for it there and nowhere
#      else, so a zip of the folder rather than its contents silently fails.
#   2. START-HERE.bat ships alongside it, because "serve it over http" is not a
#      discoverable instruction for someone who was sent a game to try.

param([string]$Stamp = (Get-Date -Format "yyyy-MM-dd"))

$ErrorActionPreference = "Stop"
$root   = Split-Path -Parent $PSScriptRoot
$godot  = Join-Path $root "..\..\engine\Godot_v4.7.1-stable_win64_console.exe"
$builds = Join-Path $root "builds"
$share  = Join-Path $PSScriptRoot "share"

function Fail([string]$Message) { Write-Host "  $Message" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "=== exports ===" -ForegroundColor Cyan

# A previous run of the game keeps a handle on the .exe and the export then dies
# on "Failed to rename temporary file", which reads like a build error and is not.
Get-Process -Name "BESTAGON" -ErrorAction SilentlyContinue | Stop-Process -Force

foreach ($p in @(
    @{ Name = "Web";             Out = "builds/web/index.html" },
    @{ Name = "Windows Desktop"; Out = "builds/windows/BESTAGON.exe" })) {
  & $godot --headless --path $root --export-release $p.Name $p.Out | Out-Null
  if ($LASTEXITCODE -ne 0) { Fail "export failed: $($p.Name)" }
  Write-Host "  ok  $($p.Name)" -ForegroundColor Green
}

# builds/ lives inside the project, so the editor's importer generates .import
# sidecars next to the exported PNGs. Harmless to the game, noise in a zip.
Get-ChildItem (Join-Path $builds "web") -Filter *.import -ErrorAction SilentlyContinue |
  Remove-Item -Force

Write-Host ""
Write-Host "=== package ===" -ForegroundColor Cyan

Copy-Item (Join-Path $share "START-HERE.bat") (Join-Path $builds "web") -Force
Copy-Item (Join-Path $share "PLAYTEST.txt")   (Join-Path $builds "web") -Force

$webZip = Join-Path $builds "BESTAGON-web-$Stamp.zip"
$winZip = Join-Path $builds "BESTAGON-windows-$Stamp.zip"
Remove-Item $webZip, $winZip -Force -ErrorAction SilentlyContinue

# "web\*" not "web" - the glob puts the CONTENTS at the zip root, which is what
# itch.io requires. Zipping the folder itself produces a zip that uploads fine
# and then shows a blank page.
Compress-Archive -Path (Join-Path $builds "web\*") -DestinationPath $webZip -CompressionLevel Optimal
Compress-Archive -Path (Join-Path $builds "windows\BESTAGON.exe"), (Join-Path $share "PLAYTEST.txt") `
  -DestinationPath $winZip -CompressionLevel Optimal

# Prove the layout rather than trusting it. A web zip whose index.html is not at
# the root is the single failure that would waste the tester's time, not ours.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($webZip)
$names = $zip.Entries | ForEach-Object { $_.FullName }
$zip.Dispose()
foreach ($required in @("index.html", "index.pck", "index.wasm", "START-HERE.bat")) {
  if ($names -notcontains $required) { Fail "web zip is missing $required at its root" }
}

Write-Host ""
foreach ($z in @($webZip, $winZip)) {
  $mb = [math]::Round((Get-Item $z).Length / 1MB, 1)
  Write-Host ("  {0,-38} {1,5} MB" -f (Split-Path $z -Leaf), $mb) -ForegroundColor Green
}
Write-Host ""
Write-Host "  Web zip is itch.io ready: upload as an HTML game, 1280x720 embed." -ForegroundColor Gray
Write-Host "  The build is single-threaded, so it does NOT need itch's" -ForegroundColor Gray
Write-Host "  SharedArrayBuffer option - leave that unchecked." -ForegroundColor Gray
Write-Host ""
