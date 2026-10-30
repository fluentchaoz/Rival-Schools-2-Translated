[CmdletBinding()]
param(
    [string]$SourceBin = "",
    [string]$BuildRoot = "",
    [switch]$Resume,
    [switch]$CheckOnly,
    [switch]$StopAtV16
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function FullPath([string]$Path) {
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}
function Hash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Verify([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing file: $Path" }
    $Actual = Hash $Path
    if ($Actual -ne $Expected) { throw "SHA-256 mismatch: $Path`nExpected: $Expected`nActual:   $Actual" }
}
function WriteText([string]$Path, [string]$Value) {
    [IO.File]::WriteAllText($Path, $Value, (New-Object Text.UTF8Encoding($false)))
}
function NoLinks([string]$Path, [switch]$Recurse) {
    if (Test-Path -LiteralPath $Path) {
        $Items = @(Get-Item -LiteralPath $Path -Force)
        if ($Recurse) { $Items += @(Get-ChildItem -LiteralPath $Path -Recurse -Force) }
        foreach ($Item in $Items) {
            if (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Recovery paths cannot contain junctions or symbolic links: $($Item.FullName)"
            }
        }
    }
}
function SourceStamp([string]$Directory) {
    NoLinks $Directory -Recurse
    $Lines = @(Get-ChildItem -LiteralPath $Directory -Recurse -File | Sort-Object FullName | ForEach-Object {
        $_.FullName.Substring($Directory.Length).Replace('\', '/') + ' ' + (Hash $_.FullName)
    })
    $Bytes = [Text.Encoding]::UTF8.GetBytes(($Lines -join "`n"))
    $Hasher = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($Hasher.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $Hasher.Dispose() }
}
function SaveState {
    WriteText ($StatePath + ".tmp") ($State | ConvertTo-Json -Depth 12)
    Move-Item -LiteralPath ($StatePath + ".tmp") -Destination $StatePath -Force
}
function InvokeLogged([string]$Command, [string[]]$Arguments, [string]$LogName) {
    $LogPath = Join-Path $Logs $LogName
    $PriorPreference = $ErrorActionPreference
    try {
        # Native compiler diagnostics use stderr even on successful builds.
        $ErrorActionPreference = "Continue"
        & $Command @Arguments 2>&1 | Tee-Object -FilePath $LogPath | ForEach-Object { Write-Host $_ }
        $Code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $PriorPreference }
    if ($Code -ne 0) { throw "Command failed with exit code $Code. Log: $LogPath" }
}
function BeginStep([string]$Name) {
    $Snapshot = Join-Path $BuildRoot ("checkpoints/" + $Name + "-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $Snapshot | Out-Null
    NoLinks $Src -Recurse
    Copy-Item -LiteralPath $Src -Destination (Join-Path $Snapshot "src") -Recurse
    $State.active_step = $Name
    $State.checkpoint = $Snapshot
    $State.checkpoint_sha256 = SourceStamp (Join-Path $Snapshot "src")
    SaveState
}
function EndStep {
    $State.source_stamp = SourceStamp $Src
    $State.active_step = ""
    $State.checkpoint = ""
    $State.checkpoint_sha256 = ""
    SaveState
}
function SpaceCheck([int]$Completed) {
    # Retain every predecessor, including the date image reused by v9b.
    # The target directory and Cargo cache are both inside this recovery root.
    $Remaining = [Math]::Max(0, $Plan.stages.Count - $Completed)
    $Required = [long](($Remaining + 3) * $Plan.source_bytes + 8GB)
    $Volume = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($BuildRoot))
    Write-Host ("Recovery drive: {0:N1} GiB free; {1:N1} GiB required." -f ($Volume.AvailableFreeSpace / 1GB), ($Required / 1GB))
    if ($Volume.AvailableFreeSpace -lt $Required) {
        throw "Not enough space for this rebuild. Use -BuildRoot on a drive with at least $([Math]::Ceiling($Required / 1GB)) GiB free."
    }
}

if ($env:OS -ne "Windows_NT") { throw "Run this recovery kit in Windows PowerShell on the PC with the original disc and Arial font." }
$Shell = Join-Path $env:SystemRoot "System32/WindowsPowerShell/v1.0/powershell.exe"
if (-not (Test-Path -LiteralPath $Shell)) { throw "Windows PowerShell was not found: $Shell" }
if (-not $SourceBin) {
    $SourceBin = Join-Path $env:USERPROFILE "Downloads/Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan)/Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin"
}
if (-not $BuildRoot) { $BuildRoot = Join-Path $env:USERPROFILE "JG2-Recovery-v1" }
$SourceBin = FullPath $SourceBin
$BuildRoot = (FullPath $BuildRoot).TrimEnd('\', '/')
$Kit = FullPath $PSScriptRoot
if ($BuildRoot -eq $Kit -or $Kit.StartsWith($BuildRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "BuildRoot must be a separate new folder outside the kit."
}
for ($Ancestor = $BuildRoot; $Ancestor; $Ancestor = Split-Path -Parent $Ancestor) { NoLinks $Ancestor }
$PlanPath = Join-Path $Kit "recovery-plan.json"
$Plan = [IO.File]::ReadAllText($PlanPath) | ConvertFrom-Json
if ($Plan.schema -ne 1) { throw "Unsupported recovery plan version." }
$PlanHash = Hash $PlanPath
foreach ($File in $Plan.files.PSObject.Properties) { Verify (Join-Path $Kit $File.Name) $File.Value }
foreach ($Tool in @("git", "cargo", "rustc", "rustup")) {
    if (-not (Get-Command $Tool -ErrorAction SilentlyContinue)) { throw "$Tool is missing from PATH. Open the terminal used for the earlier builds." }
}
Verify $SourceBin $Plan.source_sha256
if ((Get-Item -LiteralPath $SourceBin).Length -ne $Plan.source_bytes) { throw "Original disc length mismatch." }
$Font = "C:\Windows\Fonts\arial.ttf"
if (-not (Test-Path -LiteralPath $Font)) { throw "The saved builds require the installed font C:\Windows\Fonts\arial.ttf." }
$FontHash = Hash $Font
$StatePath = Join-Path $BuildRoot "recovery-state.json"
$Project = Join-Path $BuildRoot "project"
$Upstream = Join-Path $Project "upstream"
$Src = Join-Path $Upstream "src"
$Logs = Join-Path $BuildRoot "logs"
$Completed = 0

if (Test-Path -LiteralPath $BuildRoot) {
    if (-not $Resume) { throw "Folder already exists: $BuildRoot. Use -Resume for this kit's previous run, or choose a new -BuildRoot." }
    if (-not (Test-Path -LiteralPath $StatePath)) { throw "This is not an initialized recovery folder. Choose a new -BuildRoot." }
    $State = [IO.File]::ReadAllText($StatePath) | ConvertFrom-Json
    if ($State.schema -ne 1 -or $State.build_root -ne $BuildRoot -or $State.plan_sha256 -ne $PlanHash -or $State.font_sha256 -ne $FontHash) {
        throw "Recovery state, kit, folder, or font has changed. Refusing to resume a different build."
    }
    $Completed = [int]$State.completed
    NoLinks $Project -Recurse
    foreach ($File in $Plan.files.PSObject.Properties) { Verify (Join-Path $Project $File.Name) $File.Value }
    if ($Completed -gt 0) {
        $Last = $Plan.stages[$Completed - 1]
        Verify (Join-Path $Upstream $Last.output) $Last.sha256
    }
    if ($State.active_step) {
        $CheckpointRoot = Join-Path $BuildRoot "checkpoints"
        if (-not $State.checkpoint.StartsWith($CheckpointRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Invalid checkpoint path."
        }
        if ((SourceStamp (Join-Path $State.checkpoint "src")) -ne $State.checkpoint_sha256) { throw "Source checkpoint has changed." }
        Write-Host ("Will restore this recovery folder's source checkpoint for interrupted step: " + $State.active_step)
    }
    elseif ($State.prepared -and (SourceStamp $Src) -ne $State.source_stamp) {
        throw "Generated source changed since the last checkpoint. Keep this folder and choose a new -BuildRoot."
    }
}
elseif ($Resume) { throw "No recovery folder exists at $BuildRoot. Omit -Resume for the first run." }
SpaceCheck $Completed
Write-Host "Verified original disc, saved translation inputs, build scripts, font, and free space."
if ($CheckOnly) { Write-Host "Preflight passed. No files changed."; return }

$EnvironmentNames = @("CARGO_INCREMENTAL", "CARGO_HOME", "CARGO_TARGET_DIR", "RUSTUP_TOOLCHAIN", "JUSTICE_RECOVERY_SOURCE_BIN", "JUSTICE_RECOVERY_ROM_FOLDER")
$PreviousEnvironment = @{}
foreach ($Name in $EnvironmentNames) { $PreviousEnvironment[$Name] = [Environment]::GetEnvironmentVariable($Name, "Process") }
try {
    if (-not (Test-Path -LiteralPath $BuildRoot)) {
        New-Item -ItemType Directory -Path $Project -Force | Out-Null
        New-Item -ItemType Directory -Path $Logs | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $BuildRoot "checkpoints") | Out-Null
        foreach ($File in $Plan.files.PSObject.Properties) { Copy-Item -LiteralPath (Join-Path $Kit $File.Name) -Destination (Join-Path $Project $File.Name) }
        $State = [pscustomobject]@{
            schema = 1; build_root = $BuildRoot; plan_sha256 = $PlanHash; font_sha256 = $FontHash
            prepared = $false; completed = 0; source_stamp = ""; active_step = ""; checkpoint = ""; checkpoint_sha256 = ""
            v17h_bin = ""; v17h_sha256 = ""
        }
        SaveState
    }
    $env:CARGO_INCREMENTAL = "0"
    $env:CARGO_HOME = Join-Path $BuildRoot "cargo-cache"
    $env:CARGO_TARGET_DIR = Join-Path $Upstream "target"
    $env:RUSTUP_TOOLCHAIN = $Plan.rust_toolchain
    # rustup reuses an installed toolchain; it never changes the user's default.
    InvokeLogged "rustup" @("toolchain", "install", $Plan.rust_toolchain, "--profile", "minimal", "--no-self-update") "rust-toolchain.log"

    if (-not (Test-Path -LiteralPath $Upstream)) {
        $Clone = Join-Path $Project ("upstream-clone-" + [Guid]::NewGuid().ToString('N'))
        InvokeLogged "git" @("-c", "core.autocrlf=false", "clone", "--no-checkout", "https://github.com/mcpads/justice-gakuen2-kr-patch.git", $Clone) "clone.log"
        InvokeLogged "git" @("-C", $Clone, "checkout", "--detach", $Plan.upstream_commit) "checkout.log"
        Move-Item -LiteralPath $Clone -Destination $Upstream
    }
    $Head = (& git -C $Upstream rev-parse HEAD)
    if ($LASTEXITCODE -ne 0 -or $Head -ne $Plan.upstream_commit) { throw "Recovery upstream commit does not match the pinned revision." }
    if ($State.active_step) {
        NoLinks $Src -Recurse
        Remove-Item -LiteralPath $Src -Recurse -Force
        Copy-Item -LiteralPath (Join-Path $State.checkpoint "src") -Destination $Src -Recurse
        $State.active_step = ""
        $State.checkpoint = ""
        $State.checkpoint_sha256 = ""
        SaveState
    }
    if (-not $State.prepared) {
        BeginStep "prepare"
        InvokeLogged $Shell @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Project "prepare_recovery_source.ps1"), "-Upstream", $Upstream) "prepare-source.log"
        $State.prepared = $true
        EndStep
    }
    $Roms = Join-Path $Upstream "roms"
    New-Item -ItemType Directory -Path $Roms -Force | Out-Null
    $StagedSource = Join-Path $Roms "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin"
    if (-not (Test-Path -LiteralPath $StagedSource)) { Copy-Item -LiteralPath $SourceBin -Destination $StagedSource }
    Verify $StagedSource $Plan.source_sha256
    $Cue = 'FILE "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin" BINARY' + "`r`n  TRACK 01 MODE2/2352`r`n    INDEX 01 00:00:00`r`n"
    WriteText ([IO.Path]::ChangeExtension($StagedSource, ".cue")) $Cue
    $env:JUSTICE_RECOVERY_SOURCE_BIN = $StagedSource
    $env:JUSTICE_RECOVERY_ROM_FOLDER = $Roms
    $Workspace = Join-Path $Project "english-batsu-workspace-bootstrap-v4.zip"

    for ($Index = [int]$State.completed; $Index -lt $Plan.stages.Count; $Index++) {
        $Stage = $Plan.stages[$Index]
        Write-Host ("`n[{0}/{1}] {2}" -f ($Index + 1), $Plan.stages.Count, $Stage.script) -ForegroundColor Cyan
        SpaceCheck $Index
        BeginStep ("stage-{0:D2}" -f ($Index + 1))
        $Arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Project $Stage.script))
        if ($Stage.arguments -eq "workspace") { $Arguments += @("-RomFolder", $Roms, "-WorkspacePackage", $Workspace, "-FontPath", $Font) }
        elseif ($Stage.arguments -eq "font") { $Arguments += @("-FontPath", $Font) }
        $LogName = "stage-{0:D2}-{1}.log" -f ($Index + 1), (Get-Date -Format "yyyyMMdd-HHmmss")
        InvokeLogged $Shell $Arguments $LogName
        $Output = Join-Path $Upstream $Stage.output
        Verify $Output $Stage.sha256
        if ((Get-Item -LiteralPath $Output).Length -ne $Plan.source_bytes) { throw "Stage output disc length mismatch." }
        if (-not (Test-Path -LiteralPath ([IO.Path]::ChangeExtension($Output, ".cue")))) { throw "Stage CUE was not produced." }
        $State.completed = $Index + 1
        EndStep
        Write-Host ("Verified saved build SHA-256: " + $Stage.sha256) -ForegroundColor Green
    }
    $V16 = Join-Path $Upstream $Plan.stages[-1].output
    Verify $V16 $Plan.stages[-1].sha256
    Write-Host ("`nV16 RESTORED: " + [IO.Path]::ChangeExtension($V16, ".cue")) -ForegroundColor Green
    if ($StopAtV16) { return }
    if ($State.v17h_bin) {
        Verify $State.v17h_bin $State.v17h_sha256
    }
    else {
        BeginStep "v17h"
        # A retry gets a new output folder; the v17h builder refuses collisions.
        $CandidateWork = Join-Path $Upstream ("work/english-quiz-fixed-ui-v17h-" + [Guid]::NewGuid().ToString('N'))
        InvokeLogged $Shell @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Project "build_quiz_fixed_ui_english_v17h.ps1"), "-MasterBin", $V16, "-SourceBin", $StagedSource, "-UpstreamRoot", $Upstream, "-WorkRoot", $CandidateWork) ("v17h-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")
        $Candidate = Join-Path $CandidateWork "build/justice-gakuen2-quiz-fixed-ui-v17h.bin"
        $Report = [IO.File]::ReadAllText((Join-Path $CandidateWork "build/quiz-fixed-ui-v17h-report.json")) | ConvertFrom-Json
        Verify $Candidate $Report.output_sha256
        $State.v17h_bin = $Candidate
        $State.v17h_sha256 = Hash $Candidate
        EndStep
    }
    Write-Host ("`nV17H CANDIDATE: " + [IO.Path]::ChangeExtension($State.v17h_bin, ".cue")) -ForegroundColor Green
    Write-Host "Keep v16. Test v17h in DuckStation before treating it as the working build."
}
catch {
    Write-Host ("`nRECOVERY STOPPED: " + $_.Exception.Message) -ForegroundColor Red
    Write-Host ("Logs: " + $Logs)
    Write-Host "Keep the recovery folder. After fixing the reported problem, rerun this command with -Resume."
    throw
}
finally {
    foreach ($Name in $EnvironmentNames) { [Environment]::SetEnvironmentVariable($Name, $PreviousEnvironment[$Name], "Process") }
}
