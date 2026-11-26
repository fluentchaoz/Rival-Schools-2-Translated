param(
    [string]$RomFolder = "C:\Users\Fluent\Downloads\Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan)"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Fail([string]$Message) {
    Write-Host ""
    Write-Host ("ERROR: {0}" -f $Message) -ForegroundColor Red
    exit 1
}

function Run-Native([string]$Command, [string[]]$Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        Fail ("{0} failed with exit code {1}" -f $Command, $LASTEXITCODE)
    }
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"
$SourceRs = Join-Path $Upstream "src\source_disc.rs"

$ExpectedOriginalHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
$ExpectedCurrentMasterHash = "30cdcc7cdbc1a21818b65272ac50e7baebc245f0505c83d03dfb2c00db713ac4"

$OriginalBin = Join-Path $RomFolder "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin"
$OriginalCue = Join-Path $RomFolder "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).cue"

$MasterBin = Join-Path $Upstream "work\english-mgk04-full-tutorial-v3\build\justice-gakuen2-mgk04-full-tutorial-v3.bin"

$WorkRoot = Join-Path $Upstream "work\english-name-entry-screen-probe-v1"
$PreviewDir = Join-Path $WorkRoot "previews"
$AuditJson = Join-Path $WorkRoot "dialogue-name-entry-audit.json"
$ContactSheet = Join-Path $PreviewDir "name-entry-font-palettes-contact-sheet.png"

Write-Host ""
Write-Host "Justice Gakuen English Project - NAME ENTRY SCREEN PROBE v1" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream folder beside this script." }
if (-not (Test-Path $SourceRs)) { Fail "Missing upstream\src\source_disc.rs." }
if (-not (Test-Path $OriginalBin)) { Fail "Missing original BIN in ROM folder." }
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) { Fail "Cargo is not on PATH." }

$OriginalHash = (Get-FileHash $OriginalBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("Original BIN SHA-256: {0}" -f $OriginalHash)
if ($OriginalHash -ne $ExpectedOriginalHash) {
    Fail "Original BIN hash mismatch."
}
Write-Host "Original source verified." -ForegroundColor Green

if (Test-Path $MasterBin) {
    $MasterHash = (Get-FileHash $MasterBin -Algorithm SHA256).Hash.ToLower()
    Write-Host ("Current English master SHA-256: {0}" -f $MasterHash)
    if ($MasterHash -ne $ExpectedCurrentMasterHash) {
        Fail "Current MGK04 v3 master hash mismatch."
    }
    Write-Host "Current English master verified." -ForegroundColor Green
}
else {
    Fail "Current MGK04 v3 master BIN is missing."
}

New-Item -ItemType Directory -Force -Path $PreviewDir | Out-Null

# If the original dump did not include a cue, make a tiny temporary one.
if (-not (Test-Path $OriginalCue)) {
    $TempCue = Join-Path $WorkRoot "original-source.cue"
    $BinName = Split-Path -Leaf $OriginalBin
    @"
FILE "$BinName" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
"@ | Set-Content -Path $TempCue -Encoding ASCII

    # The CUE must sit beside the BIN for relative resolution, so copy only the
    # tiny cue into the ROM folder temporarily and clean it after the audit.
    $OriginalCue = Join-Path $RomFolder "__jg_name_entry_probe_temp.cue"
    @"
FILE "$BinName" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
"@ | Set-Content -Path $OriginalCue -Encoding ASCII
    $CreatedTempCue = $true
}
else {
    $CreatedTempCue = $false
}

try {
    Write-Host ""
    Write-Host "[1/3] Running upstream MGENT.BIN structural audit..." -ForegroundColor Cyan
    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "run", "--release", "--",
            "audit-dialogue-name-entry",
            "--cue", $OriginalCue,
            "--output", $AuditJson
        )
    }
    finally {
        Pop-Location
    }
}
finally {
    if ($CreatedTempCue -and (Test-Path $OriginalCue)) {
        Remove-Item $OriginalCue -Force
    }
}

if (-not (Test-Path $AuditJson)) {
    Fail "Name-entry audit JSON was not created."
}

