# BESTAGON - play under a watchdog that turns a freeze into evidence.
#
#   powershell -File tools/hang-watchdog.ps1                # watches builds/windows/BESTAGON.exe
#   powershell -File tools/hang-watchdog.ps1 -Exe <path>    # watch some other build
#
# ASCII ONLY, same reason as package.ps1: Windows PowerShell 5.1 reads a .ps1 as
# ANSI unless it has a BOM, so one em-dash in a comment is a parser error.
#
# Launches the game, samples CPU + Responding once a second, and the moment the
# window stops responding for -HangSeconds it captures a FULL minidump and fixes
# the ACL so it is readable without elevation (comsvcs writes it SYSTEM-only;
# we own the file, so an owner re-grant needs no admin). The process is left
# ALIVE afterwards for live inspection - kill it yourself when done.
#
# The game's stdout and the watchdog's samples land in two files sharing one
# wall clock, so the last game line before resp=False is what the game was
# doing when it stalled. With the in-game flight recorder (always-on [stats]/
# [card]/[exit] breadcrumbs) that brackets a freeze to seconds.
#
# Exists because the first hang dump (2026-08-03) was captured by luck: the
# process happened to still be hung when someone looked. A freeze that is not
# dumped teaches nothing.
#
# NOTE: no dev flags by default. Any --dev- flag redirects the save to the dev
# profile, and a watchdog run should be a REAL run that banks into your real
# records. Pass -GameArgs @('--','--dev-stats') if you want the [meta] line and
# do not care about the profile.

param(
    [string]$Exe,
    [string[]]$GameArgs = @(),
    [int]$HangSeconds = 10,
    [string]$OutDir
)

# NOT param defaults: $PSScriptRoot comes back EMPTY inside a param() default
# under Windows PowerShell 5.1, which made every Join-Path below throw before
# the game ever launched.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Exe) { $Exe = Join-Path $here "..\builds\windows\BESTAGON.exe" }
if (-not $OutDir) { $OutDir = Join-Path $here "..\.ai" }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

if (-not (Test-Path $Exe)) {
    Write-Host "  exe not found: $Exe" -ForegroundColor Red
    Write-Host "  build it first: powershell -File tools/package.ps1 (or the export command in CLAUDE.md)"
    exit 1
}

$stamp = Get-Date -Format "yyyy-MM-ddTHH.mm.ss"
$stdout = Join-Path $OutDir "run-$stamp.stdout.txt"
$samples = Join-Path $OutDir "run-$stamp.samples.txt"

$proc = Start-Process -FilePath $Exe -ArgumentList $GameArgs -PassThru -RedirectStandardOutput $stdout
Start-Sleep -Milliseconds 1500
"watching pid $($proc.Id)  ($([System.IO.Path]::GetFileName($Exe)))"
"game stdout -> $stdout"
"samples     -> $samples"
$hdr = "time      cpu_s   d_cpu  resp  ws_mb  threads"
$hdr
$hdr | Out-File $samples -Encoding utf8

$hung = 0
$prev = $null
while (-not $proc.HasExited) {
    Start-Sleep -Seconds 1
    try { $proc.Refresh() } catch { break }
    # Refresh() succeeds on an exited process but zeroes its counters, which
    # once wrote a final garbage sample (d_cpu=-193, threads=0). Check AFTER.
    if ($proc.HasExited) { break }
    $cpu = $proc.TotalProcessorTime.TotalSeconds
    $d = if ($null -eq $prev) { 0 } else { $cpu - $prev }
    $prev = $cpu
    $resp = $proc.Responding
    $line = "{0}  {1,7:n1} {2,7:n2}  {3,-5} {4,6:n0} {5,8}" -f (Get-Date -Format "HH:mm:ss"), $cpu, $d, $resp, ($proc.WorkingSet64 / 1MB), $proc.Threads.Count
    $line
    $line | Out-File $samples -Append -Encoding utf8

    if (-not $resp) { $hung++ } else { $hung = 0 }
    if ($hung -ge $HangSeconds) {
        $dump = Join-Path $OutDir "hang-$($proc.Id)-$stamp.dmp"
        "HUNG for ${hung}s -- dumping to $dump"
        # Resolved from SystemRoot, not a literal drive letter: the absolute
        # path guard rejects tracked code that only works on one machine, and
        # it caught the literal form of this exact line.
        $comsvcs = Join-Path $env:SystemRoot "System32\comsvcs.dll"
        rundll32.exe $comsvcs, MiniDump $($proc.Id) $dump full
        icacls "$dump" /grant "$($env:USERNAME):(R)" | Out-Null
        "dump written: {0:n0} MB" -f ((Get-Item $dump).Length / 1MB)
        "process left ALIVE for inspection -- kill it yourself when done."
        break
    }
}
if ($proc.HasExited) { "process exited with code $($proc.ExitCode)" }
