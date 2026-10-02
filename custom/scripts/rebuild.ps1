#requires -Version 5.1
<#
  rebuild.ps1
  Rebuild the mod layer on top of a fresh upstream baseline.

  Use this when:
    - upstream rewrote files the mods touch and repeated merges became pointless, or
    - you want a clean linear base instead of a mesh of merges.

  What it does:
    1. saves nothing but relies on git objects (nothing is deleted: the old tip stays
       reachable as paul/main@{1} and is also reflogged for 90 days)
    2. creates/rewrites <Branch> from -UpstreamRef
    3. git am's every *.patch in custom/patches in filename order
    4. stops on the first failing patch and tells you exactly where it stopped

  ASCII only: PowerShell 5.1 reads scripts as ANSI.
#>
param(
    [string]$UpstreamRef = 'upstream/main',
    [string]$Branch = 'paul/main',
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$patchDir   = Join-Path $PSScriptRoot '..\patches'
$logDir     = Join-Path $PSScriptRoot '..\state'
$logFile    = Join-Path $logDir 'last-rebuild.log'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Say($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Write-Host $line
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

"### rebuild run at $(Get-Date -Format o) ref=$UpstreamRef" | Add-Content -Path $logFile -Encoding UTF8

Set-Location $repoRoot

$dirty = (git status --porcelain).Trim()
if ($dirty -and -not $Force) {
    Say 'worktree is dirty; commit or stash first, or pass -Force'
    exit 1
}

$patches = Get-ChildItem -Path $patchDir -Filter *.patch -File -ErrorAction SilentlyContinue |
           Sort-Object Name
if (-not $patches) {
    Say "no .patch files in $patchDir - nothing to replay"
    exit 0
}
Say "found $($patches.Count) patch(es)"

git fetch upstream --tags 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'git fetch upstream failed' }

$oldTip = ''
git rev-parse --verify --quiet $Branch 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { $oldTip = (git rev-parse $Branch).Trim() }

git branch -f $Branch $UpstreamRef 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "cannot set $Branch to $UpstreamRef" }
git checkout $Branch 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "cannot checkout $Branch" }

Say "new base = $((git rev-parse HEAD).Trim()) (old tip was ${oldTip:-none})"

foreach ($p in $patches) {
    git am --3way $p.FullName 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Say "STOP: patch failed -> $($p.Name)"
        Say "  resolve, then: git add -A ; git am --continue"
        Say "  or skip it :   git am --skip   (remember to strike it off PATCHES.md)"
        Say "  or bail out:   git am --abort"
        "RESULT=FAILED_AT=$($p.Name)" | Add-Content -Path $logFile -Encoding UTF8
        exit 2
    }
    Say "applied $($p.Name)"
}

Say "all patches applied on top of $UpstreamRef"
Say 'verify with the steps in custom/PATCHES.md, then: git push origin paul/main'
"RESULT=OK" | Add-Content -Path $logFile -Encoding UTF8
exit 0
