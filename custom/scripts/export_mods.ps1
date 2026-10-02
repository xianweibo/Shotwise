#requires -Version 5.1
<#
  export_mods.ps1
  Regenerate custom/patches/ from the commits that exist only on paul/main.

  Call this after landing a mod by hand. It is idempotent: the directory is wiped and
  rewritten, so the count always matches the real number of mod commits.

  --no-merges keeps pure integration merges out of the patch set; upstream imports stay
  visible as merges in the branch history instead of being flattened into fake patches.

  ASCII only: PowerShell 5.1 reads scripts as ANSI.
#>
param(
    [string]$Branch = 'paul/main'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$patchDir = Join-Path $PSScriptRoot '..\patches'
$logDir   = Join-Path $PSScriptRoot '..\state'
$logFile  = Join-Path $logDir 'last-export.log'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Say($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Write-Host $line
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

"### export_mods run at $(Get-Date -Format o)" | Add-Content -Path $logFile -Encoding UTF8

Set-Location $repoRoot

if (Test-Path $patchDir) {
    Get-ChildItem -Path $patchDir -Filter *.patch -File | Remove-Item -Force
} else {
    New-Item -ItemType Directory -Path $patchDir -Force | Out-Null
}

git fetch upstream 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'git fetch upstream failed' }

$range = "upstream/main..$Branch"
git format-patch --no-merges --output-directory $patchDir $range 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Say 'git format-patch failed'; exit 2 }

$count = (Get-ChildItem -Path $patchDir -Filter *.patch -File -ErrorAction SilentlyContinue | Measure-Object).Count
Say "exported $count patch(es) from $range"

if ($count -eq 0) {
    Say 'paul/main has no commits ahead of upstream - no local mods registered'
    Say 'check custom/PATCHES.md: it should be empty too, otherwise commits were lost'
}

git --no-pager log --oneline --no-merges $range | Out-String |
    Add-Content -Path $logFile -Encoding UTF8

"RESULT=OK count=$count" | Add-Content -Path $logFile -Encoding UTF8
exit 0
