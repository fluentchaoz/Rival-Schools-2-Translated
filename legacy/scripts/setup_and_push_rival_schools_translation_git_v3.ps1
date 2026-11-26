$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Fail([string]$Message) {
    Write-Host ""
    Write-Host ("ERROR: {0}" -f $Message) -ForegroundColor Red
    exit 1
}

function Invoke-Git {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$GitArgs,
        [switch]$AllowFailure
    )

    & git -C $ProjectRoot @GitArgs
    $Code = $LASTEXITCODE

    if ($Code -ne 0 -and -not $AllowFailure) {
        throw ("git {0} failed with exit code {1}" -f ($GitArgs -join " "), $Code)
    }

    return $Code
}

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RemoteUrl = "https://github.com/fluentchaoz/Rival-Schools-2-Translated.git"
$KnownGoodSha = "2fe51561d025cc2ffdface62d1a7e7222a40937bb3b5a97ebc019f8338d43977"

Write-Host ""
Write-Host "Rival Schools 2 Translated - LOCAL + GITHUB SETUP v3" -ForegroundColor Cyan
Write-Host "Project root: $ProjectRoot"
Write-Host "GitHub repo:  fluentchaoz/Rival-Schools-2-Translated"
Write-Host ""

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "Git is not installed or is not on PATH."
}

Write-Host (& git --version) -ForegroundColor Green

# ---------------------------------------------------------------------------
# 1. Initialize / repair branch state.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[1/8] Checking local Git repository..." -ForegroundColor Cyan

if (-not (Test-Path (Join-Path $ProjectRoot ".git"))) {
    & git -C $ProjectRoot init
    if ($LASTEXITCODE -ne 0) { Fail "git init failed." }
    Write-Host "Initialized new local repository." -ForegroundColor Green
}
else {
    Write-Host "Existing local repository found." -ForegroundColor Green
}

# Determine whether this repository is still unborn without intentionally
# running a Git command that exits nonzero. `git status --porcelain=2 --branch`
# succeeds for both normal and empty repositories and reports "(initial)"
# for an unborn branch.
$BranchStatus = @(& git -C $ProjectRoot status --porcelain=2 --branch 2>$null)
if ($LASTEXITCODE -ne 0) {
    Fail "Could not read local Git branch status."
}

$IsInitial = $false
foreach ($Line in $BranchStatus) {
    if ($Line -match '^# branch\.oid \(initial\)$') {
        $IsInitial = $true
        break
    }
}

