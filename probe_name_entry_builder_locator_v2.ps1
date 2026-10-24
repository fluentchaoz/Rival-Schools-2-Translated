$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"
$WorkRoot = Join-Path $Upstream "work\english-name-entry-builder-locator-v2"
$ReportPath = Join-Path $WorkRoot "name-entry-builder-locator-v2.txt"

if (-not (Test-Path $Upstream)) {
    throw "Missing upstream folder beside this script."
}

New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null

$Patterns = @(
    "MA_ENT\.BIZ",
    "MGENT\.BIN",
    "name[_-]?entry",
    "composed",
    "compose.*atlas",
    "atlas.*compose",
    "keyboard",
    "dialogue_name_entry",
    "name_entry"
)

$Regex = "(" + ($Patterns -join "|") + ")"

$Roots = @(
    (Join-Path $Upstream "src"),
    (Join-Path $Upstream "tests")
) | Where-Object { Test-Path $_ }

$Files = foreach ($Root in $Roots) {
    Get-ChildItem $Root -Recurse -File -Include *.rs,*.toml,*.md
}

$Matches = @(
    $Files |
    Select-String -Pattern $Regex -CaseSensitive:$false
)

$Lines = New-Object System.Collections.Generic.List[string]
$Lines.Add("Justice Gakuen English Project - NAME ENTRY BUILDER LOCATOR v2")
$Lines.Add("")
$Lines.Add(("Files scanned: {0}" -f $Files.Count))
$Lines.Add(("Matching lines: {0}" -f $Matches.Count))
$Lines.Add("")

$Grouped = $Matches | Group-Object Path | Sort-Object Name

foreach ($Group in $Grouped) {
    $Lines.Add("============================================================")
    $Lines.Add($Group.Name)
    $Lines.Add("============================================================")

    $SourceLines = Get-Content $Group.Name

    $Interesting = @(
        $Group.Group |
        Sort-Object LineNumber |
        Select-Object -Unique LineNumber
    )

    foreach ($M in $Interesting) {
        $LineNo = [int]$M.LineNumber
        $Start = [Math]::Max(1, $LineNo - 3)
        $End = [Math]::Min($SourceLines.Count, $LineNo + 3)

        for ($i = $Start; $i -le $End; $i++) {
            $Prefix = if ($i -eq $LineNo) { ">>" } else { "  " }
            $Lines.Add(("{0} {1,5}: {2}" -f $Prefix, $i, $SourceLines[$i - 1]))
        }
        $Lines.Add("")
    }
}

[System.IO.File]::WriteAllLines(
    $ReportPath,
    $Lines,
    [System.Text.UTF8Encoding]::new($false)
)

$MatchingFileCount = @($Grouped).Count

Write-Host ""
Write-Host "Justice Gakuen English Project - NAME ENTRY BUILDER LOCATOR v2" -ForegroundColor Cyan
Write-Host ""
Write-Host ("Files scanned: {0}" -f $Files.Count)
Write-Host ("Matching source files: {0}" -f $MatchingFileCount)
Write-Host ("Matching lines: {0}" -f $Matches.Count)
Write-Host ""
Write-Host "REPORT WRITTEN:" -ForegroundColor Yellow
Write-Host $ReportPath
Write-Host ""
Write-Host "Upload that TXT here. Nothing was modified." -ForegroundColor Green
