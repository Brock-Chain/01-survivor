# BESTAGON - locate the Godot engine binary. No absolute paths, ever.
#
# ASCII ONLY, same reason as verify.ps1 and package.ps1: Windows PowerShell 5.1
# reads a .ps1 as ANSI unless it has a BOM, so one em-dash here is a parser error.
#
# Dot-source it:  . (Join-Path $PSScriptRoot "find_godot.ps1")
#
# Resolution order, first hit wins:
#
#   1. $env:GODOT                     an explicit override, any checkout anywhere
#   2. ..\..\engine\<console exe>      THIS WORKSPACE. the normal path here
#   3. PATH                            godot / godot4 / the versioned console exe
#
# WHY THIS FILE EXISTS. verify.ps1 and package.ps1 both resolved the engine as a
# single hardcoded `$root\..\..\engine\...`, with no override and no message. That
# is not an absolute path, so the absolute-path guard in verify.ps1 stayed green
# on it for the entire life of the repo - the guard was watching a narrower thing
# than the promise it exists to protect. The effect was the same one the guard was
# written for: the layout held on exactly one machine.
#
# Measured 2026-08-04, cloning this PUBLIC repo to a scratch directory and running
# the command the README puts first: every stage failed with
#
#   Start-Process : This command cannot be run due to the error: The system
#   cannot find the file specified.
#
# Five stages, five identical exceptions, and not one of them said "engine".
# `--headless --import` on that same clone was clean, so the project was always
# fine - only the tooling was unforkable. A gate a stranger cannot run is not a
# gate, and a build script whose failure does not name what is missing is worse
# than one that has no dependency at all.
#
# This mirrors tools/strudel_renderer.py, which already resolves the audio
# renderer exactly this way and for exactly this reason. When a second dependency
# needs finding, it goes here too.

$script:GodotExeNames = @(
  "Godot_v4.7.1-stable_win64_console.exe",
  "godot4",
  "godot"
)

function Get-GodotCandidates {
  param([Parameter(Mandatory)][string]$Root)

  # Assumes the documented workspace layout: games\NN-name\ beside engine\.
  # A fork will not have this, which is the entire point of the other two entries.
  @(
    [pscustomobject]@{
      Label = "the workspace engine\ folder"
      Path  = (Join-Path $Root "..\..\engine\Godot_v4.7.1-stable_win64_console.exe")
    }
  )
}

function Find-Godot {
  param([Parameter(Mandatory)][string]$Root)

  # An explicit override that is wrong is a mistake worth surfacing, not
  # something to silently fall through from - same rule as $STRUDEL_RENDERER.
  if ($env:GODOT) {
    if (Test-Path -LiteralPath $env:GODOT -PathType Leaf) { return (Resolve-Path -LiteralPath $env:GODOT).Path }
    return $null
  }

  foreach ($c in (Get-GodotCandidates -Root $Root)) {
    if (Test-Path -LiteralPath $c.Path -PathType Leaf) { return (Resolve-Path -LiteralPath $c.Path).Path }
  }

  foreach ($name in $script:GodotExeNames) {
    $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
  }

  return $null
}

function Get-GodotSearchReport {
  param([Parameter(Mandatory)][string]$Root)

  $lines = @("Godot 4.7.1 not found. Looked in:")
  if ($env:GODOT) {
    $lines += "  `$env:GODOT = $($env:GODOT)   <- set, but not a file"
  } else {
    $lines += "  `$env:GODOT                    <- not set (the override)"
  }
  foreach ($c in (Get-GodotCandidates -Root $Root)) {
    $lines += "  $($c.Path)   <- $($c.Label)"
  }
  $lines += "  PATH: $($script:GodotExeNames -join ', ')   <- none of these resolved"
  $lines += @(
    "",
    "The engine is NOT vendored in this repo - it is a ~120 MB binary and it is",
    "not ours to redistribute. Download Godot 4.7.1 stable, STANDARD build (not",
    "mono - mono ships no web export templates) from https://godotengine.org, then",
    "point this at it:",
    "",
    # Written as a placeholder rather than a specimen path on purpose: this file
    # is tracked .ps1, so the absolute-path guard in verify.ps1 reads it, and that
    # guard has no exemption for examples. It caught this line. Good.
    "    `$env:GODOT = '<full path to Godot_v4.7.1-stable_win64_console.exe>'",
    "",
    "Use the _console executable. The plain one detaches from the terminal and",
    "every line of output is lost, which makes the gate below unable to grep for",
    "the errors it exists to catch.",
    "",
    "You do not need any of this to PLAY BESTAGON - the itch.io build is a browser",
    "page. You need it to build or verify from source."
  )
  return ($lines -join "`n")
}

function Assert-Godot {
  param([Parameter(Mandatory)][string]$Root)

  $godot = Find-Godot -Root $Root
  if (-not $godot) {
    Write-Host ""
    Write-Host (Get-GodotSearchReport -Root $Root) -ForegroundColor Red
    Write-Host ""
    exit 1
  }
  return $godot
}
