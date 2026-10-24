$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"

if (-not (Test-Path $Upstream)) {
    throw "Missing upstream folder beside this script."
}

Write-Host ""
Write-Host "Justice Gakuen English Project - NAME ENTRY BUILDER LOCATOR v1" -ForegroundColor Cyan
Write-Host ""

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

Write-Host ("Files scanned: {0}" -f $Files.Count)
Write-Host ("Matching lines: {0}" -f $Matches.Count)
Write-Host ""

$Grouped = $Matches | Group-Object Path | Sort-Object Name

foreach ($Group in $Grouped) {
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host $Group.Name -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor DarkGray

    $SourceLines = Get-Content $Group.Name

    $Interesting = @(
        $Group.Group |
        Sort-Object LineNumber |
        Select-Object -Unique LineNumber
    )

    foreach ($M in $Interesting) {
        $LineNo = [int]$M.LineNumber
        $Start = [Math]::Max(1, $LineNo - 2)
        $End = [Math]::Min($SourceLines.Count, $LineNo + 2)

        for ($i = $Start; $i -le $End; $i++) {
            $Prefix = if ($i -eq $LineNo) { ">>" } else { "  " }
            Write-Host ("{0} {1,5}: {2}" -f $Prefix, $i, $SourceLines[$i - 1])
        }
        Write-Host ""
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "NAME ENTRY BUILDER LOCATOR COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Nothing was modified." -ForegroundColor Green
