<#
.SYNOPSIS
  Installs the approved Claude Code skills and plugins on Windows in one go.

.DESCRIPTION
  - Installs the Claude Code command line (claude) if it is missing.
  - Adds each plugin marketplace and installs each plugin for your user account,
    so the plugins work in the VS Code extension and the desktop app.
  - Installs the terminal-based skills (Cloudflare Security Audit, Graphify)
    when their prerequisites (Node.js, uv) are present; otherwise skips them with a warning.
  - Safe to run again: anything already installed is skipped.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\Install-ClaudeSkills.ps1
#>

$ErrorActionPreference = 'Continue'
$results = New-Object System.Collections.Generic.List[object]

function Add-Result([string]$Name, [string]$Status, [string]$Detail = '') {
    $results.Add([pscustomobject]@{ Item = $Name; Status = $Status; Detail = $Detail })
}

function Test-Command([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

Write-Host "`n=== Claude Code skills installer ===`n" -ForegroundColor Cyan

# --- 1. Prerequisites -------------------------------------------------------
if (-not (Test-Command 'git')) {
    Write-Host "Git is not installed. Install Git for Windows (git-scm.com/downloads/win), then run this script again." -ForegroundColor Red
    exit 1
}

if (-not (Test-Command 'claude')) {
    Write-Host "Claude Code command line not found. Installing it with the official installer..." -ForegroundColor Yellow
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    $claudeBin = Join-Path $env:USERPROFILE '.local\bin'
    if (Test-Path $claudeBin) { $env:Path = "$claudeBin;$env:Path" }
    if (-not (Test-Command 'claude')) {
        Write-Host "Claude Code installed, but 'claude' is not on PATH yet. Open a new PowerShell window and run this script again." -ForegroundColor Red
        exit 1
    }
    Add-Result 'Claude Code CLI' 'Installed'
} else {
    Add-Result 'Claude Code CLI' 'Already present'
}

# --- 2. Plugins -------------------------------------------------------------
# Marketplace source (GitHub owner/repo) and the plugins to install from it.
$marketplaces = @(
    @{ Source = 'anthropics/claude-plugins-official'; Name = 'claude-plugins-official'
       Plugins = @('claude-security', 'superpowers', 'code-review', 'code-simplifier', 'frontend-design', 'skill-creator') },
    @{ Source = 'DietrichGebert/ponytail';     Name = 'ponytail';       Plugins = @('ponytail') },
    @{ Source = 'ayghri/i-have-adhd';          Name = 'i-have-adhd';    Plugins = @('i-have-adhd') },
    @{ Source = 'cathrynlavery/diagram-design'; Name = 'diagram-design'; Plugins = @('diagram-design') },
    @{ Source = 'blader/humanizer';            Name = 'humanizer';      Plugins = @('humanizer') },
    @{ Source = 'pbakaus/impeccable';          Name = 'impeccable';     Plugins = @('impeccable') }
)

$knownMarketplaces = (& claude plugin marketplace list 2>&1 | Out-String)
$installedPlugins  = (& claude plugin list 2>&1 | Out-String)

foreach ($m in $marketplaces) {
    if ($knownMarketplaces -match [regex]::Escape($m.Name)) {
        Write-Host "Marketplace $($m.Name): already added" -ForegroundColor DarkGray
    } else {
        Write-Host "Adding marketplace $($m.Source)..." -ForegroundColor Yellow
        & claude plugin marketplace add $m.Source
        if ($LASTEXITCODE -ne 0) {
            foreach ($p in $m.Plugins) { Add-Result $p 'FAILED' "could not add marketplace $($m.Source)" }
            continue
        }
    }

    foreach ($p in $m.Plugins) {
        $id = "$p@$($m.Name)"
        if ($installedPlugins -match [regex]::Escape($id)) {
            Add-Result $p 'Already installed' $id
            continue
        }
        Write-Host "Installing $id..." -ForegroundColor Yellow
        & claude plugin install $id
        if ($LASTEXITCODE -eq 0) { Add-Result $p 'Installed' $id } else { Add-Result $p 'FAILED' $id }
    }
}

# Claude Security needs Python 3.9+ answering to "python3".
$py = (& python3 --version 2>&1 | Out-String).Trim()
if ($py -notmatch 'Python 3\.(9|[1-9]\d)') {
    Add-Result 'python3 check' 'WARNING' 'Claude Security needs Python 3.9+ as "python3". Install from python.org with "Add to PATH" ticked.'
}

# --- 3. Terminal-based skills ----------------------------------------------
# Cloudflare Security Audit (needs Node.js for npx)
if (Test-Command 'npx') {
    Write-Host "Installing Cloudflare security-audit skill for Claude Code..." -ForegroundColor Yellow
    & npx skills add https://github.com/cloudflare/security-audit-skill --skill security-audit -a claude-code -g
    if ($LASTEXITCODE -eq 0) { Add-Result 'security-audit (Cloudflare)' 'Installed' } else { Add-Result 'security-audit (Cloudflare)' 'FAILED' }
} else {
    Add-Result 'security-audit (Cloudflare)' 'SKIPPED' 'Node.js not found. Install Node.js, then run this script again.'
}

# Graphify (needs uv)
if (Test-Command 'uv') {
    Write-Host "Installing Graphify..." -ForegroundColor Yellow
    & uv tool install graphifyy
    if (-not (Test-Command 'graphify')) {
        $uvBin = Join-Path $env:USERPROFILE '.local\bin'
        if (Test-Path $uvBin) { $env:Path = "$uvBin;$env:Path" }
    }
    if (Test-Command 'graphify') {
        & graphify install
        if ($LASTEXITCODE -eq 0) { Add-Result 'graphify' 'Installed' 'then run "/graphify ." in a project' } else { Add-Result 'graphify' 'FAILED' 'graphify install' }
    } else {
        Add-Result 'graphify' 'FAILED' 'installed but not on PATH. Run "uv tool update-shell", open a new window, then "graphify install".'
    }
} else {
    Add-Result 'graphify' 'SKIPPED' 'uv not found. Install uv (docs.astral.sh/uv), then run this script again.'
}

# --- 4. Summary -------------------------------------------------------------
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
foreach ($r in $results) {
    $color = switch -Regex ($r.Status) { '^FAILED' { 'Red' } '^(SKIPPED|WARNING)' { 'Yellow' } default { 'Green' } }
    Write-Host ("{0,-28} {1,-18} {2}" -f $r.Item, $r.Status, $r.Detail) -ForegroundColor $color
}
Write-Host ''
Write-Host "Restart VS Code and the Claude desktop app (or run /reload-plugins in open sessions) to load new plugins." -ForegroundColor Cyan
Write-Host "Impeccable: run '/impeccable init' once in each front-end project." -ForegroundColor Cyan
