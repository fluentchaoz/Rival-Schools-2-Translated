[CmdletBinding()]
param([string]$MasterBin = "", [string]$OutputRoot = "")
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$Packet = $PSScriptRoot
$Manifest = Get-Content -LiteralPath (Join-Path $Packet "manifest.json") -Raw | ConvertFrom-Json
function FileHash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
if (-not $MasterBin) {
    foreach ($Folder in @($Packet, (Split-Path -Parent $Packet), (Join-Path $env:USERPROFILE "Downloads"))) {
        foreach ($Subfolder in @($Folder, (Join-Path $Folder "menu-fixes-v31"), (Join-Path $Folder "practice-v30"))) {
            foreach ($Filename in @("justice-gakuen2-menu-fixes-v31.bin", "justice-gakuen2-practice-v30.bin", "justice-gakuen2-boot-notice-v29.bin")) {
                $Candidate = Join-Path $Subfolder $Filename
                if ((-not $MasterBin) -and (Test-Path -LiteralPath $Candidate -PathType Leaf)) { $MasterBin = $Candidate }
            }
        }
    }
}
if (-not $MasterBin) { throw 'Put this extracted updater beside your v31, v30 or v29 BIN, or pass -MasterBin with its full path. Extract any ROM archive first.' }
$MasterBin = (Resolve-Path -LiteralPath $MasterBin).Path
$SourceHash = FileHash $MasterBin
$InputMatches = @($Manifest.inputs | Where-Object { $_.master_sha256 -eq $SourceHash })
if ((Get-Item -LiteralPath $MasterBin).Length -ne 663216960 -or $InputMatches.Count -ne 1) { throw "Select the exact recovered v29, v30 or v31 BIN. No output created." }
$InputSpec = $InputMatches[0]
$PatchPath = Join-Path $Packet $InputSpec.patch_file
if ((FileHash $PatchPath) -ne $InputSpec.patch_sha256) { throw "Patch identity mismatch. No output created." }
# Validate the whole patch before copying the source image.
$Patch = [IO.File]::OpenRead($PatchPath)
try {
    $Reader = [IO.BinaryReader]::new($Patch)
    if ([Text.Encoding]::ASCII.GetString($Reader.ReadBytes(8)) -ne "JG2V32`0`0") { throw "Invalid patch header" }
    $Count = $Reader.ReadUInt32()
    if ($Count -ne $InputSpec.changed_sector_count -or $Patch.Length -ne (12 + [long]$Count * 2356)) { throw "Invalid patch length/count" }
    [long]$Last = -1
    for ($i = 0; $i -lt $Count; $i++) {
        [long]$Lba = $Reader.ReadUInt32()
        if ($Lba -le $Last -or ($Lba + 1) * 2352 -gt 663216960) { throw "Invalid sector index" }
        [void]$Patch.Seek(2352, [IO.SeekOrigin]::Current)
        $Last = $Lba
    }
} finally { $Patch.Dispose() }
if (-not $OutputRoot) { $OutputRoot = Join-Path $Packet "title-exam-v32" }
$OutputRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputRoot)
if (Test-Path -LiteralPath $OutputRoot) { throw "Output folder already exists: $OutputRoot. Choose a new -OutputRoot; existing work will not be overwritten." }
$Drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($OutputRoot))
if ($Drive.AvailableFreeSpace -lt 700MB) { throw "At least 700 MB of free space is required." }
[void][IO.Directory]::CreateDirectory($OutputRoot)
$OutputBin = Join-Path $OutputRoot "justice-gakuen2-title-exam-v32.bin"
Write-Host "Creating v32. Your input remains unchanged..." -ForegroundColor Cyan
$Source = [IO.File]::OpenRead($MasterBin)
try {
    $Output = [IO.File]::Open($OutputBin, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    try { $Source.CopyTo($Output) } finally { $Output.Dispose() }
} finally { $Source.Dispose() }
$Patch = [IO.File]::OpenRead($PatchPath)
$Output = [IO.File]::Open($OutputBin, [IO.FileMode]::Open, [IO.FileAccess]::Write)
try {
    $Reader = [IO.BinaryReader]::new($Patch)
    [void]$Patch.Seek(12, [IO.SeekOrigin]::Begin)
    for ($i = 0; $i -lt $Count; $i++) {
        [long]$Lba = $Reader.ReadUInt32()
        $Sector = $Reader.ReadBytes(2352)
        if ($Sector.Length -ne 2352) { throw "Truncated patch" }
        [void]$Output.Seek($Lba * 2352, [IO.SeekOrigin]::Begin)
        $Output.Write($Sector, 0, 2352)
    }
} finally { $Output.Dispose(); $Patch.Dispose() }
if ((Get-Item -LiteralPath $OutputBin).Length -ne 663216960 -or (FileHash $OutputBin) -ne $Manifest.output_sha256) { throw "Final verification failed. Do not boot this output." }
$Cue = Join-Path $OutputRoot "justice-gakuen2-title-exam-v32.cue"
$CueText = "FILE `"justice-gakuen2-title-exam-v32.bin`" BINARY`r`n  TRACK 01 MODE2/2352`r`n    INDEX 01 00:00:00`r`n"
[IO.File]::WriteAllText($Cue, $CueText, [Text.UTF8Encoding]::new($false))
Write-Host "V32 VERIFIED" -ForegroundColor Green
Write-Host ("SHA256: " + $Manifest.output_sha256)
Write-Host ("CUE TO BOOT: " + $Cue) -ForegroundColor Yellow
Write-Host "Fresh-boot this CUE, then load an in-game save. Keep your earlier discs and existing memory cards."
