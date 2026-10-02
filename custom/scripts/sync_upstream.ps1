#requires -Version 5.1
<#
  sync_upstream.ps1
  Bring upstream/main into paul/main without losing Paul's mod layer.

  Safety model:
    - paul/main is never rewritten here; only forward merges happen.
    - On conflict the merge is left paused and the script exits 2 with manual steps.
      It never guesses a resolution.
    - custom/patches/ always holds a replayable copy of every mod,
      so even a botched merge can be rebuilt with rebuild.ps1.

  ASCII only: PowerShell 5.1 reads scripts as ANSI, non-ASCII comments get garbled.
#>
param(
    [switch]$Push,
    [string]$Branch = 'paul/main'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$logDir  = Join-Path $PSScriptRoot '..\state'
$logFile = Join-Path $logDir 'last-sync.log'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Say($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Write-Host $line
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

"### sync_upstream run at $(Get-Date -Format o)" | Add-Content -Path $logFile -Encoding UTF8

Set-Location $repoRoot
Say "repo root : $repoRoot"

git rev-parse --verify --quiet $Branch 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Say "branch $Branch missing -> creating from main"
    git branch $Branch main
    if ($LASTEXITCODE -ne 0) { throw "cannot create $Branch" }
}

$current = (git rev-parse --abbrev-ref HEAD).Trim()
if ($current -ne $Branch) {
    git checkout $Branch 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "cannot checkout $Branch (dirty tree?)" }
    Say "checked out $Branch"
}

git fetch upstream --tags --prune 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'git fetch upstream failed' }

$upHead = (git rev-parse upstream/main).Trim()
$ourHead = (git rev-parse HEAD).Trim()
Say "upstream/main = $upHead"
Say "$Branch     = $ourHead"

git merge-base --is-ancestor upstream/main $Branch 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Say 'already up to date, nothing to do'
    exit 0
}

git merge --no-ff --no-edit upstream/main 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Say 'CONFLICT: merge paused, manual action required'
    Say '  fix the files, then:  git add -A ; git commit'
    Say '  or give up entirely:  git merge --abort'
    Say '  mod layer is intact - custom/patches/ can rebuild from scratch'
    $conflicts = (git diff --name-only --diff-filter=U) -join ', '
    Say "  conflicting files: $conflicts"
    "RESULT=CONFLICT" | Add-Content -Path $logFile -Encoding UTF8
    exit 2
}

Say 'merge OK'
Say 'next: re-verify every row in custom/PATCHES.md (column Verify)'

if ($Push) {
    git push origin $Branch 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Say 'push failed (see git output)'; exit 3 }
    Say "pushed $Branch"
} else {
    Say 'not pushed (use -Push)'
}

"RESULT=OK" | Add-Content -Path $logFile -Encoding UTF8
exit 0
