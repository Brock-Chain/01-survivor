# BESTAGON - the whole gate, one command.
#
#   powershell -File tools/verify.ps1
#   powershell -File tools/verify.ps1 soak      # adds an 11-minute fixed-step run
#
# ASCII ONLY, deliberately: Windows PowerShell 5.1 reads a .ps1 as ANSI unless it
# has a BOM, so a single em-dash in a comment is a parser error. Learned the hard
# way while writing this file.
#
# Exists because of review finding 29. The documented smoke command was
#   <console.exe> --headless --path . --quit-after 300
# and run/main_scene is title.tscn, so it booted the TITLE SCREEN, sat there, and
# exited 0 no matter what was broken in gameplay. It could not fail on a gameplay
# error because it never loaded main.tscn. Every "smoke passed" before this
# script was evidence of nothing.
#
# Two further traps encoded here so nobody has to remember them:
#   * gameplay smoke must name main.tscn EXPLICITLY, and must assert the
#     "BESTAGON boot OK" line actually appeared. Exit 0 alone proves nothing.
#   * --dev-autopick takes the call_deferred+break path in _check_level_up and
#     therefore NEVER calls LevelUpPanel.show_offers, so a soak with autopick
#     leaves the level-up screen untested. The no-autopick pass below covers it.

# A positional STRING, not a [switch]: powershell.exe -File passes every argument
# as a string, so a switch parameter cannot bind and the script dies before it
# runs a single step.
param([string]$Mode = "")

$ErrorActionPreference = "Continue"
$root   = Split-Path -Parent $PSScriptRoot
$godot  = Join-Path $root "..\..\engine\Godot_v4.7.1-stable_win64_console.exe"
$script:failed = @()

# Teardown noise that is genuinely benign, matched as narrowly as possible. The
# audio server holds every stream that played past the leak check, and the
# renderer/physics dummies release their last RIDs after it. Anything else
# containing ERROR is a real failure.
$benign = @(
  'resources still in use at exit',
  'RID allocations of type'
)

function Invoke-Step {
  param([string]$Name, [string[]]$GodotArgs, [string]$MustContain)

  Write-Host ""
  Write-Host "=== $Name ===" -ForegroundColor Cyan

  # Start-Process with real file redirection, NOT `& exe 2>&1`. In Windows
  # PowerShell 5.1 merging a native command's stderr into the pipeline wraps
  # every line in an ErrorRecord whose text contains "NativeCommandError" - which
  # this function's own error filter then matched, so the gate failed itself on
  # three steps that had actually passed.
  $so = [IO.Path]::GetTempFileName()
  $se = [IO.Path]::GetTempFileName()
  $proc = Start-Process -FilePath $godot -ArgumentList $GodotArgs -NoNewWindow -Wait `
    -PassThru -RedirectStandardOutput $so -RedirectStandardError $se
  $code = $proc.ExitCode
  $out = ((Get-Content $so -Raw) + "`n" + (Get-Content $se -Raw))
  Remove-Item $so, $se -Force -ErrorAction SilentlyContinue

  $errors = $out -split "`r?`n" | Where-Object {
    $line = $_
    ($line -match 'SCRIPT ERROR|Parse Error|ERROR|Failed to load|Cannot call') -and
    -not ($benign | Where-Object { $line -match [regex]::Escape($_) })
  }

  if ($code -ne 0) { $script:failed += "$Name (exit $code)" }
  if ($errors) {
    $script:failed += "$Name (errors)"
    $errors | Select-Object -First 8 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
  }
  if ($MustContain -and ($out -notmatch [regex]::Escape($MustContain))) {
    $script:failed += "$Name (missing '$MustContain' - did it actually run?)"
  }
  if ((-not $errors) -and $code -eq 0) { Write-Host "  ok" -ForegroundColor Green }
  return $out
}