if ($IsInitial) {
    Invoke-Git -GitArgs @("symbolic-ref", "HEAD", "refs/heads/main") | Out-Null
    Write-Host "Empty repository prepared on unborn main branch." -ForegroundColor Green
}
else {
    Invoke-Git -GitArgs @("branch", "-M", "main") | Out-Null
    Write-Host "Existing branch normalized to main." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 2. Safety files.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[2/8] Installing ROM-safe Git ignore rules..." -ForegroundColor Cyan

$GitIgnore = @'
# ---------------------------------------------------------------------------
# Rival Schools 2 Translated
# Project source/scripts only. Do NOT commit copyrighted disc images/assets.
# ---------------------------------------------------------------------------

# External pinned reverse-engineering repository
upstream/

# Disc / ROM / converted images
*.bin
*.cue
*.iso
*.img
*.chd
*.pbp
*.mdf
*.mds

# Emulator memory cards / saves / states
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

# Generated build output
target/
**/target/
work/
**/work/
previews/
**/previews/

# Common temporary output
*.tmp
*.bak
*.log
*.orig
*.rej
Thumbs.db
.DS_Store

# PowerShell editor backups
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
# 3. README + milestone docs.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[3/8] Writing project documentation..." -ForegroundColor Cyan

$Readme = @'
# Rival Schools 2 Translated

English fan-translation / reverse-engineering project for the Japanese PlayStation
release of **Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2** (`SLPS-02120`).

## Status

Current live-tested working milestone: **Name-entry UI v5**

Known-good rebuilt-disc SHA-256:

`2fe51561d025cc2ffdface62d1a7e7222a40937bb3b5a97ebc019f8338d43977`

### Confirmed English work so far

- Main mode-select graphics
- School Life `PLAY / LOAD` title UI
- English dialogue glyph support
- Batsu-route prototype work
- Status HUD (`ATK / DEF / STAM / GUTS / POT / INT`)
- MGK04 opening greeting
- `SCHOOL GATE` opening location
- Dynamic English date (`4/1 THU`)
- Full MGK04 tutorial/admissions dialogue layer
- Enrollment/application form
- Name-entry controls (`HIRA / KATA / A-Z / DEL / NEXT / BACK / OK`)
- Native `0-9 / A-Z / a-z` keyboard preserved and verified in-game

## Development philosophy

Changes are built as isolated, source-verified layers. Each successful build is
identified by SHA-256 and tested in-game before becoming the next working master.

## Upstream tooling

Reverse-engineering/build tooling is based on:

`mcpads/justice-gakuen2-kr-patch`

Pinned upstream commit:

`98ca12ddf082d6e2367b2963f76edf5a09242deb`

The local `upstream/` checkout is intentionally not committed here.

## Copyright / repository contents

This repository is for translation code, build/probe scripts, documentation,
checksums, and original project work.

**No ROM/disc image, BIOS, rebuilt BIN/CUE, or copyrighted game asset is included.**
You must supply your own legally obtained game data when using the tooling.
'@

[System.IO.File]::WriteAllText(
    (Join-Path $ProjectRoot "README.md"),
    $Readme.TrimStart() + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

$Milestone = @"
# Current Known-Good Milestone

## Name-entry UI v5

Live-tested rebuilt-disc SHA-256:

```
$KnownGoodSha
```

Local working CUE (not tracked by Git):

```
upstream\work\english-name-entry-ui-v5\build\justice-gakuen2-name-entry-ui-v5.cue
```

### Confirmed behavior

- English enrollment form renders correctly in-game.
- Native name-entry controls render as HIRA / KATA / A-Z / DEL / NEXT / BACK / OK.
- Original control colors remain correct.
- A-Z page displays 0-9 / A-Z / a-z correctly.
- Keyboard navigation and cursor highlighting work.
- MGENT.BIN was unchanged by v5.
- Only MA_ENT.BIZ fixed graphics/control sprites were changed for v5.

### Next target

Patch only the name-entry page initialization behavior so the native A-Z page
opens by default for English name entry.

Do not promote a later build over this milestone until it is verified in-game.
"@

[System.IO.File]::WriteAllText(
    (Join-Path $ProjectRoot "CURRENT_MILESTONE.md"),
    $Milestone.TrimStart() + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

# ---------------------------------------------------------------------------
# 4. Commit identity.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[4/8] Checking Git commit identity..." -ForegroundColor Cyan

$Name = (& git -C $ProjectRoot config user.name 2>$null)
$Email = (& git -C $ProjectRoot config user.email 2>$null)

if (-not $Name) {
    $Name = Read-Host "Enter the name or handle you want shown on Git commits"
    if ([string]::IsNullOrWhiteSpace($Name)) { Fail "Commit name cannot be blank." }
    Invoke-Git -GitArgs @("config", "--local", "user.name", $Name) | Out-Null
}

if (-not $Email) {
    $Email = Read-Host "Enter the email you want shown on Git commits"
    if ([string]::IsNullOrWhiteSpace($Email)) { Fail "Commit email cannot be blank." }
    Invoke-Git -GitArgs @("config", "--local", "user.email", $Email) | Out-Null
}

Write-Host (
    "Commit identity: {0} <{1}>" -f
    (& git -C $ProjectRoot config user.name),
    (& git -C $ProjectRoot config user.email)
) -ForegroundColor Green

# ---------------------------------------------------------------------------
# 5. Stage only known-safe root project material.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[5/8] Staging safe project files..." -ForegroundColor Cyan

$SafeFixed = @(
    ".gitignore",
    ".gitattributes",
    "README.md",
    "CURRENT_MILESTONE.md",
    "ENGLISH_PROJECT.md"
)

foreach ($FileName in $SafeFixed) {
    $Path = Join-Path $ProjectRoot $FileName
    if (Test-Path $Path) {
        Invoke-Git -GitArgs @("add", "--", $FileName) | Out-Null
    }
}

$Scripts = @(Get-ChildItem $ProjectRoot -File -Filter "*.ps1" | Sort-Object Name)
foreach ($ScriptFile in $Scripts) {
    Invoke-Git -GitArgs @("add", "--", $ScriptFile.Name) | Out-Null
}

Write-Host ("Staged root documentation + {0} PowerShell script(s)." -f $Scripts.Count)

$Staged = @(& git -C $ProjectRoot diff --cached --name-only)
$ForbiddenExt = @(".bin", ".cue", ".iso", ".img", ".chd", ".pbp", ".mdf", ".mds")
$Bad = @(
    $Staged | Where-Object {
        $Ext = [System.IO.Path]::GetExtension($_).ToLowerInvariant()
        ($ForbiddenExt -contains $Ext) -or ($_ -match '^(upstream/|upstream\\)')
    }
)

if ($Bad.Count -gt 0) {
    Write-Host ""
    Write-Host "REFUSING TO COMMIT PROHIBITED FILES:" -ForegroundColor Red
    $Bad | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Fail "Safety check failed."
}

Write-Host "Safety check passed: no ROM/disc/upstream files are staged." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 6. Commit checkpoint + tag.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[6/8] Creating the known-good checkpoint commit..." -ForegroundColor Cyan

$Cached = @(& git -C $ProjectRoot diff --cached --name-only)
if ($Cached.Count -gt 0) {
    Invoke-Git -GitArgs @("commit", "-m", "English translation through name-entry UI v5") | Out-Null
}
else {
    Write-Host "No new staged changes; existing commit will be used." -ForegroundColor Yellow
}

$TagExists = (& git -C $ProjectRoot tag --list "name-entry-v5")
if (-not $TagExists) {
    Invoke-Git -GitArgs @(
        "tag",
        "-a",
        "name-entry-v5",
        "-m",
        "Known-good live-tested name-entry UI v5; rebuilt-disc SHA-256 $KnownGoodSha"
    ) | Out-Null
    Write-Host "Created tag name-entry-v5." -ForegroundColor Green
}
else {
    Write-Host "Tag name-entry-v5 already exists." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 7. Attach the exact GitHub repository.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[7/8] Connecting GitHub remote..." -ForegroundColor Cyan

$RemoteNames = @(& git -C $ProjectRoot remote)
if ($LASTEXITCODE -ne 0) {
    Fail "Could not read Git remotes."
}

$HasOrigin = $RemoteNames -contains "origin"
$Origin = $null
if ($HasOrigin) {
    $Origin = (& git -C $ProjectRoot remote get-url origin)
    if ($LASTEXITCODE -ne 0) {
        Fail "Could not read existing origin URL."
    }
}

if ($HasOrigin -and $Origin) {
    if ($Origin -ne $RemoteUrl) {
        Write-Host ("Existing origin was: {0}" -f $Origin) -ForegroundColor Yellow
        Invoke-Git -GitArgs @("remote", "set-url", "origin", $RemoteUrl) | Out-Null
        Write-Host ("origin updated to: {0}" -f $RemoteUrl) -ForegroundColor Green
    }
    else {
        Write-Host "origin already points to the correct repository." -ForegroundColor Green
    }
}
else {
    Invoke-Git -GitArgs @("remote", "add", "origin", $RemoteUrl) | Out-Null
    Write-Host ("origin added: {0}" -f $RemoteUrl) -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 8. Push.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[8/8] Pushing main + milestone tag to GitHub..." -ForegroundColor Cyan
Write-Host "Git Credential Manager may open a browser the first time." -ForegroundColor Yellow
Write-Host ""

try {
    Invoke-Git -GitArgs @("push", "-u", "origin", "main") | Out-Null
    Invoke-Git -GitArgs @("push", "origin", "name-entry-v5") | Out-Null
}
catch {
    Write-Host ""
    Write-Host "LOCAL GIT CHECKPOINT IS SAFE, BUT THE GITHUB PUSH FAILED." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Nothing was lost. Paste this output; only the push/authentication step needs repair." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "GITHUB BACKUP COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Latest commit:" -ForegroundColor Yellow
& git -C $ProjectRoot --no-pager log -1 --oneline

Write-Host ""
Write-Host "Remote:" -ForegroundColor Yellow
& git -C $ProjectRoot remote -v

Write-Host ""
Write-Host "Tag:" -ForegroundColor Yellow
& git -C $ProjectRoot tag --list "name-entry-v5"

Write-Host ""
Write-Host "Status:" -ForegroundColor Yellow
& git -C $ProjectRoot status --short

Write-Host ""
Write-Host "GitHub:" -ForegroundColor Cyan
Write-Host "https://github.com/fluentchaoz/Rival-Schools-2-Translated"
Write-Host ""
Write-Host "Reminder: this GitHub repository is currently PUBLIC." -ForegroundColor Yellow