Write-Host ""
Write-Host "[2/3] Extracting the exact MA_ENT.BIZ application + keyboard atlases..." -ForegroundColor Cyan

$OriginalSource = [System.IO.File]::ReadAllText($SourceRs)
$Marker = "// ENGLISH_PROJECT_NAME_ENTRY_SCREEN_PROBE_V1"
if ($OriginalSource.Contains($Marker)) {
    Fail "Stale name-entry probe injection already exists in source_disc.rs."
}

$InputLiteral = $OriginalBin.Replace("\", "\\")

$Rust = @"

// ENGLISH_PROJECT_NAME_ENTRY_SCREEN_PROBE_V1
#[cfg(test)]
mod english_name_entry_screen_probe_v1 {
    use std::fs;
    use std::path::Path;

    use anyhow::{Result, ensure};

    const INPUT: &str = "$InputLiteral";
    const EXPECTED_STORED: &str =
        "31b003368f9c7189448cdaa98baa746dc8dbea1638183c46554f96f480bf21ce";
    const EXPECTED_DECODED: &str =
        "099210a8804eee3270973c24ed6eb294d11499c55b4c1ef8c63e75988227b373";

    #[test]
    fn english_name_entry_screen_probe_v1() -> Result<()> {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let out = root.join("work/english-name-entry-screen-probe-v1/previews");
        fs::create_dir_all(&out)?;

        let input = Path::new(INPUT);
        let (_, stored) = crate::disc::rebuild::read_record(input, "DAT2/MA_ENT.BIZ")?;
        ensure!(
            crate::pipeline::sha256_bytes(&stored) == EXPECTED_STORED,
            "MA_ENT.BIZ stored identity changed"
        );

        let decoded = crate::compression::decompress(&stored, true)?;
        ensure!(
            crate::pipeline::sha256_bytes(&decoded) == EXPECTED_DECODED,
            "MA_ENT.BIZ decoded identity changed"
        );

        let app_tim = crate::tim::parse_4bpp_prefix(&decoded)?;
        ensure!(
            app_tim.image_x == 512
                && app_tim.image_y == 0
                && app_tim.pixel_width() == 448
                && app_tim.image_height == 464
                && app_tim.clut_width == 16
                && app_tim.clut_height == 1,
            "application-form TIM geometry changed"
        );
        let app = crate::tim::decode_4bpp_rgba_in_prefix(&decoded, 0, 0)?;
        crate::tim_preview::write_tim_preview(
            &out.join("application-form-source.png"),
            &app,
        )?;

        let font_offset = 0x19_000usize;
        let font_tim = crate::tim::parse_4bpp_prefix(&decoded[font_offset..])?;
        ensure!(
            font_tim.image_x == 768
                && font_tim.image_y == 0
                && font_tim.pixel_width() == 768
                && font_tim.image_height == 256
                && font_tim.clut_width == 352
                && font_tim.clut_height == 1,
            "name-entry font/control TIM geometry changed"
        );
        let palette_count = font_tim.clut_width * font_tim.clut_height / 16;
        ensure!(palette_count == 22, "unexpected name-entry palette count");

        for palette in 0..palette_count {
            let image =
                crate::tim::decode_4bpp_rgba_in_prefix(&decoded, font_offset, palette)?;
            crate::tim_preview::write_tim_preview(
                &out.join(format!("font-palette-{palette:02}.png")),
                &image,
            )?;
        }

        let (_, mgent) = crate::disc::rebuild::read_record(input, "DAT1/MGENT.BIN")?;
        ensure!(
            crate::pipeline::sha256_bytes(&mgent)
                == "eaf243e2d5a78919055b453611ea8b785766a6dc945966a1d5c0ce166714f70a",
            "MGENT.BIN identity changed"
        );

        eprintln!("NAME_ENTRY_PROBE_COMPLETE=1");
        eprintln!("APPLICATION_FORM={}", out.join("application-form-source.png").display());
        eprintln!("FONT_PALETTE_COUNT={palette_count}");
        Ok(())
    }
}

"@

try {
    [System.IO.File]::WriteAllText(
        $SourceRs,
        $OriginalSource.TrimEnd() + [Environment]::NewLine + $Rust + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_name_entry_screen_probe_v1",
            "--", "--nocapture"
        )
    }
    finally {
        Pop-Location
    }
}
finally {
    [System.IO.File]::WriteAllText(
        $SourceRs,
        $OriginalSource,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$ApplicationPng = Join-Path $PreviewDir "application-form-source.png"
if (-not (Test-Path $ApplicationPng)) {
    Fail "Application-form preview was not created."
}

Write-Host ""
Write-Host "[3/3] Building palette contact sheet..." -ForegroundColor Cyan

Add-Type -AssemblyName System.Drawing

$PaletteFiles = @(
    Get-ChildItem $PreviewDir -Filter "font-palette-*.png" |
    Sort-Object Name
)
if ($PaletteFiles.Count -ne 22) {
    Fail ("Expected 22 palette previews; found {0}." -f $PaletteFiles.Count)
}

$ThumbW = 384
$ThumbH = 128
$LabelH = 24
$Cols = 2
$Rows = [Math]::Ceiling($PaletteFiles.Count / $Cols)
$Sheet = New-Object System.Drawing.Bitmap ($Cols * $ThumbW), ($Rows * ($ThumbH + $LabelH))
$G = [System.Drawing.Graphics]::FromImage($Sheet)
$G.Clear([System.Drawing.Color]::Black)
$Font = New-Object System.Drawing.Font("Consolas", 10)
$Brush = [System.Drawing.Brushes]::White

try {
    for ($i = 0; $i -lt $PaletteFiles.Count; $i++) {
        $col = $i % $Cols
        $row = [Math]::Floor($i / $Cols)
        $x = $col * $ThumbW
        $y = $row * ($ThumbH + $LabelH)

        $Img = [System.Drawing.Image]::FromFile($PaletteFiles[$i].FullName)
        try {
            $G.DrawImage($Img, $x, $y + $LabelH, $ThumbW, $ThumbH)
            $G.DrawString(
                ("Palette {0:D2}" -f $i),
                $Font,
                $Brush,
                [single]($x + 4),
                [single]($y + 3)
            )
        }
        finally {
            $Img.Dispose()
        }
    }

    $Sheet.Save($ContactSheet, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $G.Dispose()
    $Font.Dispose()
    $Sheet.Dispose()
}

$Audit = Get-Content $AuditJson -Raw | ConvertFrom-Json

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "NAME ENTRY SCREEN PROBE COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Overlay:" -ForegroundColor Cyan
Write-Host ("  {0}" -f $Audit.overlay_path)
Write-Host ("  SHA-256: {0}" -f $Audit.overlay_sha256)
Write-Host ""
Write-Host "Name fields:" -ForegroundColor Cyan
foreach ($Field in @($Audit.fields)) {
    Write-Host (
        "  {0}: {1} visible glyphs, record offset {2}" -f
        $Field.name,
        $Field.visible_glyph_capacity,
        $Field.source_record_offset
    )
}
Write-Host ""
Write-Host "Keyboard source pages:" -ForegroundColor Cyan
foreach ($Page in @($Audit.pages)) {
    Write-Host (
        "  {0}: {1} cells / {2} selectable / {3} unique" -f
        $Page.name,
        $Page.cell_count,
        $Page.selectable_cell_count,
        $Page.unique_selectable_code_count
    )
}
Write-Host ""
Write-Host ("Nickname skips first source page: {0}" -f $Audit.input.nickname_skips_first_source_page)
Write-Host ("Navigation positions: {0}" -f $Audit.input.navigation_position_count)
Write-Host ("Renderer cell: {0}x{1}" -f $Audit.renderer.sprite_cell_width, $Audit.renderer.sprite_cell_height)
Write-Host ""
Write-Host "FILES TO SEND ME:" -ForegroundColor Yellow
Write-Host ("  1. {0}" -f $ApplicationPng)
Write-Host ("  2. {0}" -f $ContactSheet)
Write-Host ("  3. {0}" -f $AuditJson)
Write-Host ""
Write-Host "Nothing in either ROM was modified." -ForegroundColor Green
