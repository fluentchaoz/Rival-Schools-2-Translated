$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Fail([string]$Message) {
    Write-Host ""
    Write-Host ("ERROR: {0}" -f $Message) -ForegroundColor Red
    exit 1
}

function Git([string[]]$Args) {
    & git -C $ProjectRoot @Args
    if ($LASTEXITCODE -ne 0) {
        throw ("git {0} failed with exit code {1}" -f ($Args -join " "), $LASTEXITCODE)
    }
}

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $ProjectRoot "upstream"

Write-Host ""
Write-Host "Justice Gakuen English Project - GIT SETUP v1" -ForegroundColor Cyan
Write-Host "Project root: $ProjectRoot"
Write-Host ""

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "Git is not installed or is not on PATH. Install Git for Windows, then rerun this script."
}

$GitVersion = (& git --version)
Write-Host $GitVersion -ForegroundColor Green

if (-not (Test-Path $Upstream)) {
    Write-Host "WARNING: upstream folder was not found. Continuing anyway." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 1. Initialize OUR repo at the project root.
#    upstream/ is intentionally excluded because it is its own pinned repo.
# ---------------------------------------------------------------------------
if (-not (Test-Path (Join-Path $ProjectRoot ".git"))) {
    Write-Host ""
    Write-Host "[1/6] Initializing local Git repository..." -ForegroundColor Cyan
    & git -C $ProjectRoot init
    if ($LASTEXITCODE -ne 0) { Fail "git init failed." }
    Git @("branch", "-M", "main")
}
else {
    Write-Host ""
    Write-Host "[1/6] Existing project-root Git repository found." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 2. Safe ignore rules.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[2/6] Writing safety-focused .gitignore..." -ForegroundColor Cyan

$GitIgnore = @'
# ---------------------------------------------------------------------------
# Justice Gakuen English Project
# Never commit copyrighted disc images, generated builds, or the upstream clone.
# ---------------------------------------------------------------------------

# Pinned external source repository (kept separately)
upstream/

# PS1 / disc images and converted images
*.bin
*.cue
*.iso
*.img
*.chd
*.pbp
*.mdf
*.mds

# Emulator memory cards / save states
*.mcr
*.srm
*.sav
*.state
*.sst
*.st0
*.st1
*.st2
*.st3
*.st4
*.st5
*.st6
*.st7
*.st8
*.st9

# Rust / generated build output
target/
**/target/
work/
**/work/

# Generated previews / scratch output
previews/
**/previews/

# Temporary / editor / log files
*.tmp
*.bak
*.log
*.orig
*.rej
Thumbs.db
.DS_Store

# PowerShell transient files
*.ps1~
'@

[System.IO.File]::WriteAllText(
    (Join-Path $ProjectRoot ".gitignore"),
    $GitIgnore.TrimStart() + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

$GitAttributes = @'
* text=auto
*.ps1 text eol=crlf
*.md text eol=lf
*.txt text eol=lf
*.json text eol=lf
'@

[System.IO.File]::WriteAllText(
    (Join-Path $ProjectRoot ".gitattributes"),
    $GitAttributes.TrimStart() + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

# ---------------------------------------------------------------------------
# 3. Project documentation for the current known-good checkpoint.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[3/6] Recording current known-good milestone..." -ForegroundColor Cyan

$ProjectDoc = @'
# Justice Gakuen 2 English Translation Project

English fan-translation / reverse-engineering work for:

**Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan)**  
Game ID: `SLPS-02120`

This repository tracks only original project work such as PowerShell build/probe
scripts, translation notes, checksums, and patch-development documentation.

It intentionally does **not** contain ROM/disc images, BIOS files, copyrighted
game assets, generated rebuilt BIN/CUE images, or the external upstream source
checkout.

## Upstream

Reverse-engineering/build tooling is based on:

`mcpads/justice-gakuen2-kr-patch`

Pinned upstream commit:

`98ca12ddf082d6e2367b2963f76edf5a09242deb`

The upstream checkout lives in `upstream/` locally and is intentionally ignored
by this repository.

## Workflow

1. Keep known-good builds identified by SHA-256.
2. Make one isolated subsystem change at a time.
3. Verify source identity before patching.
4. Verify readback and changed-sector scope after patching.
5. Test the result in-game before promoting it to the next working master.
6. Commit successful project scripts/notes to Git.
'@

[System.IO.File]::WriteAllText(
    (Join-Path $ProjectRoot "ENGLISH_PROJECT.md"),
    $ProjectDoc.TrimStart() + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

$Milestone = @'
# Current Known-Good Milestone

## Name-entry UI v5

Live-tested working master:

`2fe51561d025cc2ffdface62d1a7e7222a40937bb3b5a97ebc019f8338d43977`

Local test CUE:

`upstream\work\english-name-entry-ui-v5\build\justice-gakuen2-name-entry-ui-v5.cue`

The rebuilt BIN/CUE are **not** tracked by Git.

### Confirmed working English layers

- English main mode-select graphics
- English School Life title (`PLAY`, `LOAD`)
- English dialogue glyph injection
- playable Batsu route prototype
- status HUD (`ATK / DEF / STAM / GUTS / POT / INT`)
- English MGK04 opening greeting
- `SCHOOL GATE` opening location
- dynamic English date format (`4/1 THU`)
- full MGK04 tutorial/admissions dialogue translation
- English enrollment form
- native name-entry alphanumeric keyboard preserved
- English name-entry controls:
  - `HIRA`
  - `KATA`
  - `A-Z`
  - `DEL`
  - `NEXT`
  - `BACK`
  - `OK`

### Next target

Make the native `A-Z` keyboard page the initial/default page for English name
entry using a narrowly verified `MGENT.BIN` behavior patch.
'@

[System.IO.File]::WriteAllText(
    (Join-Path $ProjectRoot "CURRENT_MILESTONE.md"),
    $Milestone.TrimStart() + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

# ---------------------------------------------------------------------------
# 4. Stage ONLY our project material.
#    Do not use "git add ." here: being explicit is safer for a ROM project.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[4/6] Staging safe project files..." -ForegroundColor Cyan

Git @("add", "--", ".gitignore", ".gitattributes", "ENGLISH_PROJECT.md", "CURRENT_MILESTONE.md")

$Scripts = @(Get-ChildItem $ProjectRoot -File -Filter "*.ps1" | Sort-Object Name)
foreach ($Script in $Scripts) {
    Git @("add", "--", $Script.Name)
}

Write-Host ("Staged {0} root-level PowerShell script(s)." -f $Scripts.Count)

# Safety check: refuse to continue if a prohibited file somehow became staged.
$Staged = @(& git -C $ProjectRoot diff --cached --name-only)
$BadExtensions = @(".bin", ".cue", ".iso", ".img", ".chd", ".pbp", ".mdf", ".mds")
$Bad = @(
    $Staged | Where-Object {
        $Ext = [System.IO.Path]::GetExtension($_).ToLowerInvariant()
        $BadExtensions -contains $Ext -or $_ -match '^(upstream/|upstream\\)'
    }
)

if ($Bad.Count -gt 0) {
    Write-Host ""
    Write-Host "REFUSING TO COMMIT THESE FILES:" -ForegroundColor Red
    $Bad | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Fail "A prohibited ROM/build/upstream file was staged."
}

# ---------------------------------------------------------------------------
# 5. Configure commit identity LOCALLY if needed.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[5/6] Checking Git commit identity..." -ForegroundColor Cyan

$Name = (& git -C $ProjectRoot config --local user.name 2>$null)
if (-not $Name) {
    $Name = (& git config --global user.name 2>$null)
}
$Email = (& git -C $ProjectRoot config --local user.email 2>$null)
if (-not $Email) {
    $Email = (& git config --global user.email 2>$null)
}

if (-not $Name) {
    $Name = Read-Host "Git needs a name for commit history. Enter the name/handle you want shown"
    if ([string]::IsNullOrWhiteSpace($Name)) { Fail "Commit name cannot be blank." }
    Git @("config", "--local", "user.name", $Name)
}

if (-not $Email) {
    $Email = Read-Host "Git needs an email for commit history. Enter the email you want associated with LOCAL commits"
    if ([string]::IsNullOrWhiteSpace($Email)) { Fail "Commit email cannot be blank." }
    Git @("config", "--local", "user.email", $Email)
}

$EffectiveName = (& git -C $ProjectRoot config user.name)
$EffectiveEmail = (& git -C $ProjectRoot config user.email)
Write-Host ("Commit identity: {0} <{1}>" -f $EffectiveName, $EffectiveEmail) -ForegroundColor Green

# ---------------------------------------------------------------------------
# 6. Commit + tag the proven v5 checkpoint.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[6/6] Creating first project checkpoint..." -ForegroundColor Cyan

$HasHead = $true
& git -C $ProjectRoot rev-parse --verify HEAD *> $null
if ($LASTEXITCODE -ne 0) { $HasHead = $false }

$CachedNames = @(& git -C $ProjectRoot diff --cached --name-only)
if ($CachedNames.Count -gt 0) {
    Git @(
        "commit",
        "-m",
        "English translation through name-entry UI v5"
    )
}
else {
    Write-Host "Nothing new is staged; no commit needed." -ForegroundColor Yellow
}

# Create the milestone tag if it does not already exist.
$ExistingTag = (& git -C $ProjectRoot tag --list "name-entry-v5")
if (-not $ExistingTag) {
    Git @(
        "tag",
        "-a",
        "name-entry-v5",
        "-m",
        "Known-good live-tested name-entry UI v5; master SHA-256 2fe51561d025cc2ffdface62d1a7e7222a40937bb3b5a97ebc019f8338d43977"
    )
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "LOCAL GIT CHECKPOINT CREATED" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Latest commit:" -ForegroundColor Yellow
& git -C $ProjectRoot --no-pager log -1 --oneline

Write-Host ""
Write-Host "Milestone tag:" -ForegroundColor Yellow
& git -C $ProjectRoot tag --list "name-entry-v5"

Write-Host ""
Write-Host "Repository status:" -ForegroundColor Yellow
& git -C $ProjectRoot status --short

Write-Host ""
Write-Host "IMPORTANT:" -ForegroundColor Cyan
Write-Host "This is now safely versioned on YOUR COMPUTER." 
Write-Host "Nothing has been uploaded to GitHub yet."
Write-Host ""
Write-Host "Next, after you paste this output, we can connect this local repo to a private or public GitHub repository."
