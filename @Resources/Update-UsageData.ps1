# Refreshes UsageData.json:
#   Claude  -> real /usage percentages scraped from the Claude Code TUI
#              via node scrape-usage.js (authoritative subscription numbers)
#   Codex   -> token totals summed from ~/.codex/sessions/*.jsonl

$ErrorActionPreference = 'Continue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outFile   = Join-Path $scriptDir 'UsageData.json'

# Codex and Claude now both come from PTY-scraped /status + /usage panels
# (real subscription percentages from OpenAI / Anthropic).

# --- Claude: scrape /usage ---
$claudeSession = @{ used = 0; max = 100; resetAtUtc = '' }
$claudeWeekly  = @{ used = 0; max = 100; resetAtUtc = '' }
$claudeSonnet  = @{ used = 0; max = 100; resetAtUtc = '' }
try {
  $raw = & node (Join-Path $scriptDir 'scrape-usage.js') 2>$null
  if ($LASTEXITCODE -eq 0 -and $raw) {
    $u = $raw | ConvertFrom-Json
    if ($u.session.pct      -ne $null) { $claudeSession.used = [int]$u.session.pct;      $claudeSession.resetAtUtc = [string]$u.session.reset }
    if ($u.weeklyAll.pct    -ne $null) { $claudeWeekly.used  = [int]$u.weeklyAll.pct;    $claudeWeekly.resetAtUtc  = [string]$u.weeklyAll.reset }
    if ($u.weeklySonnet.pct -ne $null) { $claudeSonnet.used  = [int]$u.weeklySonnet.pct; $claudeSonnet.resetAtUtc  = [string]$u.weeklySonnet.reset }
  } else {
    Write-Warning "scrape-usage.js failed (exit $LASTEXITCODE)"
  }
} catch { Write-Warning "Claude scrape failed: $_" }

# --- Codex: scrape /status ---
$codexSession = @{ used = 0; max = 100; resetAtUtc = '' }
$codexWeekly  = @{ used = 0; max = 100; resetAtUtc = '' }
try {
  $raw = & node (Join-Path $scriptDir 'scrape-codex.js') 2>$null
  if ($LASTEXITCODE -eq 0 -and $raw) {
    $u = $raw | ConvertFrom-Json
    if ($u.session.pct -ne $null) { $codexSession.used = [int]$u.session.pct; $codexSession.resetAtUtc = [string]$u.session.reset }
    if ($u.weekly.pct  -ne $null) { $codexWeekly.used  = [int]$u.weekly.pct;  $codexWeekly.resetAtUtc  = [string]$u.weekly.reset }
  } else {
    Write-Warning "scrape-codex.js failed (exit $LASTEXITCODE)"
  }
} catch { Write-Warning "Codex scrape failed: $_" }

$payload = [ordered]@{
  claude = [ordered]@{
    session          = $claudeSession
    weeklyAllModels  = $claudeWeekly
    weeklySonnet     = $claudeSonnet
  }
  codex = [ordered]@{
    session = $codexSession
    weekly  = $codexWeekly
  }
}

$payload | ConvertTo-Json -Depth 6 | Set-Content -Path $outFile -Encoding UTF8
Write-Host "Wrote $outFile"
