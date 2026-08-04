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
# See verify.ps1 and tools/find_godot.ps1 - resolved, never hardcoded.
. (Join-Path $PSScriptRoot "find_godot.ps1")
$godot  = Assert-Godot -Root $root
$builds = Join-Path $root "builds"
$share  = Join-Path $PSScriptRoot "share"

function Fail([string]$Message) { Write-Host "  $Message" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "=== exports ===" -ForegroundColor Cyan

# A previous run of the game keeps a handle on the .exe and the export then dies
# on "Failed to rename temporary file", which reads like a build error and is not.
Get-Process -Name "BESTAGON" -ErrorAction SilentlyContinue | Stop-Process -Force

# CLEAN FIRST. The web zip is built by globbing builds/web/*, so anything left
# from a previous run ships. PLAYTEST.txt was renamed to README.txt and the
# stale file sat in the directory, so the "release" zip carried BOTH -- one of
# them a playtest note with a hardcoded date, deleted from the repo two commits
# earlier. An export directory that is only ever added to is a directory that
# quietly accumulates whatever you thought you had removed.
# Recreated immediately: Godot refuses to export into a folder that does not
# exist ("Target folder does not exist or is inaccessible").
foreach ($dir in @("web", "windows")) {
  $path = Join-Path $builds $dir
  if (Test-Path $path) { Remove-Item $path -Recurse -Force }
  New-Item -ItemType Directory -Path $path -Force | Out-Null
}

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
Copy-Item (Join-Path $share "README.txt")   (Join-Path $builds "web") -Force

# The DATE alone cannot answer "is this the latest one?". Three builds shipped on
# 2026-08-03 under identical filenames, and the only way to tell them apart was a
# file timestamp nobody looks at. The commit SHA does answer it, and answers a
# better question too: it says exactly which source a zip came from, which is the
# thing you actually want when a tester reports something from a build you no
# longer have. Falls back to the clock outside a git checkout.
$sha = (& git -C $root rev-parse --short HEAD 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $sha) { $sha = Get-Date -Format "HHmm" }
$Stamp = "$Stamp-$sha"

# Warn rather than encode it in the name: this workspace runs concurrent sessions,
# so the tree is routinely dirty with work that is not this build's and a
# permanent "-dirty" suffix would just stop meaning anything.
$dirty = & git -C $root status --porcelain 2>$null
if ($dirty) {
  Write-Host "  NOTE: tree is dirty, so $sha does not fully describe this build:" -ForegroundColor Yellow
  $dirty | ForEach-Object { Write-Host "        $_" -ForegroundColor Yellow }
}

$webZip = Join-Path $builds "BESTAGON-web-$Stamp.zip"
$winZip = Join-Path $builds "BESTAGON-windows-$Stamp.zip"

# Same reasoning as the builds/ clean above, one directory up: a folder that is
# only ever added to accumulates old zips, and then "which one do I send?" is a
# question again. Exactly one pair survives a package run.
Get-ChildItem (Join-Path $builds "BESTAGON-*.zip") -ErrorAction SilentlyContinue |
  Remove-Item -Force

# "web\*" not "web" - the glob puts the CONTENTS at the zip root, which is what
# itch.io requires. Zipping the folder itself produces a zip that uploads fine
# and then shows a blank page.
Compress-Archive -Path (Join-Path $builds "web\*") -DestinationPath $webZip -CompressionLevel Optimal
# COLLECT-LOGS ships with the WINDOWS zip only. The web build has no log file to
# collect - a browser build's output goes to the devtools console and never to
# disk - so shipping it there would be a button that does nothing.
Compress-Archive -Path (Join-Path $builds "windows\BESTAGON.exe"), (Join-Path $share "README.txt"), `
  (Join-Path $share "COLLECT-LOGS.bat"), (Join-Path $share "collect-logs.ps1") `
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

# The windows zip had NO assertion at all until 2026-08-03, which is how a zip
# ships missing the one file that exists to be found after a crash.
$zip = [System.IO.Compression.ZipFile]::OpenRead($winZip)
$names = $zip.Entries | ForEach-Object { $_.FullName }
$zip.Dispose()
foreach ($required in @("BESTAGON.exe", "README.txt", "COLLECT-LOGS.bat", "collect-logs.ps1")) {
  if ($names -notcontains $required) { Fail "windows zip is missing $required at its root" }
}

# The log collector is worthless if the build it ships with buffers its log away.
# Release builds do exactly that unless this is set, and the setting lives in a
# different file from the packaging, so assert them together or they drift.
$proj = Get-Content (Join-Path $root "project.godot") -Raw
if ($proj -notmatch "run/flush_stdout_on_print\s*=\s*true") {
  Fail "project.godot lacks run/flush_stdout_on_print=true - a freeze would ship a 0-byte log"
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
