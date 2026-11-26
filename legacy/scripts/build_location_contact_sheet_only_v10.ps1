param()

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Host ""
    Write-Host ("ERROR: {0}" -f $Message) -ForegroundColor Red
    exit 1
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"
$ProbeRoot = Join-Path $Upstream "work\english-road-to-batsu-date-location-probe-v2"
$LocationAudit = Join-Path $ProbeRoot "location-audit"
$CataloguePath = Join-Path $LocationAudit "catalogue.json"
$PreviewIndexPath = Join-Path $LocationAudit "catalogue-previews.json"
$ContactSheet = Join-Path $ProbeRoot "location-strips-contact-sheet-v10.png"
$CsvPath = Join-Path $ProbeRoot "location-strip-groups-v10.csv"

Write-Host ""
Write-Host "Justice Gakuen English Project - Location Contact Sheet v10" -ForegroundColor Cyan
Write-Host ""
Write-Host "Reusing successful v7 audit output; no Rust rebuild or ROM scan required."

if (-not (Test-Path $CataloguePath)) {
    Fail "Missing successful v7 catalogue.json."
}
if (-not (Test-Path $PreviewIndexPath)) {
    Fail "Missing successful v7 catalogue-previews.json."
}

$Catalogue = Get-Content -LiteralPath $CataloguePath -Raw | ConvertFrom-Json
$PreviewIndex = Get-Content -LiteralPath $PreviewIndexPath -Raw | ConvertFrom-Json

$PreviewByIndex = @{}
foreach ($Entry in $PreviewIndex.entries) {
    $PreviewByIndex[[int]$Entry.member_index] = [string]$Entry.preview_file
}

$Groups = @{}
foreach ($Member in $Catalogue.members) {
    if ($null -eq $Member.location_block_sha256) { continue }
    $Hash = [string]$Member.location_block_sha256
    if (-not $Groups.ContainsKey($Hash)) {
        $Groups[$Hash] = New-Object System.Collections.ArrayList
    }
    [void]$Groups[$Hash].Add([int]$Member.index)
}

$Hashes = @($Groups.Keys | Sort-Object)
Write-Host ("Distinct location strips: {0}" -f $Hashes.Count)

if ($Hashes.Count -eq 0) {
    Fail "No location strips were found in the audit output."
}

# Stable index map: the visible two-digit number on the sheet maps to this CSV row.
$Rows = New-Object System.Collections.Generic.List[object]
for ($i = 0; $i -lt $Hashes.Count; $i++) {
    $Hash = [string]$Hashes[$i]
    $Members = @($Groups[$Hash] | Sort-Object)
    $Rows.Add([pscustomobject]@{
        sheet_index = ("{0:D2}" -f $i)
        hash = $Hash
        members = ($Members -join ",")
        representative_member = [int]$Members[0]
    })
}
$Rows | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8

Add-Type -AssemblyName System.Drawing

# Hand-drawn 5x7 digit font; avoids Graphics.DrawString entirely.
$DigitPatterns = @{
    "0" = @("11111","10001","10011","10101","11001","10001","11111")
    "1" = @("00100","01100","00100","00100","00100","00100","01110")
    "2" = @("11110","00001","00001","11110","10000","10000","11111")
    "3" = @("11110","00001","00001","01110","00001","00001","11110")
    "4" = @("10010","10010","10010","11111","00010","00010","00010")
    "5" = @("11111","10000","10000","11110","00001","00001","11110")
    "6" = @("01111","10000","10000","11110","10001","10001","01110")
    "7" = @("11111","00001","00010","00100","01000","01000","01000")
    "8" = @("01110","10001","10001","01110","10001","10001","01110")
    "9" = @("01110","10001","10001","01111","00001","00001","11110")
}