# ABSOLUTE PATH GUARD. This repo is PUBLIC, and an absolute path in it is never a
# local convenience - it is a claim that only works on one machine, and it is
# invisible to the person who wrote it. tools/build_music.py carried a hardcoded
# path into a private repo for months while the README promised the .ogg files
# were regenerable build artifacts. It was true for exactly one computer on
# earth. (This comment describes it rather than quoting it, because the guard
# below has no exemption for examples - which is the point of it.)
#
# CODE ONLY (.gd/.py/.ps1/.mjs) and tracked files only - prose legitimately shows
# example paths, and node_modules is gitignored so it never reaches this. The
# lookbehind is what keeps https:// , res:// and user:// from matching.
Write-Host ""
Write-Host "=== absolute path guard ===" -ForegroundColor Cyan
$pattern = '(?<![A-Za-z])[A-Za-z]:[\\/]|[\\/](Users|home)[\\/]'
$hits = @()
foreach ($rel in @(& git -C $root ls-files -- '*.gd' '*.py' '*.ps1' '*.mjs')) {
  $full = Join-Path $root $rel
  if (-not (Test-Path $full)) { continue }
  foreach ($m in (Select-String -Path $full -Pattern $pattern -AllMatches)) {
    $hits += ("  {0}:{1}: {2}" -f $rel, $m.LineNumber, $m.Line.Trim())
  }
}
if ($hits.Count -gt 0) {
  $script:failed += "absolute path guard ($($hits.Count) found)"
  $hits | Select-Object -First 8 | ForEach-Object { Write-Host $_ -ForegroundColor Red }
} else {
  Write-Host "  ok" -ForegroundColor Green
}

Invoke-Step "import" @('--headless','--import','--path',$root) | Out-Null

$tests = Invoke-Step "unit tests" @('--headless','--path',$root,'-d','-s',
  'addons/gut/gut_cmdln.gd','-gdir=res://tests','-ginclude_subdirs','-gexit') "Passing Tests"
($tests -split "`r?`n" | Select-String 'Tests\s+\d|Passing|Failing') | ForEach-Object { Write-Host "  $_" }

# The level-up panel only exists on the no-autopick path - see the header.
#
# --dev-noprofile does nothing to gameplay; it only redirects the save. Without
# it this step banked into the REAL profile on every run, because the save
# redirect keys off any --dev- flag and this is the one step that deliberately
# carries none. The title screen was advertising "best 00:08" off seven bot runs.
Invoke-Step "gameplay smoke (level-up panel reachable)" @('--headless','--path',$root,
  '--fixed-fps','60','res://scenes/main/main.tscn','--quit-after','2400','--',
  '--dev-noprofile') "BESTAGON boot OK" | Out-Null

$layout = Invoke-Step "pause layout" @('--headless','--path',$root,
  'res://scenes/dev/pause_layout_check.tscn','--quit-after','600') "FAILURES=0"
($layout -split "`r?`n" | Select-String 'FAILURES') | ForEach-Object { Write-Host "  $_" }

if ($Mode -eq "soak") {
  # 40000 frames at a fixed 60fps = 11:06 of game time, which clears BOTH boss
  # events. The --dev- flags redirect the save (finding 12), so this cannot
  # pollute the real profile.
  $soak = Invoke-Step "11-minute soak (both boss events)" @('--headless','--path',$root,
    '--fixed-fps','60','res://scenes/main/main.tscn','--quit-after','40000','--',
    '--dev-godmode','--dev-autopick','--dev-autocontinue','--dev-unlocks','--dev-stats') "[boss]"
  ($soak -split "`r?`n" | Select-String '\[boss\]|\[victory\]') | ForEach-Object { Write-Host "  $_" }
}

Write-Host ""
if ($script:failed.Count -gt 0) {
  Write-Host "VERIFY FAILED:" -ForegroundColor Red
  $script:failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit 1
}
Write-Host "VERIFY PASSED" -ForegroundColor Green
exit 0
