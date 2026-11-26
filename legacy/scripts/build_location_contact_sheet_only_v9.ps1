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
$ContactSheet = Join-Path $ProbeRoot "location-strips-contact-sheet.png"
$GroupsCsv = Join-Path $ProbeRoot "location-strip-groups.csv"

$CataloguePath = Join-Path $LocationAudit "catalogue.json"
$PreviewIndexPath = Join-Path $LocationAudit "catalogue-previews.json"

if (-not (Test-Path $CataloguePath)) {
    Fail "Missing catalogue.json. The successful v7 audit output was not found."
}
if (-not (Test-Path $PreviewIndexPath)) {
    Fail "Missing catalogue-previews.json. The successful v7 audit output was not found."
}

Write-Host "Justice Gakuen English Project - Location Contact Sheet Fix v9" -ForegroundColor Cyan
Write-Host ""
Write-Host "Reusing successful v7 audit output; no Rust rebuild or ROM scan required." -ForegroundColor Green

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
if ($Hashes.Count -eq 0) {
    Fail "No location-strip hashes were found in catalogue.json."
}

Write-Host ("Distinct location strips: {0}" -f $Hashes.Count)
Write-Host ""

# Also emit a plain CSV so the member grouping survives independently of image rendering.
$RowsForCsv = foreach ($Hash in $Hashes) {
    $Members = @($Groups[$Hash] | Sort-Object)
    [pscustomobject]@{
        hash = $Hash
        representative_member = [int]$Members[0]
        member_count = [int]$Members.Count
        members = ($Members -join ",")
    }
}
$RowsForCsv | Export-Csv -LiteralPath $GroupsCsv -NoTypeInformation -Encoding UTF8

Add-Type -AssemblyName System.Drawing

[int]$Scale = 3
[int]$CropW = 128
[int]$CropH = 24
[int]$LabelH = 38
[int]$TileW = $CropW * $Scale
[int]$TileH = ($CropH * $Scale) + $LabelH
[int]$Columns = 2
[int]$Rows = [int][Math]::Ceiling($Hashes.Count / [double]$Columns)
[int]$SheetW = $Columns * $TileW
[int]$SheetH = $Rows * $TileH

# Use explicit .NET constructors and explicit Int32 values throughout.
$Sheet = [System.Drawing.Bitmap]::new(
    [int]$SheetW,
    [int]$SheetH,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
$G = [System.Drawing.Graphics]::FromImage($Sheet)
$G.Clear([System.Drawing.Color]::Black)
$G.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$G.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$G.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy

$Font = [System.Drawing.Font]::new(
    "Consolas",
    [single]9.0,
    [System.Drawing.FontStyle]::Regular,
    [System.Drawing.GraphicsUnit]::Point
)
$Brush = [System.Drawing.Brushes]::White

try {
    for ([int]$i = 0; $i -lt $Hashes.Count; $i++) {
        [string]$Hash = [string]$Hashes[$i]
        [int[]]$Members = @($Groups[$Hash] | Sort-Object | ForEach-Object { [int]$_ })
        if ($Members.Count -eq 0) { continue }

        [int]$Representative = $Members[0]
        if (-not $PreviewByIndex.ContainsKey($Representative)) {
            Write-Warning ("No preview mapping for representative member {0}" -f $Representative)
            continue
        }

        [string]$PreviewRelative = [string]$PreviewByIndex[$Representative]
        [string]$PreviewPath = Join-Path $LocationAudit $PreviewRelative
        if (-not (Test-Path $PreviewPath)) {
            Write-Warning ("Missing preview: {0}" -f $PreviewPath)
            continue
        }

        $Image = [System.Drawing.Image]::FromFile($PreviewPath)
        try {
            if ($Image.Width -lt 128 -or $Image.Height -lt 244) {
                Write-Warning ("Preview {0} is only {1}x{2}" -f $Representative, $Image.Width, $Image.Height)
                continue
            }

            [int]$Col = $i % $Columns
            [int]$Row = [int][Math]::Floor($i / [double]$Columns)
            [int]$X = $Col * $TileW
            [int]$Y = $Row * $TileH

            [string]$Label = "hash {0}  members {1}" -f `
                $Hash.Substring(0, 8), `
                ($Members -join ",")

            $LabelPoint = [System.Drawing.PointF]::new(
                [single]($X + 2),
                [single]($Y + 2)
            )
            $LabelFormat = [System.Drawing.StringFormat]::GenericTypographic.Clone()
            try {
                $G.DrawString(
                    [string]$Label,
                    [System.Drawing.Font]$Font,
                    [System.Drawing.Brush]$Brush,
                    [System.Drawing.PointF]$LabelPoint,
                    [System.Drawing.StringFormat]$LabelFormat
                )
            }
            finally {
                $LabelFormat.Dispose()
            }

            $Src = [System.Drawing.Rectangle]::new(
                [int]0,
                [int]220,
                [int]128,
                [int]24
            )
            $Dst = [System.Drawing.Rectangle]::new(
                [int]$X,
                [int]($Y + $LabelH),
                [int]($CropW * $Scale),
                [int]($CropH * $Scale)
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
    }

    $Sheet.Save(
        $ContactSheet,
        [System.Drawing.Imaging.ImageFormat]::Png
    )
}
finally {
    $Font.Dispose()
    $G.Dispose()
    $Sheet.Dispose()
}

if (-not (Test-Path $ContactSheet)) {
    Fail "Contact-sheet PNG was not written."
}

Write-Host "============================================================" -ForegroundColor Green
Write-Host "LOCATION CONTACT SHEET COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Contact sheet:" -ForegroundColor Yellow
Write-Host $ContactSheet
Write-Host ""
Write-Host "Hash/member CSV:" -ForegroundColor Yellow
Write-Host $GroupsCsv
Write-Host ""
Write-Host "Send me the contact-sheet image. We do not need to rerun the audit." -ForegroundColor Cyan