function Draw-DigitString {
    param(
        [System.Drawing.Graphics]$Graphics,
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Scale,
        [System.Drawing.Brush]$Brush
    )

    $CursorX = $X
    foreach ($Ch in $Text.ToCharArray()) {
        $Key = [string]$Ch
        if (-not $DigitPatterns.ContainsKey($Key)) {
            $CursorX += 6 * $Scale
            continue
        }

        $Pattern = $DigitPatterns[$Key]
        for ($Row = 0; $Row -lt 7; $Row++) {
            for ($Col = 0; $Col -lt 5; $Col++) {
                if ($Pattern[$Row][$Col] -eq "1") {
                    $Graphics.FillRectangle(
                        $Brush,
                        [int]($CursorX + $Col * $Scale),
                        [int]($Y + $Row * $Scale),
                        [int]$Scale,
                        [int]$Scale
                    )
                }
            }
        }
        $CursorX += 6 * $Scale
    }
}

$CropW = 128
$CropH = 24
$Scale = 3
$IndexScale = 2
$HeaderH = 20
$TileW = $CropW * $Scale
$TileH = $HeaderH + ($CropH * $Scale)
$Columns = 2
$SheetRows = [int][Math]::Ceiling($Hashes.Count / [double]$Columns)
$SheetW = [int]($Columns * $TileW)
$SheetH = [int]($SheetRows * $TileH)

$Sheet = [System.Drawing.Bitmap]::new($SheetW, $SheetH)
$G = [System.Drawing.Graphics]::FromImage($Sheet)
$G.Clear([System.Drawing.Color]::Black)
$G.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$G.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

$WhiteBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
$GrayPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(80,80,80), 1)

try {
    for ($i = 0; $i -lt $Hashes.Count; $i++) {
        $Hash = [string]$Hashes[$i]
        $Members = @($Groups[$Hash] | Sort-Object)
        $Representative = [int]$Members[0]

        if (-not $PreviewByIndex.ContainsKey($Representative)) {
            Fail ("No preview mapping for representative member {0}." -f $Representative)
        }

        $PreviewPath = Join-Path $LocationAudit $PreviewByIndex[$Representative]
        if (-not (Test-Path $PreviewPath)) {
            Fail ("Missing preview PNG: {0}" -f $PreviewPath)
        }

        $Col = [int]($i % $Columns)
        $Row = [int][Math]::Floor($i / [double]$Columns)
        $X = [int]($Col * $TileW)
        $Y = [int]($Row * $TileH)

        # Visible stable sheet index, e.g. 00..83.
        Draw-DigitString `
            -Graphics $G `
            -Text ("{0:D2}" -f $i) `
            -X ($X + 4) `
            -Y ($Y + 3) `
            -Scale $IndexScale `
            -Brush $WhiteBrush

        $Image = [System.Drawing.Image]::FromFile($PreviewPath)
        try {
            if ($Image.Width -lt 128 -or $Image.Height -lt 244) {
                Fail ("Preview member {0} is too small: {1}x{2}" -f $Representative, $Image.Width, $Image.Height)
            }

            $Src = [System.Drawing.Rectangle]::new(0, 220, 128, 24)
            $Dst = [System.Drawing.Rectangle]::new(
                $X,
                $Y + $HeaderH,
                $CropW * $Scale,
                $CropH * $Scale
            )

            $G.DrawImage(
                [System.Drawing.Image]$Image,
                [System.Drawing.Rectangle]$Dst,
                [System.Drawing.Rectangle]$Src,
                [System.Drawing.GraphicsUnit]::Pixel
            )
        }
        finally {
            $Image.Dispose()
        }

        $G.DrawRectangle(
            $GrayPen,
            [int]$X,
            [int]$Y,
            [int]($TileW - 1),
            [int]($TileH - 1)
        )
    }

    $Sheet.Save($ContactSheet, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $GrayPen.Dispose()
    $WhiteBrush.Dispose()
    $G.Dispose()
    $Sheet.Dispose()
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "LOCATION CONTACT SHEET V10 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Contact sheet:" -ForegroundColor Yellow
Write-Host $ContactSheet
Write-Host ""
Write-Host "Index map CSV:" -ForegroundColor Yellow
Write-Host $CsvPath
Write-Host ""
Write-Host "Send me the contact-sheet image. Each strip is labeled 00-83." -ForegroundColor Cyan
